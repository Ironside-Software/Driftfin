import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/providers/connectivity_provider.dart';
import 'package:driftfin/providers/playlist_provider.dart';
import 'package:driftfin/providers/update_provider.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';
import 'package:driftfin/widgets/navigation_scaffold/components/navigation_button.dart';
import 'package:driftfin/widgets/navigation_scaffold/components/navigation_drawer.dart';
import 'package:driftfin/widgets/navigation_scaffold/components/side_navigation_bar.dart';

final _offline = StateProvider<bool>((ref) => false);

class _Router extends RootStackRouter {
  _Router(this.child);
  final Widget child;

  @override
  List<AutoRoute> get routes => [NamedRouteDef(name: 'NavigationTest', path: '/', builder: (_, _) => child)];
}

void main() {
  for (final drawer in [false, true]) {
    testWidgets('${drawer ? 'drawer' : 'desktop rail'} hides Calendar offline and restores it online', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey<ScaffoldState>();
      final router = _Router(
        Scaffold(
          key: key,
          body: drawer
              ? NestedNavigationDrawer(
                  toggleExpanded: (_) {},
                  destinations: const [],
                  views: const [],
                  currentLocation: 'NavigationTest',
                  currentIndex: 0,
                )
              : SideNavigationRail(
                  currentIndex: 0,
                  destinations: const [],
                  currentLocation: 'NavigationTest',
                  scaffoldKey: key,
                  child: const SizedBox.expand(),
                ),
        ),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            offlineStateProvider.overrideWith((ref) => ref.watch(_offline)),
            playlistProvider.overrideWith((ref) => PlaylistNotifier(ref)),
            hasNewUpdateProvider.overrideWithValue(false),
          ],
          child: AdaptiveLayout(
            data: const AdaptiveLayoutModel(
              viewSize: ViewSize.desktop,
              layoutMode: LayoutMode.dual,
              inputDevice: InputDevice.pointer,
              platform: TargetPlatform.linux,
              isDesktop: true,
              posterDefaults: PosterDefaults(size: 100, ratio: 0.66),
              controller: {},
              sideBarWidth: 0,
              topBarHeight: 0,
              statusBarHeight: 0,
            ),
            child: MaterialApp.router(
              routerConfig: router.config(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(NavigationButton).first);
      final container = ProviderScope.containerOf(context);
      final l10n = AppLocalizations.of(context);
      final calendar = find.byWidgetPredicate(
        (widget) => widget is NavigationButton && widget.label == l10n.calendarTitle,
      );
      final settings = find.byWidgetPredicate((widget) => widget is NavigationButton && widget.label == l10n.settings);
      expect(calendar, findsOneWidget);
      container.read(_offline.notifier).state = true;
      await tester.pumpAndSettle();
      expect(calendar, findsNothing);
      expect(settings, findsOneWidget);
      container.read(_offline.notifier).state = false;
      await tester.pumpAndSettle();
      expect(calendar, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
