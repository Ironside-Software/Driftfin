import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/server_integration_config.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/sonarr_provider.dart';
import 'package:driftfin/providers/radarr_provider.dart';
import 'package:driftfin/providers/trakt_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/settings/client_sections/client_settings_integrations.dart';
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

/// Test double so we can drive plugin-managed state without the network.
class _FakeServerIntegrationConfig extends ServerIntegrationConfigNotifier {
  _FakeServerIntegrationConfig(super.ref, ServerIntegrationConfig? initial) {
    state = initial;
  }
}

Widget _harness(SharedPreferences prefs, ServerIntegrationConfig? config) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      serverIntegrationConfigProvider.overrideWith((ref) => _FakeServerIntegrationConfig(ref, config)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdaptiveLayout(
        data: _adaptiveModel,
        child: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => ListView(children: buildIntegrationSettings(context, ref)),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void useTallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('managed: integrations show "Managed by server" and disable the switches', (tester) async {
    useTallView(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    const managed = ServerIntegrationConfig(
      sonarr: ArrServerConfig(enabled: true, url: 'https://s', apiKey: 'k'),
      radarr: ArrServerConfig(enabled: true, url: 'https://r', apiKey: 'k'),
      trakt: TraktServerConfig(enabled: true, clientId: 'c', clientSecret: 's'),
    );

    await tester.pumpWidget(_harness(prefs, managed));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.managedByServerPlugin), findsNWidgets(3));

    // Every switch is disabled (onChanged == null) while managed.
    final switches = tester.widgetList<Switch>(find.byType(Switch));
    expect(switches, isNotEmpty);
    for (final s in switches) {
      expect(s.onChanged, isNull);
    }
  });

  testWidgets('unmanaged: fields are editable and persist via the prompt dialog', (tester) async {
    useTallView(tester);
    SharedPreferences.setMockInitialValues({
      'sonarrSettings': jsonEncode({'baseUrl': 'http://s', 'apiKey': 'k', 'enabled': true}),
      'radarrSettings': jsonEncode({'baseUrl': 'http://r', 'apiKey': 'k', 'enabled': true}),
      'traktSettings': jsonEncode({
        'clientId': 'c',
        'clientSecret': 's',
        'enabled': true,
        'tokens': {'accessToken': 'a', 'refreshToken': 'r', 'createdAt': 9999999999, 'expiresIn': 3600},
      }),
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_harness(prefs, null));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // No managed note when the plugin is absent.
    expect(find.text(l10n.managedByServerPlugin), findsNothing);

    final container = ProviderScope.containerOf(tester.element(find.byType(ListView)));

    // Save a value through the prompt dialog for every editable field
    // (covers each onTap closure + promptText + the setter).
    Future<void> editField(String title, String text) async {
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.text(l10n.save));
      await tester.pumpAndSettle();
    }

    await editField(l10n.sonarrUrlTitle, 'http://new-sonarr');
    await editField(l10n.sonarrApiKeyTitle, 'sonarr-key2');
    await editField(l10n.radarrUrlTitle, 'http://new-radarr');
    await editField(l10n.radarrApiKeyTitle, 'radarr-key2');
    await editField(l10n.traktClientId, 'cid2');
    await editField(l10n.traktClientSecret, 'secret2');

    expect(container.read(sonarrProvider).baseUrl, 'http://new-sonarr');
    expect(container.read(sonarrProvider).apiKey, 'sonarr-key2');
    expect(container.read(radarrProvider).baseUrl, 'http://new-radarr');
    expect(container.read(radarrProvider).apiKey, 'radarr-key2');
    expect(container.read(traktProvider).clientId, 'cid2');
    expect(container.read(traktProvider).clientSecret, 'secret2');

    // Cancel path leaves the value unchanged.
    await tester.tap(find.text(l10n.sonarrUrlTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();
    expect(container.read(sonarrProvider).baseUrl, 'http://new-sonarr');

    // Trakt is authenticated -> the action tile disconnects (no network).
    await tester.tap(find.text(l10n.traktDisconnect));
    await tester.pumpAndSettle();
    expect(container.read(traktProvider).isAuthenticated, isFalse);

    // Toggle each integration via its Switch (covers the onChanged closures).
    // The three section switches keep their order (sonarr, radarr, trakt) even
    // as field tiles collapse.
    await tester.tap(find.byType(Switch).at(0));
    await tester.pumpAndSettle();
    expect(container.read(sonarrProvider).enabled, isFalse);

    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(container.read(radarrProvider).enabled, isFalse);

    await tester.tap(find.byType(Switch).at(2));
    await tester.pumpAndSettle();
    expect(container.read(traktProvider).enabled, isFalse);
  });

  testWidgets('unmanaged: toggling an integration off hides its fields', (tester) async {
    useTallView(tester);
    SharedPreferences.setMockInitialValues({
      'sonarrSettings': jsonEncode({'baseUrl': 'http://s', 'apiKey': 'k', 'enabled': true}),
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_harness(prefs, null));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.sonarrUrlTitle), findsOneWidget);

    // Tap the Sonarr toggle tile to disable it.
    await tester.tap(find.text(l10n.sonarrIntegrationTitle));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(ListView)));
    expect(container.read(sonarrProvider).enabled, isFalse);
    expect(find.text(l10n.sonarrUrlTitle), findsNothing);
  });
}
