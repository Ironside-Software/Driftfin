import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/server_integration_config.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/settings/widgets/seerr_connection_dialog.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';

/// Test double so we can drive plugin-managed state without the network.
class _FakeServerIntegrationConfig extends ServerIntegrationConfigNotifier {
  _FakeServerIntegrationConfig(super.ref, ServerIntegrationConfig? initial) {
    state = initial;
  }
}

/// Test double for [User] that starts with no account (so [userProvider]
/// reads return null and _refreshSession short-circuits without seerr creds).
class _FakeUser extends User {
  @override
  AccountModel? build() => null;
}

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

Widget _harness(SharedPreferences prefs) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      serverIntegrationConfigProvider.overrideWith((ref) => _FakeServerIntegrationConfig(ref, null)),
      userProvider.overrideWith(_FakeUser.new),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdaptiveLayout(
        data: _phoneModel,
        child: Scaffold(
          body: SeerrConnectionDialog(),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> mockPrefs() async {
    SharedPreferences.setMockInitialValues({});
    return SharedPreferences.getInstance();
  }

  testWidgets('not logged in: renders the auth tabs (jellyfin/local/apiKey)', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await mockPrefs();
    await tester.pumpWidget(_harness(prefs));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.seerrAuthJellyfin), findsOneWidget);
    expect(find.text(l10n.seerrAuthLocal), findsOneWidget);
    expect(find.text(l10n.seerrAuthApiKey), findsOneWidget);
    expect(find.byType(SegmentedButton<SeerrAuthTab>), findsOneWidget);
  });

  testWidgets('switching tabs via SegmentedButton shows the matching form fields', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await mockPrefs();
    await tester.pumpWidget(_harness(prefs));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Default tab is jellyfin -> username/password fields visible.
    expect(find.text(l10n.username), findsOneWidget);

    // Switch to the local tab.
    await tester.tap(find.text(l10n.seerrAuthLocal));
    await tester.pumpAndSettle();
    expect(find.text(l10n.emailUsername), findsOneWidget);

    // Switch to the apiKey tab.
    await tester.tap(find.text(l10n.seerrAuthApiKey));
    await tester.pumpAndSettle();
    expect(find.text(l10n.seerrAuthApiKey), findsWidgets);
  });

  testWidgets('entering text into the server URL field updates the controller', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await mockPrefs();
    await tester.pumpWidget(_harness(prefs));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final serverField = find.widgetWithText(TextField, l10n.seerrServer).evaluate().isNotEmpty
        ? find.widgetWithText(TextField, l10n.seerrServer)
        : find.byType(TextField).first;

    await tester.enterText(serverField, 'https://seerr.example.com');
    await tester.pump();

    expect(find.text('https://seerr.example.com'), findsOneWidget);
  });
}
