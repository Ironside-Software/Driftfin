import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/book_model.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/items/media_streams_model.dart';
import 'package:driftfin/models/items/movie_model.dart';
import 'package:driftfin/models/items/overview_model.dart';
import 'package:driftfin/screens/shared/media/components/poster_overlays.dart';

ItemBaseModel _item(
  String id, {
  bool played = false,
  double progress = 0,
  int? unPlayedItemCount,
  Duration? runTime,
}) =>
    ItemBaseModel(
      name: id,
      id: id,
      overview: OverviewModel(runTime: runTime),
      parentId: null,
      playlistId: null,
      images: null,
      childCount: null,
      primaryRatio: null,
      userData: UserData(played: played, progress: progress, unPlayedItemCount: unPlayedItemCount),
      canDownload: null,
      canDelete: null,
      jellyType: null,
    );

BookModel _book(String id, {UserData userData = const UserData()}) => BookModel(
      parentName: 'Series',
      name: id,
      id: id,
      overview: const OverviewModel(),
      parentId: null,
      playlistId: null,
      images: null,
      childCount: null,
      primaryRatio: null,
      userData: userData,
      canDownload: null,
      canDelete: null,
    );

MovieModel _movie(String id, {Duration? runTime}) => MovieModel(
      originalTitle: id,
      premiereDate: DateTime(2020),
      sortName: id,
      status: '',
      name: id,
      id: id,
      overview: OverviewModel(runTime: runTime),
      parentId: null,
      playlistId: null,
      images: null,
      childCount: null,
      primaryRatio: null,
      userData: const UserData(),
      parentImages: null,
      mediaStreams: MediaStreamsModel(versionStreams: const []),
      canDownload: null,
      canDelete: null,
    );

Widget _harness(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SelectedPosterOverlay shows the poster name', (tester) async {
    await tester.pumpWidget(_harness(SelectedPosterOverlay(
      poster: _item('a'),
      radius: BorderRadius.circular(8),
    )));
    await tester.pumpAndSettle();

    expect(find.text('a'), findsOneWidget);
  });

  testWidgets('FavouriteOverlay shows a heart icon', (tester) async {
    await tester.pumpWidget(_harness(const FavouriteOverlay()));
    await tester.pumpAndSettle();

    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('ProgressOverlay renders a linear progress indicator', (tester) async {
    await tester.pumpWidget(_harness(const ProgressOverlay(progress: 42)));
    await tester.pumpAndSettle();

    final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(indicator.value, closeTo(0.42, 0.001));
  });

  group('UnplayedWatchedOverlay', () {
    testWidgets('renders nothing when unplayed', (tester) async {
      await tester.pumpWidget(_harness(UnplayedWatchedOverlay(poster: _item('a'))));
      await tester.pumpAndSettle();

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('renders a check icon when fully played', (tester) async {
      await tester.pumpWidget(_harness(UnplayedWatchedOverlay(poster: _item('a', played: true))));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('renders a percentage label when partially played', (tester) async {
      // Only BookModel's watchedState() ever returns PartiallyPlayed; the base
      // ItemBaseModel.watchedState() only distinguishes Played/Unplayed.
      final book = _book('a', userData: const UserData(playbackPositionTicks: 6000000000, progress: 10));
      await tester.pumpWidget(_harness(UnplayedWatchedOverlay(poster: book)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.byType(Text), findsWidgets);
    });
  });

  group('VideoDurationOverlay', () {
    testWidgets('renders nothing when runTime is null', (tester) async {
      await tester.pumpWidget(_harness(VideoDurationOverlay(poster: _item('a'))));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('renders nothing for non-PhotoModel items even with a runTime', (tester) async {
      await tester.pumpWidget(_harness(VideoDurationOverlay(poster: _movie('m', runTime: const Duration(minutes: 5)))));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });
  });

  testWidgets('InlineTitleOverlay renders the title text', (tester) async {
    await tester.pumpWidget(_harness(const InlineTitleOverlay(title: 'My Title')));
    await tester.pumpAndSettle();

    expect(find.text('My Title'), findsOneWidget);
  });

  group('BottomOverlaysContainer', () {
    testWidgets('shows favourite and progress overlays when enabled', (tester) async {
      await tester.pumpWidget(_harness(const BottomOverlaysContainer(
        showFavourite: true,
        showProgress: true,
        progress: 30,
        itemType: FladderItemType.movie,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(FavouriteOverlay), findsOneWidget);
      expect(find.byType(ProgressOverlay), findsOneWidget);
    });

    testWidgets('hides progress overlay for books', (tester) async {
      await tester.pumpWidget(_harness(const BottomOverlaysContainer(
        showFavourite: false,
        showProgress: true,
        progress: 30,
        itemType: FladderItemType.book,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(FavouriteOverlay), findsNothing);
      expect(find.byType(ProgressOverlay), findsNothing);
    });

    testWidgets('hides progress overlay when progress is 0 or 100', (tester) async {
      await tester.pumpWidget(_harness(const BottomOverlaysContainer(
        showFavourite: false,
        showProgress: true,
        progress: 0,
        itemType: FladderItemType.movie,
      )));
      await tester.pumpAndSettle();

      expect(find.byType(ProgressOverlay), findsNothing);
    });
  });

  group('PosterMediaBadge', () {
    testWidgets('renders nothing when there is no stream data', (tester) async {
      await tester.pumpWidget(_harness(PosterMediaBadge(poster: _item('a'))));
      await tester.pumpAndSettle();

      expect(find.byType(Container), findsNothing);
    });

    testWidgets('renders nothing for a movie with an empty version stream list', (tester) async {
      await tester.pumpWidget(_harness(PosterMediaBadge(poster: _movie('m'))));
      await tester.pumpAndSettle();

      expect(find.byType(Text), findsNothing);
    });
  });
}
