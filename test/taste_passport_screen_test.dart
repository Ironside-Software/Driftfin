import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/taste_passport_model.dart';
import 'package:driftfin/providers/taste_passport_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/taste_passport/taste_passport_screen.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';

const _testLayoutModel = AdaptiveLayoutModel(
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

/// Test double that records calls instead of hitting the real Jellyfin API.
class _FakeTastePassportNotifier extends TastePassportNotifier {
  _FakeTastePassportNotifier(super.ref, TastePassportModel initial) {
    state = initial;
  }

  int fetchCalls = 0;

  @override
  Future<void> fetchProfile() async {
    fetchCalls++;
  }
}

class _Harness {
  late final _FakeTastePassportNotifier notifier;

  Widget build(TastePassportModel initial) {
    return ProviderScope(
      overrides: [
        tastePassportProvider.overrideWith((ref) {
          notifier = _FakeTastePassportNotifier(ref, initial);
          return notifier;
        }),
      ],
      child: const AdaptiveLayout(
        data: _testLayoutModel,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TastePassportScreen(),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fetches the profile once on first build', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(const TastePassportModel()));
    await tester.pumpAndSettle();

    expect(harness.notifier.fetchCalls, 1);
  });

  testWidgets('shows a progress indicator while loading', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(const TastePassportModel(loading: true)));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the empty state when nothing has been watched yet', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(const TastePassportModel()));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.tastePassportEmpty), findsOneWidget);
  });

  testWidgets('renders genre chips and stats once data is available', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(const TastePassportModel(
      itemsWatched: 42,
      topGenres: [MapEntry('Comedy', 10)],
    )));
    await tester.pumpAndSettle();

    expect(find.text('42'), findsOneWidget);
    expect(find.text('Comedy'), findsOneWidget);
  });
}
