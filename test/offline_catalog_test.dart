import 'dart:io';

import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/providers/views_provider.dart';
import 'package:driftfin/providers/connectivity_provider.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:driftfin/models/playback/playback_model.dart';
import 'package:driftfin/models/playback/offline_playback_model.dart';
import 'package:driftfin/models/syncing/sync_settings_model.dart';
import 'package:driftfin/models/video_stream_model.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/sync_provider.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart' as dto;
import 'package:driftfin/models/items/episode_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/syncing/sync_item.dart';
import 'package:driftfin/providers/offline_catalog_provider.dart';

SyncedItem episode(
  String id, {
  String series = 'series',
  int season = 1,
  int number = 1,
  UserData userData = const UserData(),
}) => SyncedItem(
  id: id,
  userId: 'user',
  userData: userData,
  itemModel: EpisodeModel.fromBaseDto(
    dto.BaseItemDto(
      id: id,
      name: id,
      seriesId: series,
      seriesName: series,
      parentIndexNumber: season,
      indexNumber: number,
    ),
    null,
  ),
);

class _LocalSync extends StateNotifier<SyncSettingsModel> implements SyncNotifier {
  _LocalSync(this.item) : super(SyncSettingsModel());
  final SyncedItem item;

  @override
  Stream<List<SyncedItem>> watchAllItems() => Stream.value([item]);

  @override
  Future<SyncedItem?> getSyncedItem(String? id) async => item;

  @override
  Future<List<SyncedItem>> getSiblings(SyncedItem item) async => [item];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User extends User {
  @override
  AccountModel? build() => AccountModel(
    id: 'user',
    name: 'User',
    avatar: '',
    lastUsed: DateTime(2026),
    credentials: CredentialsModel(url: 'https://jellyfin.test', token: 'test'),
  );
  void signOut() => state = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog refresh checks files asynchronously and clears after logout', () async {
    final directory = Directory.systemTemp.createTempSync('offline_provider');
    addTearDown(() => directory.deleteSync(recursive: true));
    final item = episode('download').copyWith(path: directory.path, videoFileName: 'video');
    await item.videoFile.writeAsBytes([1]);
    final user = _User();
    final container = ProviderContainer(
      overrides: [userProvider.overrideWith(() => user), syncProvider.overrideWith((ref) => _LocalSync(item))],
    );
    addTearDown(container.dispose);
    container.listen(offlineCatalogProvider, (_, _) {});
    expect((await container.read(offlineCatalogProvider.future)).single.id, 'download');
    await item.videoFile.delete();
    container.read(activeDownloadTasksProvider.notifier).state = [];
    expect(await container.read(offlineCatalogProvider.future), isEmpty);
    await item.videoFile.writeAsBytes([1]);
    container.read(activeDownloadTasksProvider.notifier).state = [];
    expect((await container.read(offlineCatalogProvider.future)).single.id, 'download');
    user.signOut();
    expect(await container.read(offlineCatalogProvider.future), isEmpty);
  });

  test('offline navigation refresh skips server library requests', () async {
    final container = ProviderContainer(
      overrides: [
        offlineStateProvider.overrideWithValue(true),
        jellyApiProvider.overrideWith(() => throw StateError('Server API accessed')),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(viewsProvider.notifier).fetchViews(), isNull);
  });

  test('explicit local playback never reads server API and refuses missing files', () async {
    final directory = Directory.systemTemp.createTempSync('offline_playback');
    addTearDown(() => directory.deleteSync(recursive: true));
    final item = episode('download').copyWith(path: directory.path, videoFileName: 'video', fileSize: 1);
    item.videoFile.writeAsBytesSync([1]);
    var apiReads = 0;
    final container = ProviderContainer(
      overrides: [
        syncProvider.overrideWith((ref) => _LocalSync(item)),
        jellyApiProvider.overrideWith(() {
          apiReads++;
          throw StateError('Server API accessed');
        }),
      ],
    );
    addTearDown(container.dispose);
    final helper = container.read(playbackModelHelper);
    final model = await helper.createPlaybackModel(null, item.itemModel, forcedPlaybackType: PlaybackType.offline);
    expect(model, isA<OfflinePlaybackModel>());
    expect(model!.media!.url, item.videoFile.path);
    expect(apiReads, 0);
    item.videoFile.deleteSync();
    expect(await helper.createPlaybackModel(null, item.itemModel, forcedPlaybackType: PlaybackType.offline), isNull);
    expect(apiReads, 0);
  });

  test('only complete, readable, nonempty local media enters the catalog', () async {
    final directory = Directory.systemTemp.createTempSync('offline_catalog');
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/video').writeAsBytesSync([1]);
    File('${directory.path}/empty').writeAsBytesSync([]);
    final ready = episode('ready').copyWith(path: directory.path, videoFileName: 'video', fileSize: 1);
    expect(
      (await availableOfflineItems([
        ready,
        ready.copyWith(id: 'unknown-size', fileSize: null),
        ready.copyWith(id: 'zero-source-size', fileSize: 0),
        ready.copyWith(id: 'directory', videoFileName: '.'),
        ready.copyWith(id: 'in-progress', syncing: true),
        ready.copyWith(id: 'deleted', markedForDelete: true),
        ready.copyWith(id: 'missing', videoFileName: 'missing'),
        ready.copyWith(id: 'empty', videoFileName: 'empty'),
        ready.copyWith(id: 'metadata-only', videoFileName: null),
        ready.copyWith(id: 'no-model', itemModel: null),
      ])).map((item) => item.id),
      ['ready', 'unknown-size', 'zero-source-size'],
    );
  });

  test('next up orders seasons numerically, skips watched and specials, groups by series ID', () {
    final items = [
      episode('s2', season: 2),
      episode('e10', number: 10),
      episode('watched', userData: const UserData(played: true)),
      episode('e2', number: 2),
      episode('special', season: 0),
      episode('other', series: 'other'),
      episode('finished', series: 'finished', userData: const UserData(played: true)),
      episode('unknown', series: ''),
    ];
    expect(offlineNextUp(items).map((item) => item.id), ['other', 'e2']);
    expect(offlineNextUp(items.reversed.toList()).map((item) => item.id), ['other', 'e2']);
  });

  test('queued local watched state wins over stale metadata', () {
    final first = episode('first').copyWith(unSyncedData: true, userData: const UserData(played: true));
    expect(offlineNextUp([first, episode('second', number: 2)]).single.id, 'second');
    expect(offlineNextUp([]), isEmpty);
  });
}
