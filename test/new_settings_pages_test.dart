import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/seerr/seerr_models.dart';
import 'package:driftfin/providers/cultures_provider.dart';
import 'package:driftfin/providers/home_collections_provider.dart';
import 'package:driftfin/providers/home_preferences_provider.dart';
import 'package:driftfin/providers/seerr_user_provider.dart';
import 'package:driftfin/providers/settings/client_settings_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/sync_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/screens/settings/settings_list_tile.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/settings/account_device_settings_page.dart';
import 'package:driftfin/screens/settings/appearance_settings_page.dart';
import 'package:driftfin/screens/settings/downloads_settings_page.dart';
import 'package:driftfin/screens/settings/home_library_settings_page.dart';
import 'package:driftfin/screens/settings/integrations_settings_page.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';

const _adaptiveModel = AdaptiveLayoutModel(
  viewSize: ViewSize.desktop,
  layoutMode: LayoutMode.single,
  inputDevice: InputDevice.pointer,
  platform: TargetPlatform.linux,
  isDesktop: true,
  posterDefaults: PosterDefaults(size: 100, ratio: 0.66),
  controller: <HomeTabs, ScrollController>{},
  sideBarWidth: 0,
  topBarHeight: 0,
  statusBarHeight: 0,
);

class _FakeUser extends User {
  _FakeUser(this._initial);
  final AccountModel? _initial;

  @override
  AccountModel? build() => _initial;
}

/// Returns an empty culture list without hitting the API (the real notifier
/// fetches from Jellyfin in build()).
class _FakeCultures extends Cultures {
  @override
  List<CultureDto> build() => const [];
}

/// Never resolves a Seerr user (the real notifier reads seerrApiProvider).
class _FakeSeerrUser extends SeerrUser {
  @override
  SeerrUserModel? build() => null;
}

/// No-op load so the Home & Library page doesn't call the Jellyfin API in its
/// initState post-frame callback.
class _FakeHomePreferences extends HomePreferencesNotifier {
  _FakeHomePreferences(super.ref);

  @override
  Future<void> load() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;
  late Directory tempDir;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    tempDir = Directory.systemTemp.createTempSync('driftfin_settings_test');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  final credentials = CredentialsModel(url: 'http://server', deviceId: 'device-1');
  final user = AccountModel(
    name: 'Tester',
    id: 'user-1',
    avatar: '',
    lastUsed: DateTime(2024),
    credentials: credentials,
    userSettings: UserSettings(),
  );

  void useTallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpPage(WidgetTester tester, Widget page, {List<Override> overrides = const []}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userProvider.overrideWith(() => _FakeUser(user)),
          ...overrides,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdaptiveLayout(data: _adaptiveModel, child: page),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('Appearance page renders its theme + visual builder groups', (tester) async {
    useTallView(tester);
    await pumpPage(tester, const AppearanceSettingsPage());

    expect(find.text(l10n.settingsAppearanceTitle), findsWidgets);
    // A theme-group tile and the new reduce-animations tile both render.
    expect(find.text(l10n.itemColorsTitle), findsOneWidget);
    expect(find.text(l10n.reduceAnimationsTitle), findsOneWidget);

    // Toggle "reduce animations" through the tile's Switch to exercise the
    // onChanged wiring and the client-settings setter.
    final container = ProviderScope.containerOf(tester.element(find.byType(AppearanceSettingsPage)));
    expect(container.read(clientSettingsProvider).reduceAnimations, isFalse);
    final switchFinder = find.descendant(
      of: find.ancestor(of: find.text(l10n.reduceAnimationsTitle), matching: find.byType(SettingsListTile)),
      matching: find.byType(Switch),
    );
    tester.widget<Switch>(switchFinder).onChanged!(true);
    await tester.pump();
    expect(container.read(clientSettingsProvider).reduceAnimations, isTrue);
    // Flush the client-settings debounced persistence timer.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Home & Library page renders its dashboard + library-order groups', (tester) async {
    useTallView(tester);
    await pumpPage(
      tester,
      const HomeLibrarySettingsPage(),
      overrides: [
        homePreferencesProvider.overrideWith((ref) => _FakeHomePreferences(ref)),
        homeCollectionsProvider.overrideWith((ref) => Future.value(const [])),
      ],
    );

    expect(find.text(l10n.settingsHomeLibraryTitle), findsWidgets);
  });

  testWidgets('Downloads & Offline page renders its download builder group', (tester) async {
    useTallView(tester);
    await pumpPage(
      tester,
      const DownloadsSettingsPage(),
      overrides: [syncProvider.overrideWith((ref) => SyncNotifier(ref, tempDir))],
    );

    expect(find.text(l10n.settingsDownloadsOfflineTitle), findsWidgets);
  });

  testWidgets('Integrations page renders Seerr + arr integration groups', (tester) async {
    useTallView(tester);
    await pumpPage(
      tester,
      const IntegrationsSettingsPage(),
      overrides: [seerrUserProvider.overrideWith(() => _FakeSeerrUser())],
    );

    expect(find.text(l10n.settingsIntegrationsTitle), findsWidgets);
    // Seerr appears both as the section divider and the tile label.
    expect(find.text(l10n.seerr), findsWidgets);
    // The lifted *arr integration builder group rendered too.
    expect(find.text(l10n.sonarrIntegrationTitle), findsOneWidget);
    expect(find.text(l10n.radarrIntegrationTitle), findsOneWidget);
  });

  testWidgets('Account & Device page renders account/device/sync groups', (tester) async {
    useTallView(tester);
    await pumpPage(
      tester,
      const AccountDeviceSettingsPage(),
      overrides: [culturesProvider.overrideWith(() => _FakeCultures())],
    );

    expect(find.text(l10n.settingsAccountDeviceTitle), findsWidgets);
    expect(find.text(l10n.settingsAccountSectionTitle), findsOneWidget);
    expect(find.text(l10n.settingsSyncBackupSectionTitle), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(AccountDeviceSettingsPage)));

    // Toggle the mouse-drag device setting via its Switch.
    final mouseDragSwitch = find.descendant(
      of: find.ancestor(of: find.text(l10n.mouseDragSupport), matching: find.byType(SettingsListTile)),
      matching: find.byType(Switch),
    );
    tester.widget<Switch>(mouseDragSwitch).onChanged!(true);
    await tester.pump();
    expect(container.read(clientSettingsProvider).mouseDragSupport, isTrue);

    // Sync is always on now (no toggle), so the "Sync now" action is present.
    expect(find.text(l10n.syncNow), findsOneWidget);

    // Flush the client-settings (1s) and config-sync push (2s) debounce timers.
    await tester.pump(const Duration(seconds: 3));
  });
}
