import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/providers/seerr_search_provider.dart';
import 'package:driftfin/screens/seerr/widgets/seerr_filter_dialogs.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/seerr/seerr_models.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';

const _phoneModel = AdaptiveLayoutModel(
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

/// Harness that pumps a single button whose onPressed exposes both a real
/// [BuildContext] (with [AppLocalizations] available) and a real
/// [SeerrSearch] notifier instance (obtained via `ref.read`), so the
/// dialog-opening top-level functions can be exercised without any network
/// activity (SeerrSearch.build() is network-free; only init()/submit()/etc.
/// call the API, none of which we invoke here).
///
/// Wrapped in [AdaptiveLayout] because some dialogs (e.g. the studio search
/// dialog) render an [OutlinedTextField], which reads
/// `AdaptiveLayout.inputDeviceOf(context)` during its first frame.
Widget _harness({
  required Widget Function(BuildContext context, SeerrSearch notifier) builder,
}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // AdaptiveLayout must wrap the Navigator (via `builder`), not just
      // `home`, because dialogs render into the Navigator's Overlay, which
      // sits alongside `home` rather than beneath it.
      builder: (context, child) => AdaptiveLayout(
        data: _phoneModel,
        child: child!,
      ),
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) {
            final notifier = ref.read(seerrSearchProvider.notifier);
            return Builder(builder: (context) => builder(context, notifier));
          },
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pure label helpers', () {
    testWidgets('yearLabel returns the localized default and range variants', (tester) async {
      late String noneLabel;
      late String rangeLabel;
      late String minOnlyLabel;
      late String maxOnlyLabel;

      await tester.pumpWidget(_harness(
        builder: (context, notifier) => ElevatedButton(
          onPressed: () {
            noneLabel = yearLabel(context, (null, null));
            rangeLabel = yearLabel(context, (2000, 2020));
            minOnlyLabel = yearLabel(context, (2000, null));
            maxOnlyLabel = yearLabel(context, (null, 2020));
          },
          child: const Text('go'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(noneLabel, isNotEmpty);
      expect(rangeLabel, contains('2000-2020'));
      expect(minOnlyLabel, contains('2000+'));
      expect(maxOnlyLabel, contains('<=2020'));
    });

    testWidgets('ratingLabel returns the localized default and range variants', (tester) async {
      late String noneLabel;
      late String rangeLabel;
      late String minOnlyLabel;
      late String maxOnlyLabel;

      await tester.pumpWidget(_harness(
        builder: (context, notifier) => ElevatedButton(
          onPressed: () {
            noneLabel = ratingLabel(context, const SeerrFilterModel());
            rangeLabel = ratingLabel(context, const SeerrFilterModel(voteAverageGte: 5, voteAverageLte: 8));
            minOnlyLabel = ratingLabel(context, const SeerrFilterModel(voteAverageGte: 5));
            maxOnlyLabel = ratingLabel(context, const SeerrFilterModel(voteAverageLte: 8));
          },
          child: const Text('go'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(noneLabel, isNotEmpty);
      expect(rangeLabel, contains('5.0-8.0'));
      expect(minOnlyLabel, contains('5.0+'));
      expect(maxOnlyLabel, contains('<=8.0'));
    });

    testWidgets('runtimeLabel returns the localized default and range variants', (tester) async {
      late String noneLabel;
      late String rangeLabel;
      late String minOnlyLabel;
      late String maxOnlyLabel;

      await tester.pumpWidget(_harness(
        builder: (context, notifier) => ElevatedButton(
          onPressed: () {
            noneLabel = runtimeLabel(context, const SeerrFilterModel());
            rangeLabel = runtimeLabel(context, const SeerrFilterModel(runtimeGte: 30, runtimeLte: 90));
            minOnlyLabel = runtimeLabel(context, const SeerrFilterModel(runtimeGte: 30));
            maxOnlyLabel = runtimeLabel(context, const SeerrFilterModel(runtimeLte: 90));
          },
          child: const Text('go'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('go'));
      await tester.pump();

      expect(noneLabel, isNotEmpty);
      expect(rangeLabel, contains('30-90'));
      expect(minOnlyLabel, contains('30+'));
      expect(maxOnlyLabel, contains('<=90'));
    });
  });

  group('openYearDialog', () {
    testWidgets('renders the range summary and Save closes it, updating filters without submit', (tester) async {
      await tester.pumpWidget(_harness(
        builder: (context, notifier) => ElevatedButton(
          onPressed: () => openYearDialog(context,
              (first, last) => notifier.setYearRangeWithoutSubmit(minYear: first, maxYear: last), (2010, 2015)),
          child: const Text('open'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('2010 - 2015'), findsOneWidget);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.save));
      await tester.pumpAndSettle();

      expect(find.text('2010 - 2015'), findsNothing);
    });

    testWidgets('Clear resets the year range', (tester) async {
      SeerrSearch? capturedNotifier;

      await tester.pumpWidget(_harness(
        builder: (context, notifier) {
          capturedNotifier = notifier;
          return ElevatedButton(
            onPressed: () => openYearDialog(context,
                (first, last) => notifier.setYearRangeWithoutSubmit(minYear: first, maxYear: last), (2010, 2015)),
            child: const Text('open'),
          );
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.clear));
      await tester.pumpAndSettle();

      expect(capturedNotifier, isNotNull);
      expect(capturedNotifier!.state.filters.yearGte, isNull);
      expect(capturedNotifier!.state.filters.yearLte, isNull);
    });
  });

  group('openRatingDialog', () {
    testWidgets('renders with the initial rating summary', (tester) async {
      await tester.pumpWidget(_harness(
        builder: (context, notifier) => ElevatedButton(
          onPressed: () =>
              openRatingDialog(context, notifier, const SeerrFilterModel(voteAverageGte: 2, voteAverageLte: 9)),
          child: const Text('open'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('2.0 - 9.0'), findsOneWidget);
    });
  });

  group('openRuntimeDialog', () {
    testWidgets('renders with the initial runtime range', (tester) async {
      await tester.pumpWidget(_harness(
        builder: (context, notifier) => ElevatedButton(
          onPressed: () =>
              openRuntimeDialog(context, notifier, const SeerrFilterModel(runtimeGte: 30, runtimeLte: 120)),
          child: const Text('open'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });
  });

  group('openSortDialog', () {
    testWidgets('renders a checkbox list item for every SeerrSortBy option', (tester) async {
      await tester.pumpWidget(_harness(
        builder: (context, notifier) => ElevatedButton(
          onPressed: () => openSortDialog(context, notifier, const SeerrFilterModel()),
          child: const Text('open'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CheckboxListTile), findsNWidgets(SeerrSortBy.values.length));
    });

    testWidgets('selecting a different sort updates the notifier and closes the dialog', (tester) async {
      SeerrSearch? capturedNotifier;

      await tester.pumpWidget(_harness(
        builder: (context, notifier) {
          capturedNotifier = notifier;
          return ElevatedButton(
            onPressed: () => openSortDialog(
              context,
              notifier,
              const SeerrFilterModel(sortBy: SeerrSortBy.popularityDesc),
            ),
            child: const Text('open'),
          );
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap the tile for a different sort option than the currently selected one.
      final tiles = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();
      final differentIndex = tiles.indexWhere((t) => t.value == false);
      expect(differentIndex, greaterThanOrEqualTo(0));

      await tester.tap(find.byType(CheckboxListTile).at(differentIndex));
      await tester.pumpAndSettle();

      expect(capturedNotifier, isNotNull);
      expect(capturedNotifier!.state.filters.sortBy, isNot(SeerrSortBy.popularityDesc));
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('openStudioDialog', () {
    testWidgets('renders the empty state without triggering a search', (tester) async {
      await tester.pumpWidget(_harness(
        builder: (context, notifier) => ElevatedButton(
          onPressed: () => openStudioDialog(context, notifier, const SeerrFilterModel()),
          child: const Text('open'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.noResults), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows the previously selected studio name pre-filled', (tester) async {
      final studio = SeerrCompany(id: 1, name: 'Studio Ghibli');

      await tester.pumpWidget(_harness(
        builder: (context, notifier) => ElevatedButton(
          onPressed: () => openStudioDialog(context, notifier, SeerrFilterModel(studio: studio)),
          child: const Text('open'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Studio Ghibli'), findsOneWidget);
    });
  });
}
