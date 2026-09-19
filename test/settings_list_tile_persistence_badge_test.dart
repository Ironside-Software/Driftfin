import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/settings/settings_entry.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/settings/settings_list_tile.dart';
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

Widget _harness(SharedPreferences prefs, SettingId id) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdaptiveLayout(
        data: _adaptiveModel,
        child: Scaffold(
          body: SettingsListTile(id: id, label: const Text('Some setting')),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a synced setting shows the "syncs across devices" badge', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_harness(prefs, SettingId.themeMode));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.settingsSyncsAcrossDevices), findsOneWidget);
    expect(find.text(l10n.settingsStaysOnDevice), findsNothing);
  });

  testWidgets('a device-local setting shows the "stays on this device" badge', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_harness(prefs, SettingId.downloadsMaxConcurrent));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.settingsStaysOnDevice), findsOneWidget);
    expect(find.text(l10n.settingsSyncsAcrossDevices), findsNothing);
  });

  testWidgets('no id means no persistence badge is rendered', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdaptiveLayout(
            data: _adaptiveModel,
            child: Scaffold(body: SettingsListTile(label: Text('No badge here'))),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.settingsStaysOnDevice), findsNothing);
    expect(find.text(l10n.settingsSyncsAcrossDevices), findsNothing);
    expect(find.text(l10n.managedByServerPlugin), findsNothing);
  });
}
