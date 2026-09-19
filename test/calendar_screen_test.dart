import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/providers/calendar_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/seerr/calendar_screen.dart';
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

CalendarEntry _episodeEntry(DateTime airDate) => CalendarEntry(
      airDate: airDate,
      seriesTitle: 'My Show',
      season: 1,
      episode: 2,
      episodeTitle: 'The Episode',
      hasFile: false,
      item: null,
      // Null image exercises the placeholder path without a network load.
      image: null,
    );

CalendarEntry _movieEntry(DateTime airDate) => CalendarEntry(
      airDate: airDate,
      seriesTitle: 'A Movie',
      season: null,
      episode: null,
      episodeTitle: '',
      hasFile: true,
      item: null,
      image: null,
      isMovie: true,
    );

Widget _harness(Map<DateTime, List<CalendarEntry>> data) => ProviderScope(
      overrides: [
        calendarProvider.overrideWith((ref) async => data),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdaptiveLayout(
          data: _adaptiveModel,
          child: CalendarScreen(),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('agenda: renders a day group with episode and movie tiles', (tester) async {
    final airDate = DateTime(2026, 7, 5, 20, 0);
    await tester.pumpWidget(_harness({
      DateTime(2026, 7, 5): [_episodeEntry(airDate), _movieEntry(airDate)],
    }));
    // Let the overridden FutureProvider resolve and the agenda build.
    await tester.pumpAndSettle();

    expect(find.text('My Show'), findsOneWidget);
    expect(find.text('A Movie'), findsOneWidget);
    // Episode subtitle combines the SxEy code and the episode title.
    expect(find.textContaining('S1E2'), findsOneWidget);
  });

  testWidgets('empty calendar shows the empty state', (tester) async {
    await tester.pumpWidget(_harness({}));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.calendarEmpty), findsOneWidget);
  });
}
