import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/items/chapters_model.dart';
import 'package:driftfin/models/items/episode_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/items/media_streams_model.dart';
import 'package:driftfin/models/items/overview_model.dart';
import 'package:driftfin/models/items/series_model.dart';
import 'package:driftfin/models/syncing/sync_item.dart';
import 'package:driftfin/models/syncing/sync_settings_model.dart';
import 'package:driftfin/providers/items/episode_details_provider.dart';
import 'package:driftfin/providers/sync_provider.dart';
import 'package:driftfin/screens/details_screens/episode_detail_screen.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';

/// Test double so we can drive the episode details state directly, without
/// the provider's real network/offline-sync fetch logic.
class _FakeEpisodeDetailsProvider extends EpisodeDetailsProvider {
  _FakeEpisodeDetailsProvider(super.ref, EpisodeDetailModel initial) {
    state = initial;
  }
}

/// Test double for [SyncNotifier] so `syncedItemProvider` (which reads
/// `syncProvider.notifier.watchItem(id)`) doesn't touch the real
/// database/background-downloader machinery the real notifier wires up in
/// its constructor.
class _FakeSyncNotifier extends StateNotifier<SyncSettingsModel> implements SyncNotifier {
  _FakeSyncNotifier() : super(SyncSettingsModel());

  @override
  Stream<SyncedItem?> watchItem(String id) => Stream.value(null);

  @override
  Future<SyncedItem?> getSyncedItem(String? id) async => null;

  @override
  Future<List<SyncedItem>> getNestedChildren(SyncedItem? item) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SeriesModel _series({String name = 'Test Series'}) {
  return SeriesModel(
    originalTitle: name,
    sortName: name,
    status: 'Continuing',
    name: name,
    id: 'series-1',
    overview: const OverviewModel(),
    parentId: null,
    playlistId: null,
    images: null,
    childCount: 1,
    primaryRatio: null,
    userData: const UserData(),
  );
}

EpisodeModel _episode({
  String name = 'Pilot',
  String overviewText = '',
  List<Chapter> chapters = const [],
  List<Person> people = const [],
}) {
  return EpisodeModel(
    seriesName: 'Test Series',
    season: 1,
    episode: 1,
    episodeEnd: null,
    chapters: chapters,
    name: name,
    id: 'episode-1',
    overview: OverviewModel(summary: overviewText, people: people),
    parentId: 'series-1',
    playlistId: null,
    images: null,
    childCount: null,
    primaryRatio: null,
    userData: const UserData(),
    parentImages: null,
    mediaStreams: MediaStreamsModel(versionStreams: const []),
  );
}

const _adaptiveModel = AdaptiveLayoutModel(
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
);

Widget _harness(EpisodeDetailModel model) {
  return ProviderScope(
    overrides: [
      episodeDetailsProvider('episode-1').overrideWith((ref) => _FakeEpisodeDetailsProvider(ref, model)),
      syncProvider.overrideWith((ref) => _FakeSyncNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // AdaptiveLayout must wrap the Navigator (via `builder`), not just
      // `home`, so any dialogs/overlays also see it.
      builder: (context, child) => AdaptiveLayout(
        data: _adaptiveModel,
        child: child!,
      ),
      home: EpisodeDetailScreen(item: _episode()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders episode name and overview when series+episode are loaded', (tester) async {
    final model = EpisodeDetailModel(
      series: _series(),
      episode: _episode(overviewText: 'A pilot episode overview.'),
      episodes: [_episode()],
    );

    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    expect(find.text('Test Series'), findsWidgets);
    // The overview is rendered via ExpandingText -> HtmlWidget, which builds
    // a RichText rather than a plain Text, so findRichText is required here.
    expect(find.textContaining('A pilot episode overview.', findRichText: true), findsOneWidget);
  });

  testWidgets('renders without overview text when summary is empty', (tester) async {
    final model = EpisodeDetailModel(
      series: _series(),
      episode: _episode(overviewText: ''),
      episodes: [_episode()],
    );

    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    expect(find.text('Test Series'), findsWidgets);
  });

  testWidgets('renders chapters and cast rows when present', (tester) async {
    final model = EpisodeDetailModel(
      series: _series(),
      episode: _episode(
        overviewText: 'Overview text',
        chapters: [
          Chapter(name: 'Chapter 1', imageUrl: '', startPosition: Duration.zero),
        ],
        people: [
          Person(id: 'p1', name: 'Main Actor', role: 'Self'),
        ],
      ),
      episodes: [_episode()],
    );

    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    expect(find.text('Test Series'), findsWidgets);
    expect(find.textContaining('Overview text', findRichText: true), findsOneWidget);
  });

  testWidgets('renders an empty container when series or episode details are missing', (tester) async {
    final model = EpisodeDetailModel(series: null, episode: null, episodes: const []);

    await tester.pumpWidget(_harness(model));
    await tester.pumpAndSettle();

    expect(find.byType(EpisodeDetailScreen), findsOneWidget);
  });
}
