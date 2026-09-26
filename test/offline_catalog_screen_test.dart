import 'dart:async';

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart' as dto;
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/audio_model.dart';
import 'package:driftfin/models/playback/playback_model.dart';
import 'package:driftfin/models/playback/offline_playback_model.dart';
import 'package:driftfin/models/video_stream_model.dart';
import 'package:driftfin/providers/video_player_provider.dart';
import 'package:driftfin/providers/connectivity_provider.dart' as network show ConnectionState;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/syncing/sync_item.dart';
import 'package:driftfin/providers/connectivity_provider.dart';
import 'package:driftfin/providers/dashboard_provider.dart';
import 'package:driftfin/providers/library_screen_provider.dart' as library_state;
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';
import 'package:driftfin/providers/living_home_provider.dart';
import 'package:driftfin/providers/offline_catalog_provider.dart';
import 'package:driftfin/screens/dashboard/dashboard_screen.dart';
import 'package:driftfin/screens/library/library_screen.dart';
import 'package:driftfin/screens/offline/offline_catalog_screen.dart';

import 'offline_catalog_test.dart' show episode;

class _PlaybackHelper extends PlaybackModelHelper {
  _PlaybackHelper(Ref ref, this.result) : super(ref: ref);
  final PlaybackModel? result;
  PlaybackType? requestedType;

  @override
  Future<PlaybackModel?> createPlaybackModel(
    BuildContext? context,
    ItemBaseModel? item, {
    PlaybackModel? oldModel,
    List<ItemBaseModel>? libraryQueue,
    PlaybackQueueSource? queueSource,
    bool showPlaybackOptions = false,
    PlaybackType? forcedPlaybackType,
    Duration? startPosition,
  }) async {
    requestedType = forcedPlaybackType;
    expect(forcedPlaybackType, PlaybackType.offline);
    return result;
  }
}

class _Player extends VideoPlayerNotifier {
  _Player(super.ref);
  List<ItemBaseModel>? audioQueue;
  int? audioIndex;
  int videoLoads = 0;
  int opens = 0;
  bool succeeds = true;

  @override
  Future<bool> loadPlaybackItem(PlaybackModel model, Duration startPosition) async {
    videoLoads++;
    return succeeds;
  }

  @override
  Future<bool> loadAudioPlaybackItem(
    PlaybackModel model,
    List<ItemBaseModel> queue,
    int currentIndex,
    Duration startPosition,
  ) async {
    audioQueue = queue;
    audioIndex = currentIndex;
    return succeeds;
  }

  @override
  Future<void> openPlayer(BuildContext context) async {
    opens++;
  }
}

class _Connectivity extends ConnectivityStatus {
  int probes = 0;
  @override
  network.ConnectionState build() => network.ConnectionState.offline;
  @override
  Future<void> checkConnectivity({bool immediate = false}) async {
    probes++;
  }

  @override
  Future<void> waitForProbe() async {}
}

class _OnlineLibrary extends library_state.LibraryScreen {
  @override
  Future<void> fetchAllLibraries() async {}
}

Widget _harness(
  Widget child, {
  bool offline = true,
  PlaybackModel? playback,
  bool playbackSucceeds = true,
  void Function(_Player)? onPlayer,
  _Connectivity? connectivity,
  List<SyncedItem> items = const [],
  Stream<List<SyncedItem>>? stream,
}) => ProviderScope(
  overrides: [
    playbackModelHelper.overrideWith((ref) => _PlaybackHelper(ref, playback)),
    videoPlayerProvider.overrideWith((ref) {
      final player = _Player(ref)..succeeds = playbackSucceeds;
      onPlayer?.call(player);
      return player;
    }),
    if (connectivity != null) connectivityStatusProvider.overrideWith(() => connectivity),
    offlineStateProvider.overrideWithValue(offline),
    offlineCatalogProvider.overrideWith((ref) => stream ?? Stream.value(items)),
    dashboardProvider.overrideWith((ref) => throw StateError('Network dashboard accessed')),
    livingHomeProvider.overrideWith((ref) => throw StateError('Network home accessed')),
    library_state.libraryScreenProvider.overrideWith(
      () => offline ? throw StateError('Network library accessed') : _OnlineLibrary(),
    ),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: AdaptiveLayout(
      data: const AdaptiveLayoutModel(
        viewSize: ViewSize.phone,
        layoutMode: LayoutMode.single,
        inputDevice: InputDevice.touch,
        platform: TargetPlatform.android,
        isDesktop: false,
        posterDefaults: PosterDefaults(size: 100, ratio: 0.66),
        controller: {},
        sideBarWidth: 0,
        topBarHeight: 0,
        statusBarHeight: 0,
      ),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  for (final standalone in [false, true]) {
    testWidgets('audio uses the local queue loader (${standalone ? 'standalone' : 'siblings'})', (tester) async {
      final first = AudioModel.fromBaseDto(const dto.BaseItemDto(id: 'first', name: 'First'), null);
      final selected = AudioModel.fromBaseDto(const dto.BaseItemDto(id: 'second', name: 'Second'), null);
      final item = SyncedItem(id: selected.id, userId: 'user', itemModel: selected);
      final model = OfflinePlaybackModel(
        item: selected,
        syncedItem: item,
        media: null,
        queue: standalone ? [] : [first, selected],
      );
      late _Player player;
      await tester.pumpWidget(
        _harness(const OfflineCatalogScreen(), items: [item], playback: model, onPlayer: (value) => player = value),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second'));
      await tester.pumpAndSettle();
      expect(player.audioQueue!.map((track) => track.id), standalone ? ['second'] : ['first', 'second']);
      expect(player.audioIndex, standalone ? 0 : 1);
      expect(player.videoLoads, 0);
      expect(player.opens, 0);
    });
  }

  testWidgets('video uses the video loader and opens the player', (tester) async {
    final item = episode('Video');
    final model = OfflinePlaybackModel(item: item.itemModel!, syncedItem: item, media: null);
    late _Player player;
    await tester.pumpWidget(
      _harness(const OfflineCatalogScreen(), items: [item], playback: model, onPlayer: (value) => player = value),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();
    expect(player.videoLoads, 1);
    expect(player.audioQueue, isNull);
    expect(player.opens, 1);
  });

  testWidgets('failed playback shows an error and releases the play lock', (tester) async {
    final item = episode('Video');
    final model = OfflinePlaybackModel(item: item.itemModel!, syncedItem: item, media: null);
    late _Player player;
    await tester.pumpWidget(
      _harness(
        const OfflineCatalogScreen(),
        items: [item],
        playback: model,
        playbackSucceeds: false,
        onPlayer: (value) => player = value,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(player.opens, 0);
    player.succeeds = true;
    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();
    expect(player.opens, 1);
  });

  testWidgets('reconnect probes connectivity and reloads the local catalog', (tester) async {
    final connectivity = _Connectivity();
    await tester.pumpWidget(_harness(const OfflineCatalogScreen(), connectivity: connectivity));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reconnect'));
    await tester.pumpAndSettle();
    expect(connectivity.probes, 1);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Reconnect')).onPressed, isNotNull);
  });

  testWidgets('offline dashboard renders local rows without network providers', (tester) async {
    await tester.pumpWidget(
      _harness(
        const DashboardScreen(),
        items: [episode('Resuming', userData: const UserData(playbackPositionTicks: 10000000))],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Available offline'), findsOneWidget);
    expect(find.text('Next-up'), findsOneWidget);
    expect(find.text('Resuming'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline library forces local filter and searches series names', (tester) async {
    await tester.pumpWidget(
      _harness(
        const LibraryScreen(),
        items: [
          episode('First', series: 'Northern Lights'),
          episode('Second', series: 'Elsewhere'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);
    await tester.enterText(find.byType(TextField), 'northern');
    await tester.pump();
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    expect(find.text('No results'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('Second'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('Available offline can be enabled and disabled while connected', (tester) async {
    await tester.pumpWidget(_harness(const LibraryScreen(), offline: false, items: [episode('Download')]));
    await tester.pumpAndSettle();
    expect(find.byType(OfflineCatalogScreen), findsNothing);
    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Reconnect'), findsNothing);
    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();
    expect(find.byType(OfflineCatalogScreen), findsNothing);
  });

  testWidgets('empty catalog provides reconnect action', (tester) async {
    await tester.pumpWidget(_harness(const DashboardScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No downloads available on this device.'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
  });

  testWidgets('database changes refresh catalog and local favorite filtering', (tester) async {
    final stream = StreamController<List<SyncedItem>>();
    addTearDown(stream.close);
    await tester.pumpWidget(_harness(const OfflineCatalogScreen(favorites: true), stream: stream.stream));
    stream.add([episode('Favorite', userData: const UserData(isFavourite: true)), episode('Other')]);
    await tester.pumpAndSettle();
    expect(find.text('Favorite'), findsOneWidget);
    expect(find.text('Other'), findsNothing);
    stream.add([]);
    await tester.pumpAndSettle();
    expect(find.text('Favorite'), findsNothing);
    expect(find.text('No downloads available on this device.'), findsOneWidget);
  });

  testWidgets('catalog failures show retry', (tester) async {
    await tester.pumpWidget(_harness(const OfflineCatalogScreen(), stream: Stream.error(StateError('read failed'))));
    await tester.pumpAndSettle();
    expect(find.text('Could not load downloads.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
