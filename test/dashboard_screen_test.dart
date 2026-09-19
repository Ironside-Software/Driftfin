import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart' as dto;
import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/routes/auto_router.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/living_home_model.dart';
import 'package:driftfin/models/recommended_model.dart';
import 'package:driftfin/models/views_model.dart';
import 'package:driftfin/providers/dashboard_provider.dart';
import 'package:driftfin/providers/home_collections_provider.dart';
import 'package:driftfin/providers/living_home_provider.dart';
import 'package:driftfin/providers/smart_shelves_provider.dart';
import 'package:driftfin/providers/views_provider.dart';
import 'package:driftfin/screens/dashboard/dashboard_screen.dart';
import 'package:driftfin/screens/home_screen.dart';
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
);

ItemBaseModel _poster(String id) {
  return ItemBaseModel.fromBaseDto(
    dto.BaseItemDto(id: id, name: id, type: dto.BaseItemKind.movie),
    null,
  );
}

/// Test double that records calls instead of hitting the real Jellyfin API.
class _FakeViewsNotifier extends ViewsNotifier {
  _FakeViewsNotifier(super.ref);
  int fetchViewsCalls = 0;

  @override
  Future<ViewsModel?> fetchViews() async {
    fetchViewsCalls++;
    return null;
  }
}

/// Test double that records calls instead of hitting the real Jellyfin API.
class _FakeDashboardNotifier extends DashboardNotifier {
  _FakeDashboardNotifier(super.ref);
  int fetchCalls = 0;

  @override
  Future<void> fetchNextUpAndResume() async {
    fetchCalls++;
  }
}

/// Test double that records calls instead of hitting the real Jellyfin API.
class _FakeLivingHomeNotifier extends LivingHomeNotifier {
  _FakeLivingHomeNotifier(super.ref, LivingHomeModel initial) {
    state = initial;
  }
  int refreshCalls = 0;

  @override
  Future<void> refreshIfStale({bool force = false}) async {
    refreshCalls++;
  }
}

class _Harness {
  late final _FakeViewsNotifier viewsNotifier;
  late final _FakeDashboardNotifier dashboardNotifier;
  late final _FakeLivingHomeNotifier livingHomeNotifier;

  Widget build({
    LivingHomeModel livingHome = const LivingHomeModel(),
    List<RecommendedModel> smartShelves = const [],
  }) {
    return ProviderScope(
      overrides: [
        viewsProvider.overrideWith((ref) {
          viewsNotifier = _FakeViewsNotifier(ref);
          return viewsNotifier;
        }),
        dashboardProvider.overrideWith((ref) {
          dashboardNotifier = _FakeDashboardNotifier(ref);
          return dashboardNotifier;
        }),
        livingHomeProvider.overrideWith((ref) {
          livingHomeNotifier = _FakeLivingHomeNotifier(ref, livingHome);
          return livingHomeNotifier;
        }),
        homeCollectionsProvider.overrideWith((ref) async => const []),
        smartShelvesProvider.overrideWith((ref) async => smartShelves),
      ],
      child: const AdaptiveLayout(
        data: _testLayoutModel,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DashboardScreen(),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('keeps Tonight and removes the Taste Passport entry point', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.tonight), findsOneWidget);
    expect(find.text(l10n.tastePassport), findsNothing);
    expect(detailsRoutes.any((route) => route.path == 'taste-passport'), isFalse);
  });

  testWidgets('refreshes living home rails once on mount (PullToRefresh refreshOnStart)', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    expect(harness.livingHomeNotifier.refreshCalls, greaterThanOrEqualTo(1));
    expect(harness.viewsNotifier.fetchViewsCalls, greaterThanOrEqualTo(1));
    expect(harness.dashboardNotifier.fetchCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('renders a Living Home rail once one is available', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(
      livingHome: LivingHomeModel(rails: [
        RecommendedModel(name: const BecauseYouWatched('Dune'), posters: [_poster('1')]),
      ]),
    ));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.livingHomeBecauseYouWatched('Dune')), findsOneWidget);
  });

  testWidgets('renders a Smart Shelf rail once one is available', (tester) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.build(
      smartShelves: [
        RecommendedModel(name: const Other('Unwatched Sci-Fi'), posters: [_poster('1')]),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Unwatched Sci-Fi'), findsOneWidget);
  });
}
