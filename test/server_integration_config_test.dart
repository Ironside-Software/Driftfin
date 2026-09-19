import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/models/server_integration_config.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/radarr_provider.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/sonarr_provider.dart';
import 'package:driftfin/providers/trakt_provider.dart';

/// Test double for the plugin config provider so we can drive managed state
/// without hitting the network.
class _FakeServerIntegrationConfig extends ServerIntegrationConfigNotifier {
  _FakeServerIntegrationConfig(super.ref, ServerIntegrationConfig? initial) {
    state = initial;
  }

  void emit(ServerIntegrationConfig? config) => state = config;
}

ProviderContainer _container(SharedPreferences prefs, ServerIntegrationConfig? initial) {
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      serverIntegrationConfigProvider.overrideWith((ref) => _FakeServerIntegrationConfig(ref, initial)),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServerIntegrationConfig.fromJson', () {
    test('parses nested camelCase groups', () {
      final config = ServerIntegrationConfig.fromJson({
        'seerr': {'enabled': true, 'url': 'https://seerr', 'apiKey': 'k1'},
        'sonarr': {'enabled': true, 'url': 'https://sonarr', 'apiKey': 'k2'},
        'radarr': {'enabled': false, 'url': 'https://radarr', 'apiKey': 'k3'},
        'trakt': {'enabled': true, 'clientId': 'cid', 'clientSecret': 'sec'},
      });

      expect(config.seerr.url, 'https://seerr');
      expect(config.seerr.isManaged, isTrue);
      expect(config.sonarr.isManaged, isTrue);
      expect(config.radarr.isManaged, isFalse, reason: 'disabled is never managed');
      expect(config.trakt.clientId, 'cid');
      expect(config.trakt.isManaged, isTrue);
      expect(config.anyManaged, isTrue);
    });

    test('missing/garbage keys fall back to empty + unmanaged', () {
      final empty = ServerIntegrationConfig.fromJson({});
      expect(empty.anyManaged, isFalse);
      expect(empty.sonarr.url, '');

      final garbage = ServerIntegrationConfig.fromJson({'sonarr': 'not-an-object'});
      expect(garbage.sonarr.isManaged, isFalse);
    });

    test('enabled but incomplete config is not managed', () {
      const noKey = ArrServerConfig(enabled: true, url: 'https://x', apiKey: '');
      const noUrl = ArrServerConfig(enabled: true, url: '  ', apiKey: 'k');
      const noSecret = TraktServerConfig(enabled: true, clientId: 'c', clientSecret: '');
      expect(noKey.isManaged, isFalse);
      expect(noUrl.isManaged, isFalse);
      expect(noSecret.isManaged, isFalse);
    });

    test('json round-trip', () {
      const original = ServerIntegrationConfig(
        seerr: SeerrServerConfig(enabled: true, url: 'u', apiKey: 'k'),
        sonarr: ArrServerConfig(enabled: true, url: 's', apiKey: 'sk'),
        trakt: TraktServerConfig(enabled: true, clientId: 'c', clientSecret: 's'),
      );
      final restored = ServerIntegrationConfig.fromJson(original.toJson());
      expect(restored.seerr.apiKey, 'k');
      expect(restored.sonarr.url, 's');
      expect(restored.trakt.clientSecret, 's');
    });
  });

  group('fetchServerIntegrationConfig', () {
    final body = jsonEncode({
      'sonarr': {'enabled': true, 'url': 'https://s', 'apiKey': 'k'},
    });

    test('returns parsed config on 200', () async {
      final client = MockClient((_) async => http.Response(body, 200));
      final config = await fetchServerIntegrationConfig('http://server/Driftfin/Config', const {}, client);
      expect(config, isNotNull);
      expect(config!.sonarr.isManaged, isTrue);
    });

    test('null on 404 (plugin not installed)', () async {
      final client = MockClient((_) async => http.Response('', 404));
      expect(await fetchServerIntegrationConfig('http://server/Driftfin/Config', const {}, client), isNull);
    });

    test('null on empty 200 body', () async {
      final client = MockClient((_) async => http.Response('', 200));
      expect(await fetchServerIntegrationConfig('http://server/Driftfin/Config', const {}, client), isNull);
    });

    test('null when body is valid JSON but not an object', () async {
      final client = MockClient((_) async => http.Response('123', 200));
      expect(await fetchServerIntegrationConfig('http://server/Driftfin/Config', const {}, client), isNull);
    });

    test('null when the request throws', () async {
      final client = MockClient((_) async => throw Exception('boom'));
      expect(await fetchServerIntegrationConfig('http://server/Driftfin/Config', const {}, client), isNull);
    });
  });

  group('fetchServerIntegrationConfigDiagnostic reports the specific reason', () {
    const url = 'http://server/Driftfin/Config';

    test('ok on 200 with a config', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'sonarr': {'enabled': true},
          }),
          200,
        ),
      );
      final result = await fetchServerIntegrationConfigDiagnostic(url, const {}, client);
      expect(result.status, ServerIntegrationConfigStatus.ok);
      expect(result.config, isNotNull);
    });

    test('retired legacy contract marks the server managed without importing credentials', () async {
      final client = MockClient((_) async => http.Response('{"reason":"upgrade_required"}', 426));
      final result = await fetchServerIntegrationConfigDiagnostic(url, const {}, client);
      expect(result.status, ServerIntegrationConfigStatus.incompatible);
      expect(result.config?.managedProtocol, isTrue);
      expect(result.config?.seerr.apiKey, isEmpty);
      expect(result.detail, 'upgrade_required');
    });

    test('noPlugin on 404', () async {
      final client = MockClient((_) async => http.Response('', 404));
      final result = await fetchServerIntegrationConfigDiagnostic(url, const {}, client);
      expect(result.status, ServerIntegrationConfigStatus.noPlugin);
    });

    test('httpError with the status code as detail on a 500 (the Jellyfin 10.11 auth bug)', () async {
      final client = MockClient((_) async => http.Response('Error processing request.', 500));
      final result = await fetchServerIntegrationConfigDiagnostic(url, const {}, client);
      expect(result.status, ServerIntegrationConfigStatus.httpError);
      expect(result.detail, '500');
    });

    test('httpError on an empty 200 body', () async {
      final client = MockClient((_) async => http.Response('', 200));
      final result = await fetchServerIntegrationConfigDiagnostic(url, const {}, client);
      expect(result.status, ServerIntegrationConfigStatus.httpError);
    });

    test('invalidResponse when the body is valid JSON but not an object', () async {
      final client = MockClient((_) async => http.Response('123', 200));
      final result = await fetchServerIntegrationConfigDiagnostic(url, const {}, client);
      expect(result.status, ServerIntegrationConfigStatus.invalidResponse);
    });

    test('requestFailed redacts the exception text on a network/timeout failure', () async {
      final client = MockClient((_) async => throw Exception('boom'));
      final result = await fetchServerIntegrationConfigDiagnostic(url, const {}, client);
      expect(result.status, ServerIntegrationConfigStatus.requestFailed);
      expect(result.detail, isNot(contains('boom')));
    });
  });

  group('managed flag is transient (survives plugin removal)', () {
    test('Sonarr/Radarr settings never serialize the managed flag', () {
      const sonarr = SonarrSettings(baseUrl: 'u', apiKey: 'k', enabled: true, managed: true);
      const radarr = RadarrSettings(baseUrl: 'u', apiKey: 'k', enabled: true, managed: true);
      expect(sonarr.toJson().containsKey('managed'), isFalse);
      expect(radarr.toJson().containsKey('managed'), isFalse);
      expect(SonarrSettings.fromJson(sonarr.toJson()).managed, isFalse);
      expect(RadarrSettings.fromJson(radarr.toJson()).managed, isFalse);
    });

    test('Trakt settings never serialize the managed flag', () {
      const trakt = TraktSettings(clientId: 'c', clientSecret: 's', enabled: true, managed: true);
      expect(trakt.toJson().containsKey('managed'), isFalse);
      expect(TraktSettings.fromJson(trakt.toJson()).managed, isFalse);
    });
  });

  group('integration providers + server plugin', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('load() with no server URL leaves config null; clear() resets', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs), serverUrlProvider.overrideWith((ref) => '')],
      );
      addTearDown(container.dispose);

      final notifier = container.read(serverIntegrationConfigProvider.notifier);
      await notifier.load();
      expect(container.read(serverIntegrationConfigProvider), isNull);

      notifier.clear();
      expect(container.read(serverIntegrationConfigProvider), isNull);
    });

    test('absent plugin → providers use local prefs, fully editable', () {
      final container = _container(prefs, null);
      addTearDown(container.dispose);

      container.read(sonarrProvider.notifier).setEnabled(true);
      container.read(sonarrProvider.notifier).setBaseUrl('http://local-sonarr');
      container.read(sonarrProvider.notifier).setApiKey('local-key');
      container.read(radarrProvider.notifier).setEnabled(true);
      container.read(radarrProvider.notifier).setBaseUrl('http://local-radarr');
      container.read(radarrProvider.notifier).setApiKey('radar-key');
      container.read(traktProvider.notifier).setEnabled(true);
      container.read(traktProvider.notifier).setClientId('cid');
      container.read(traktProvider.notifier).setClientSecret('sec');

      expect(container.read(sonarrProvider).managed, isFalse);
      expect(container.read(sonarrProvider).baseUrl, 'http://local-sonarr');
      expect(container.read(radarrProvider).apiKey, 'radar-key');
      expect(container.read(traktProvider).clientId, 'cid');
    });

    test('emitting managed config after build applies it via the listener', () async {
      final container = _container(prefs, null);
      addTearDown(container.dispose);

      // Build providers unmanaged first.
      expect(container.read(sonarrProvider).managed, isFalse);
      expect(container.read(radarrProvider).managed, isFalse);
      expect(container.read(traktProvider).managed, isFalse);

      const managed = ServerIntegrationConfig(
        sonarr: ArrServerConfig(enabled: true, url: 'https://s', apiKey: 'k'),
        radarr: ArrServerConfig(enabled: true, url: 'https://r', apiKey: 'k'),
        trakt: TraktServerConfig(enabled: true, clientId: 'c', clientSecret: 's'),
      );
      (container.read(serverIntegrationConfigProvider.notifier) as _FakeServerIntegrationConfig).emit(managed);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(sonarrProvider).managed, isTrue);
      expect(container.read(sonarrProvider).baseUrl, 'https://s');
      expect(container.read(radarrProvider).managed, isTrue);
      expect(container.read(radarrProvider).baseUrl, 'https://r');
      expect(container.read(traktProvider).managed, isTrue);
      expect(container.read(traktProvider).clientId, 'c');
    });

    test('Sonarr: managed overrides local, locks setters, reverts on removal', () async {
      const managed = ServerIntegrationConfig(
        sonarr: ArrServerConfig(enabled: true, url: 'https://server-sonarr/', apiKey: 'server-key'),
      );
      final container = _container(prefs, managed);
      addTearDown(container.dispose);

      final state = container.read(sonarrProvider);
      expect(state.managed, isTrue);
      expect(state.baseUrl, 'https://server-sonarr', reason: 'normalized (trailing slash stripped)');
      expect(state.apiKey, 'server-key');

      // Setters are no-ops while managed.
      container.read(sonarrProvider.notifier).setBaseUrl('http://hacked');
      container.read(sonarrProvider.notifier).setApiKey('hacked');
      container.read(sonarrProvider.notifier).setEnabled(false);
      final after = container.read(sonarrProvider);
      expect(after.baseUrl, 'https://server-sonarr');
      expect(after.enabled, isTrue);

      // Plugin removed -> revert to local (empty) prefs.
      (container.read(serverIntegrationConfigProvider.notifier) as _FakeServerIntegrationConfig).emit(null);
      await Future<void>.delayed(Duration.zero); // let the ref.listen callback run
      expect(container.read(sonarrProvider).managed, isFalse);
      expect(container.read(sonarrProvider).baseUrl, '');
    });

    test('Radarr: removing the plugin reverts to the stored local config', () async {
      // Seed a local Radarr config in prefs first.
      final seed = _container(prefs, null);
      seed.read(radarrProvider.notifier).setEnabled(true);
      seed.read(radarrProvider.notifier).setBaseUrl('http://local-radarr');
      seed.read(radarrProvider.notifier).setApiKey('local-key');
      seed.dispose();

      const managed = ServerIntegrationConfig(
        radarr: ArrServerConfig(enabled: true, url: 'https://server-radarr', apiKey: 'server-key'),
      );
      final container = _container(prefs, managed);
      addTearDown(container.dispose);

      expect(container.read(radarrProvider).managed, isTrue);
      expect(container.read(radarrProvider).baseUrl, 'https://server-radarr');

      // Locked while managed.
      container.read(radarrProvider.notifier).setBaseUrl('http://hacked');
      expect(container.read(radarrProvider).baseUrl, 'https://server-radarr');

      // Plugin goes away -> revert to the local prefs we seeded.
      (container.read(serverIntegrationConfigProvider.notifier) as _FakeServerIntegrationConfig).emit(null);
      await Future<void>.delayed(Duration.zero); // let the ref.listen callback run
      final reverted = container.read(radarrProvider);
      expect(reverted.managed, isFalse);
      expect(reverted.baseUrl, 'http://local-radarr');
      expect(reverted.apiKey, 'local-key');
    });

    test('Trakt: managed overlays credentials, keeps tokens, reverts on removal', () async {
      const managed = ServerIntegrationConfig(
        trakt: TraktServerConfig(enabled: true, clientId: 'server-cid', clientSecret: 'server-sec'),
      );
      final container = _container(prefs, managed);
      addTearDown(container.dispose);

      final state = container.read(traktProvider);
      expect(state.managed, isTrue);
      expect(state.clientId, 'server-cid');
      expect(state.enabled, isTrue);

      // Credential setters are locked.
      container.read(traktProvider.notifier).setClientId('hacked');
      container.read(traktProvider.notifier).setClientSecret('hacked');
      container.read(traktProvider.notifier).setEnabled(false);
      expect(container.read(traktProvider).clientId, 'server-cid');
      expect(container.read(traktProvider).enabled, isTrue);

      (container.read(serverIntegrationConfigProvider.notifier) as _FakeServerIntegrationConfig).emit(null);
      await Future<void>.delayed(Duration.zero); // let the ref.listen callback run
      expect(container.read(traktProvider).managed, isFalse);
    });
  });
}
