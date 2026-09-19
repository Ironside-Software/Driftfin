import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/items/images_models.dart';
import 'package:driftfin/models/seerr/seerr_dashboard_model.dart';
import 'package:driftfin/providers/seerr/seerr_details_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/seerr/seerr_details_screen.dart';
import 'package:driftfin/seerr/seerr_models.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';

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

/// Test double so we can drive the seerr details state directly, without the
/// provider's real `fetch()` (which hits the network on `build`).
class FakeSeerrDetails extends SeerrDetails {
  FakeSeerrDetails(this._fixedState);

  final SeerrDetailsModel _fixedState;

  @override
  SeerrDetailsModel build({
    required int tmdbId,
    required SeerrMediaType mediaType,
    SeerrDashboardPosterModel? poster,
  }) {
    state = _fixedState;
    return state;
  }

  @override
  Future<void> toggleSeasonExpanded(int seasonNumber) async {
    final currentExpanded = state.expandedSeasons[seasonNumber] ?? false;
    state = state.copyWith(
      expandedSeasons: {...state.expandedSeasons, seasonNumber: !currentExpanded},
    );
  }

  /// `DetailScaffold` triggers a refresh on start (and pull-to-refresh),
  /// which would otherwise call the real network-backed `fetch()`. Keep the
  /// fixed state instead of hitting the network.
  @override
  Future<void> fetch() async {}
}

/// `ExpandingText` (used for the overview) renders its content via
/// `flutter_widget_from_html`'s `HtmlWidget`, which produces bare `RichText`
/// widgets rather than `Text`. `find.textContaining`/`find.text` only inspect
/// `Text`/`Text.rich`, so they never match HTML-rendered content - this
/// finder checks `RichText.text`'s plain-text content instead.
Finder findRichTextContaining(String pattern) {
  return find.byWidgetPredicate((widget) => widget is RichText && widget.text.toPlainText().contains(pattern));
}

SeerrDashboardPosterModel _poster({
  required SeerrMediaType type,
  String title = 'Test Title',
  String overview = 'Test overview text.',
  List<SeerrSeason>? seasons,
  Map<int, SeerrMediaStatus>? seasonStatuses,
}) {
  return SeerrDashboardPosterModel(
    id: 'seerr-1',
    type: type,
    tmdbId: 42,
    jellyfinItemId: null,
    title: title,
    overview: overview,
    images: ImagesData(),
    mediaStatus: SeerrMediaStatus.unknown,
    seasons: seasons,
    seasonStatuses: seasonStatuses,
  );
}

/// Lets a test swap the screen out for an empty child while keeping the same
/// [ProviderScope] (and its `windowTitleProvider`) mounted, so widgets under
/// test can be disposed - and any microtasks they schedule flushed - before
/// the container itself goes away in the test's own teardown.
class _Harness extends StatefulWidget {
  final List<Override> overrides;
  final Widget child;

  const _Harness({required this.overrides, required this.child});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool _showChild = true;

  void hide() => setState(() => _showChild = false);

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: widget.overrides,
      child: _showChild ? widget.child : const SizedBox.shrink(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void useTallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // `DetailScaffold.dispose()` removes its window-title stack entry, which
  // schedules a `Future.microtask` write to `windowTitleProvider`. Hiding the
  // screen via `_Harness` disposes `DetailScaffold` while the `ProviderScope`
  // (and its `windowTitleProvider`) stays mounted, so the follow-up `pump`
  // can flush that microtask before the test's own teardown disposes the
  // container.
  Future<void> unmount(WidgetTester tester) async {
    tester.state<_HarnessState>(find.byType(_Harness)).hide();
    await tester.pump();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('movie: renders title and overview, no season section', (tester) async {
    useTallView(tester);
    final prefs = await SharedPreferences.getInstance();

    final poster = _poster(
      type: SeerrMediaType.movie,
      title: 'A Great Movie',
      overview: 'A gripping tale of testing.',
    );
    final state = SeerrDetailsModel(
      tmdbId: 42,
      mediaType: SeerrMediaType.movie,
      poster: poster,
      genres: [SeerrGenre(id: 1, name: 'Action')],
      voteAverage: 8.4,
      contentRating: 'PG-13',
      recommended: const [],
      similar: const [],
    );

    await tester.pumpWidget(
      _Harness(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          seerrDetailsProvider(
            tmdbId: 42,
            mediaType: SeerrMediaType.movie,
            poster: poster,
          ).overrideWith(() => FakeSeerrDetails(state)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdaptiveLayout(
            data: _adaptiveModel,
            child: SeerrDetailsScreen(mediaType: 'movie', tmdbId: 42, poster: poster),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A Great Movie'), findsWidgets);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.markAsWatched), findsOneWidget);
    expect(findRichTextContaining('A gripping tale of testing.'), findsOneWidget);
    // No season section for a movie.
    expect(find.byType(AnimatedRotation), findsNothing);

    await unmount(tester);
  });

  testWidgets('tv show: expanded season with cached episodes renders episode cards', (tester) async {
    useTallView(tester);
    final prefs = await SharedPreferences.getInstance();

    final season = SeerrSeason(
      id: 1,
      name: 'Season 1',
      seasonNumber: 1,
      episodeCount: 2,
    );
    final episodes = [
      SeerrEpisode(id: 1, name: 'Pilot', episodeNumber: 1, seasonNumber: 1, overview: 'The first episode.'),
      SeerrEpisode(id: 2, name: 'Second Episode', episodeNumber: 2, seasonNumber: 1, overview: 'The second one.'),
    ];

    final poster = _poster(
      type: SeerrMediaType.tvshow,
      title: 'A Great Show',
      overview: 'A tv overview.',
      seasons: [season],
      seasonStatuses: {1: SeerrMediaStatus.available},
    );

    final state = SeerrDetailsModel(
      tmdbId: 42,
      mediaType: SeerrMediaType.tvshow,
      poster: poster,
      seasonStatuses: {1: SeerrMediaStatus.available},
      expandedSeasons: {1: true},
      episodesCache: {1: episodes},
      recommended: const [],
      similar: const [],
    );

    await tester.pumpWidget(
      _Harness(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          seerrDetailsProvider(
            tmdbId: 42,
            mediaType: SeerrMediaType.tvshow,
            poster: poster,
          ).overrideWith(() => FakeSeerrDetails(state)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdaptiveLayout(
            data: _adaptiveModel,
            child: SeerrDetailsScreen(mediaType: 'tv', tmdbId: 42, poster: poster),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A Great Show'), findsWidgets);
    expect(findRichTextContaining('Pilot'), findsOneWidget);
    expect(findRichTextContaining('Second Episode'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('minimal: poster == null collapses the content area without throwing', (tester) async {
    useTallView(tester);
    final prefs = await SharedPreferences.getInstance();

    const state = SeerrDetailsModel(
      tmdbId: 42,
      mediaType: SeerrMediaType.movie,
      poster: null,
      recommended: [],
      similar: [],
    );

    await tester.pumpWidget(
      _Harness(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          seerrDetailsProvider(
            tmdbId: 42,
            mediaType: SeerrMediaType.movie,
            poster: null,
          ).overrideWith(() => FakeSeerrDetails(state)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdaptiveLayout(
            data: _adaptiveModel,
            child: SeerrDetailsScreen(mediaType: 'movie', tmdbId: 42),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SeerrDetailsScreen), findsOneWidget);
    // No overview/title content is rendered when there's no poster.
    expect(find.textContaining('overview'), findsNothing);

    await unmount(tester);
  });

  testWidgets('interaction: tapping a collapsed season with cached episodes expands it', (tester) async {
    useTallView(tester);
    final prefs = await SharedPreferences.getInstance();

    final season = SeerrSeason(
      id: 1,
      name: 'Season 1',
      seasonNumber: 1,
      episodeCount: 1,
    );
    final episodes = [
      SeerrEpisode(id: 1, name: 'Only Episode', episodeNumber: 1, seasonNumber: 1),
    ];

    final poster = _poster(
      type: SeerrMediaType.tvshow,
      title: 'Interactive Show',
      seasons: [season],
      seasonStatuses: {1: SeerrMediaStatus.pending},
    );

    final state = SeerrDetailsModel(
      tmdbId: 42,
      mediaType: SeerrMediaType.tvshow,
      poster: poster,
      seasonStatuses: {1: SeerrMediaStatus.pending},
      expandedSeasons: const {},
      episodesCache: {1: episodes},
      recommended: const [],
      similar: const [],
    );

    await tester.pumpWidget(
      _Harness(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          seerrDetailsProvider(
            tmdbId: 42,
            mediaType: SeerrMediaType.tvshow,
            poster: poster,
          ).overrideWith(() => FakeSeerrDetails(state)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdaptiveLayout(
            data: _adaptiveModel,
            child: SeerrDetailsScreen(mediaType: 'tv', tmdbId: 42, poster: poster),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Not expanded yet: episode text is not present.
    expect(findRichTextContaining('Only Episode'), findsNothing);

    // Tap the season header to expand it. The header can render underneath
    // the scaffold's fixed top app bar/back button overlay, so scroll it
    // into view first to get a reliable hit test.
    await tester.ensureVisible(find.text('Season 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Season 1'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(findRichTextContaining('Only Episode'), findsOneWidget);

    await unmount(tester);
  });
}
