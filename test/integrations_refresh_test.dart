import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/providers/seerr_user_provider.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/settings/integrations_settings_page.dart';
import 'package:driftfin/screens/settings/settings_list_tile.dart';
import 'package:driftfin/seerr/seerr_models.dart';
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

class _FakeSeerrUser extends SeerrUser {
  @override
  SeerrUserModel? build() => null;
}

/// Returns a fixed diagnostic result so the page's status→message mapping can
/// be exercised without any network.
class _FakeDiagNotifier extends ServerIntegrationConfigNotifier {
  _FakeDiagNotifier(super.ref, this._result);
  final ({ServerIntegrationConfigStatus status, String? detail}) _result;

  @override
  Future<({ServerIntegrationConfigStatus status, String? detail})> loadWithDiagnostics() async => _result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;
  setUpAll(() async => l10n = await AppLocalizations.delegate.load(const Locale('en')));

  final user = AccountModel(
    name: 'Tester',
    id: 'user-1',
    avatar: '',
    lastUsed: DateTime(2024),
    credentials: CredentialsModel.internal(url: 'http://server', deviceId: 'device-1'),
    userSettings: UserSettings(),
  );

  void useTallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpAndRefresh(
    WidgetTester tester,
    ServerIntegrationConfigStatus status, {
    String? detail,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userProvider.overrideWith(() => _FakeUser(user)),
          seerrUserProvider.overrideWith(() => _FakeSeerrUser()),
          serverIntegrationConfigProvider
              .overrideWith((ref) => _FakeDiagNotifier(ref, (status: status, detail: detail))),
        ],
        // AdaptiveLayout above MaterialApp so the FladderSnack overlay resolves it.
        child: const AdaptiveLayout(
          data: _adaptiveModel,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: IntegrationsSettingsPage()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final refreshTile = tester
        .widgetList<SettingsListTile>(find.byType(SettingsListTile))
        .firstWhere((t) => (t.label as Text).data == l10n.refresh);
    refreshTile.onTap!();
    await tester.pump(); // run _refreshServerConfig + show the snack
    await tester.pump(const Duration(milliseconds: 350)); // snack fade-in
  }

  // Drains the FladderSnack's 5s auto-dismiss timer so nothing outlives a test.
  Future<void> drainSnack(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('ok → success message', (tester) async {
    useTallView(tester);
    await pumpAndRefresh(tester, ServerIntegrationConfigStatus.ok);
    expect(find.text(l10n.settingsIntegrationsRefreshSuccess), findsOneWidget);
    await drainSnack(tester);
  });

  testWidgets('404 → plugin-not-installed message', (tester) async {
    useTallView(tester);
    await pumpAndRefresh(tester, ServerIntegrationConfigStatus.noPlugin);
    expect(find.text(l10n.settingsIntegrationsPluginNotInstalled), findsOneWidget);
    await drainSnack(tester);
  });

  testWidgets('500 → server-error message with the status code', (tester) async {
    useTallView(tester);
    await pumpAndRefresh(tester, ServerIntegrationConfigStatus.httpError, detail: '500');
    expect(find.text('${l10n.settingsIntegrationsServerError} (500)'), findsOneWidget);
    await drainSnack(tester);
  });

  testWidgets('network failure → unreachable message', (tester) async {
    useTallView(tester);
    await pumpAndRefresh(tester, ServerIntegrationConfigStatus.requestFailed);
    expect(find.text(l10n.settingsIntegrationsUnreachable), findsOneWidget);
    await drainSnack(tester);
  });

  testWidgets('invalid response → generic message', (tester) async {
    useTallView(tester);
    await pumpAndRefresh(tester, ServerIntegrationConfigStatus.invalidResponse);
    expect(find.text(l10n.somethingWentWrong), findsOneWidget);
    await drainSnack(tester);
  });
}
