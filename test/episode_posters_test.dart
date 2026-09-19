import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/jellyfin/enum_models.dart';
import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/items/episode_model.dart';
import 'package:driftfin/models/items/images_models.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/items/media_streams_model.dart';
import 'package:driftfin/models/items/overview_model.dart';
import 'package:driftfin/models/items/season_model.dart';
import 'package:driftfin/models/syncing/sync_item.dart';
import 'package:driftfin/models/syncing/sync_settings_model.dart';
import 'package:driftfin/providers/sync_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/shared/media/episode_posters.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';
import 'package:driftfin/widgets/shared/enum_selection.dart';

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _adaptiveModel = AdaptiveLayoutModel(
  viewSize: ViewSize.phone,
  layoutMode: LayoutMode.single,
  inputDevice: InputDevice.touch,
  platform: TargetPlatform.android,
  isDesktop: false,
  posterDefaults: PosterDefaults(size: 100, ratio: 0.66),
  controller: <HomeTabs, ScrollController>{},
  sideBarWidth: 0,
  topBarHeight: 0,
  statusBarHeight: 0,
);

EpisodeModel _episode({
  required String id,
  required int season,
  required int episode,
  String name = 'Episode name',
  ItemLocation? location = ItemLocation.filesystem,
  DateTime? dateAired,
  bool played = false,
  bool favourite = false,
  double progress = 0,
  ImagesData? images,
}) {
  return EpisodeModel(
    seriesName: 'Series',
    season: season,
    episode: episode,
    episodeEnd: null,
    location: location,
    dateAired: dateAired,
    name: name,
    id: id,
    overview: const OverviewModel(),
    parentId: 'series-1',
    playlistId: null,
    images: images,
    childCount: null,
    primaryRatio: null,
    userData: UserData(played: played, isFavourite: favourite, progress: progress),
    parentImages: null,
    mediaStreams: MediaStreamsModel(versionStreams: []),
  );
}

Widget _harness({
  required List<EpisodeModel> episodes,
  List<SeasonModel> seasons = const [],
  ValueChanged<EpisodeModel>? playEpisode,
  Function(VoidCallback action, EpisodeModel episodeModel)? onEpisodeTap,
}) {
  return ProviderScope(
    overrides: [syncProvider.overrideWith((ref) => _FakeSyncNotifier())],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdaptiveLayout(
        data: _adaptiveModel,
        child: Scaffold(
          body: EpisodePosters(
            contentPadding: const EdgeInsets.all(8),
            playEpisode: playEpisode ?? (_) {},
            episodes: episodes,
            seasons: seasons,
            onEpisodeTap: onEpisodeTap,
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders a mix of available, missing and unaired episodes across seasons', (tester) async {
    final episodes = [
      _episode(id: 'e1', season: 1, episode: 1, name: 'Pilot', location: ItemLocation.filesystem, played: true),
      _episode(
        id: 'e2',
        season: 1,
        episode: 2,
        name: 'Second episode',
        location: ItemLocation.filesystem,
        favourite: true,
        progress: 42,
      ),
      _episode(
        id: 'e3',
        season: 2,
        episode: 1,
        name: '',
        location: ItemLocation.virtual,
        dateAired: DateTime.now().add(const Duration(days: 5)),
      ),
    ];

    await tester.pumpWidget(_harness(episodes: episodes));
    await tester.pumpAndSettle();

    expect(find.byType(EpisodePoster), findsWidgets);
    // Season selector should show since there are 2 distinct seasons.
    expect(find.byType(EnumBox), findsOneWidget);
  });

  testWidgets('renders with a single season (no season selector) and seasons metadata', (tester) async {
    final episodes = [_episode(id: 'e1', season: 1, episode: 1, name: 'Only episode')];
    final seasons = [
      const SeasonModel(
        parentImages: null,
        seasonName: 'Season One',
        episodeCount: 1,
        seriesId: 'series-1',
        season: 1,
        seriesName: 'Series',
        name: 'Season One',
        id: 's1',
        overview: OverviewModel(),
        parentId: 'series-1',
        playlistId: null,
        images: null,
        childCount: null,
        primaryRatio: null,
        userData: UserData(),
        canDelete: false,
        canDownload: false,
      ),
    ];

    await tester.pumpWidget(_harness(episodes: episodes, seasons: seasons));
    await tester.pumpAndSettle();

    expect(find.byType(EpisodePoster), findsOneWidget);
    expect(find.byType(EnumBox), findsNothing);
  });

  testWidgets('tapping an episode triggers onEpisodeTap when provided', (tester) async {
    EpisodeModel? tappedEpisode;
    final episodes = [
      _episode(id: 'e1', season: 1, episode: 1, name: 'First'),
      _episode(id: 'e2', season: 1, episode: 2, name: 'Second'),
    ];

    await tester.pumpWidget(
      _harness(
        episodes: episodes,
        onEpisodeTap: (action, episode) {
          tappedEpisode = episode;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(EpisodePoster).first);
    await tester.pumpAndSettle();

    expect(tappedEpisode, isNotNull);
  });

  testWidgets('EpisodePoster shows favourite, played and progress indicators standalone', (tester) async {
    final episode = _episode(id: 'solo', season: 1, episode: 1, played: true, favourite: true, progress: 55);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [syncProvider.overrideWith((ref) => _FakeSyncNotifier())],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdaptiveLayout(
            data: _adaptiveModel,
            child: Scaffold(
              // `FlatButton` (which `FocusButton`/`EpisodePoster` build on) only
              // renders its `overlays` (the favourite/played/progress badges)
              // when at least one interaction handler is set; real callers
              // (see EpisodePosters) always pass `onTap`, so this standalone
              // usage does too.
              body: EpisodePoster(episode: episode, actions: const [], onTap: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
