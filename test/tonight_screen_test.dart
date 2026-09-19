import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart' as dto;
import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/tonight_model.dart';
import 'package:driftfin/providers/tonight_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/shared/media/poster_list_item.dart';
import 'package:driftfin/screens/tonight/tonight_screen.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';
import 'package:driftfin/util/tonight_picker.dart';

ItemBaseModel _poster(String id) {
  return ItemBaseModel.fromBaseDto(
    dto.BaseItemDto(id: id, name: id, type: dto.BaseItemKind.movie),
    null,
  );
}

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
class _FakeTonightNotifier extends TonightNotifier {
  _FakeTonightNotifier(super.ref, TonightModel initial) {
    state = initial;
  }

  int fetchCalls = 0;
  Duration? lastTimeAvailable;
  TonightMood? lastMood;

  @override
  Future<void> fetchTonightPicks({Duration? timeAvailable, TonightMood? mood}) async {
    fetchCalls++;
    lastTimeAvailable = timeAvailable;
    lastMood = mood;
    state = state.copyWith(
      timeAvailable: () => timeAvailable ?? state.timeAvailable,
      mood: mood ?? state.mood,
    );
  }
}

/// Builds the widget tree under test and exposes the fake notifier Riverpod
/// creates for it, so assertions can inspect recorded calls afterwards.
class _Harness {
  late final _FakeTonightNotifier notifier;

  Widget build(TonightModel initial) {
    return ProviderScope(
      overrides: [
        tonightProvider.overrideWith((ref) {
          notifier = _FakeTonightNotifier(ref, initial);
          return notifier;
        }),
      ],
      child: const AdaptiveLayout(
        data: _testLayoutModel,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TonightScreen(),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fetches picks once on first build', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(const TonightModel()));
    await tester.pumpAndSettle();

    expect(harness.notifier.fetchCalls, 1);
  });

  testWidgets('shows a progress indicator while loading', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(const TonightModel(loading: true)));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the empty state once loaded with no picks', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(const TonightModel()));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.tonightEmpty), findsOneWidget);
  });

  testWidgets('tapping a time-budget chip re-fetches with that budget', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(const TonightModel()));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.tonightMinutesOrLess(30)));
    await tester.pumpAndSettle();

    expect(harness.notifier.lastTimeAvailable, const Duration(minutes: 30));
  });

  testWidgets('tapping the refresh button re-fetches with the current time/mood', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(const TonightModel(
      timeAvailable: Duration(minutes: 60),
      mood: TonightMood.cozy,
    )));
    await tester.pumpAndSettle();
    final callsBeforeRefresh = harness.notifier.fetchCalls;

    await tester.tap(find.byIcon(IconsaxPlusLinear.refresh));
    await tester.pumpAndSettle();

    expect(harness.notifier.fetchCalls, callsBeforeRefresh + 1);
    expect(harness.notifier.lastTimeAvailable, const Duration(minutes: 60));
    expect(harness.notifier.lastMood, TonightMood.cozy);
  });

  testWidgets('renders a poster row per pick once loaded', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(TonightModel(picks: [_poster('1'), _poster('2')])));
    await tester.pumpAndSettle();

    expect(find.byType(PosterListItem), findsNWidgets(2));
  });

  testWidgets('tapping a mood chip re-fetches with that mood', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(const TonightModel()));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.tonightMoodFunny));
    await tester.pumpAndSettle();

    expect(harness.notifier.lastMood, TonightMood.funny);
  });
}
