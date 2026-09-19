import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/settings/widgets/settings_search_field.dart';
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

// NOTE: selecting a result calls `context.tabsRouter.navigate(...)`, which
// needs a live AutoTabsRouter (see home_tabs_test.dart for why that's not
// reasonably stubbable here) — so this only exercises typing/filtering, never
// taps a result.
Widget _harness(SharedPreferences prefs) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdaptiveLayout(
        data: _adaptiveModel,
        child: Scaffold(body: SingleChildScrollView(child: SettingsSearchField())),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows nothing extra until the user types', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.noResults), findsNothing);
    expect(find.text('${l10n.theme} ${l10n.mode}'), findsNothing);
  });

  testWidgets('typing a query filters to matching settings tiles', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.enterText(find.byType(TextField), 'theme');
    await tester.pumpAndSettle();

    expect(find.text('${l10n.theme} ${l10n.mode}'), findsOneWidget);
    expect(find.text('${l10n.theme} ${l10n.color}'), findsOneWidget);
    expect(find.text(l10n.noResults), findsNothing);
  });

  testWidgets('a synonym-only match (wifi) still surfaces the setting', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs));

    await tester.enterText(find.byType(TextField), 'wifi');
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.clientSettingsRequireWifiTitle), findsOneWidget);
  });

  testWidgets('a query matching nothing shows the empty state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs));

    await tester.enterText(find.byType(TextField), 'xyzzy-not-a-real-setting');
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.noResults), findsOneWidget);
  });

  testWidgets('clearing the query hides the results again', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs));

    await tester.enterText(find.byType(TextField), 'theme');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.clear), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text('${l10n.theme} ${l10n.mode}'), findsNothing);
    expect(find.text(l10n.noResults), findsNothing);
  });
}
