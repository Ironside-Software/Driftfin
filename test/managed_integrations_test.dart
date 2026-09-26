import 'dart:async';
import 'dart:convert';

import 'package:chopper/chopper.dart' as chopper;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/util/managed_seerr_request.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/models/plugin_capabilities.dart';
import 'package:driftfin/models/seerr_credentials_model.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/connectivity_provider.dart';
import 'package:driftfin/providers/seerr_api_provider.dart';
import 'package:driftfin/providers/sonarr_provider.dart';
import 'package:driftfin/providers/radarr_provider.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/util/notification_helpers.dart';

class _User extends User {
  _User(this.account);
  final AccountModel account;
  @override
  AccountModel build() => account;
  @override
  set userState(AccountModel? value) => state = value;
}

AccountModel _account({String id = 'alice', bool managed = false, CredentialOrigin origin = CredentialOrigin.manual}) =>
    AccountModel(
      id: id,
      name: id,
      avatar: '',
      lastUsed: DateTime(2026),
      managedIntegrations: managed,
      credentials: CredentialsModel(
        url: 'https://jellyfin.test/base',
        serverId: 'server',
        token: '$id-token',
        deviceId: 'device',
      ),
      seerrCredentials: SeerrCredentialsModel(
        serverUrl: 'https://private-seerr.test',
        apiKey: 'direct-key',
        sessionCookie: 'direct-cookie',
        customHeaders: const {'X-API-User': '1', 'X-Secret': 'private'},
        origin: origin,
      ),
    );

Map<String, dynamic> _capabilities({int protocol = 1}) => {
  'protocolVersion': protocol,
  'pluginVersion': '3.0.0.0',
  'features': {
    'discovery': {'supported': true, 'allowed': true},
    'diagnostics': {'supported': true, 'allowed': false, 'reason': 'permission_denied'},
  },
  'integrations': <String, dynamic>{
    'seerr': {'configured': true, 'healthy': true},
  },
};

ProviderContainer _container(http.Client client, {AccountModel? account, SharedPreferences? preferences}) {
  final container = ProviderContainer(
    overrides: [
      if (preferences != null) sharedPreferencesProvider.overrideWithValue(preferences),
      userProvider.overrideWith(() => _User(account ?? _account())),
      serverUrlProvider.overrideWith(
        (ref) => ref.watch(localConnectionAvailableProvider)
            ? 'http://jellyfin.lan:8096/base'
            : ref.watch(userProvider)?.credentials.url,
      ),
      serverIntegrationConfigProvider.overrideWith((ref) => ServerIntegrationConfigNotifier(ref, client: client)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('managed transport preserves encoded and generated query parameters', () {
    final base = Uri.parse('https://seerr.test');
    for (final request in [
      chopper.Request(
        'GET',
        Uri.parse('/api/v1/search'),
        base,
        parameters: {'query': 'fight & club', 'page': 2, 'language': 'en-US'},
      ),
      chopper.Request('GET', Uri.parse('/api/v1/search?query=fight%20%26%20club&page=2&language=en-US'), base),
      chopper.Request(
        'GET',
        Uri.parse('/api/v1/request'),
        base,
        parameters: {'take': 20, 'skip': 40, 'requestedBy': 42, 'filter': 'pending'},
      ),
    ]) {
      final managed = managedSeerrRequest(request, 'https://jellyfin.test/base', {});
      expect(managed.url.queryParametersAll, request.url.queryParametersAll);
      expect(managed.url.path, startsWith('/base/Driftfin/v1/seerr/'));
    }
  });

  test('plugin data loads automatically without an account refresh', () async {
    final paths = <String>[];
    final container = _container(
      MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(jsonEncode(_capabilities()), 200);
      }),
    );

    container.read(serverIntegrationConfigProvider);
    await Future<void>.delayed(Duration.zero);
    expect(paths, ['/base/Driftfin/v1/capabilities']);
    expect(container.read(seerrAvailableProvider), isTrue);
    expect(container.read(serverIntegrationConnectionProvider), ServerIntegrationConfigStatus.ok);
  });

  test('automatic bootstrap persists settings through the real user provider', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final caps = _capabilities()..['localUrl'] = 'http://jellyfin.lan:8096';
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        serverUrlProvider.overrideWith(
          (ref) => ref.watch(localConnectionAvailableProvider)
              ? 'http://jellyfin.lan:8096/base'
              : ref.watch(userProvider)?.credentials.url,
        ),
        serverIntegrationConfigProvider.overrideWith(
          (ref) => ServerIntegrationConfigNotifier(
            ref,
            client: MockClient((_) async => http.Response(jsonEncode(caps), 200)),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sharedUtilityProvider).addAccount(_account());
    container.read(userProvider.notifier).loginUser(_account());
    container.read(serverIntegrationConfigProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(seerrAvailableProvider), isTrue);
    expect(container.read(userProvider)?.credentials.localUrl, 'http://jellyfin.lan:8096');
    expect(container.read(sharedUtilityProvider).getAccounts().single.managedIntegrations, isTrue);
  });

  test('automatic loading follows login, account switches and address changes', () async {
    final requests = <http.Request>[];
    final container = _container(
      MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(_capabilities()), 200);
      }),
    );
    final user = container.read(userProvider.notifier);
    user.clear();
    container.listen(serverIntegrationConfigProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(requests, isEmpty);

    user.loginUser(_account());
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(1));
    expect(container.read(seerrAvailableProvider), isTrue);

    user.loginUser(_account(id: 'bob'));
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(2));
    container.read(localConnectionAvailableProvider.notifier).state = true;
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(3));
    expect(requests.last.url.host, 'jellyfin.lan');

    user.clear();
    await Future<void>.delayed(Duration.zero);
    expect(requests, hasLength(3));
    expect(container.read(serverIntegrationConfigProvider), isNull);
    expect(container.read(serverIntegrationConnectionProvider), ServerIntegrationConfigStatus.notLoggedIn);
  });

  test('managed bootstrap carries only the compatible Jellyfin LAN address', () async {
    final caps = _capabilities()..['localUrl'] = 'http://jellyfin.lan:8096/base';
    final container = _container(MockClient((_) async => http.Response(jsonEncode(caps), 200)));
    await container.read(serverIntegrationConfigProvider.notifier).load();
    expect(container.read(serverIntegrationConfigProvider)?.localUrl, 'http://jellyfin.lan:8096/base');
    expect(container.read(userProvider)?.credentials.localUrl, 'http://jellyfin.lan:8096/base');
    caps['protocolVersion'] = 2;
    await container.read(serverIntegrationConfigProvider.notifier).load();
    expect(container.read(serverIntegrationConfigProvider)?.localUrl, isEmpty);
  });

  test('manual recovery survives restart without reopening legacy credential negotiation', () async {
    SharedPreferences.setMockInitialValues({
      for (final service in ['sonarr', 'radarr'])
        '${service}Settings': jsonEncode({
          'baseUrl': 'http://$service',
          'apiKey': 'manual-key',
          'enabled': true,
          'origin': 'manual',
        }),
    });
    final prefs = await SharedPreferences.getInstance();
    var installed = false;
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(installed ? jsonEncode(_capabilities()) : '', installed ? 200 : 404);
    });
    final container = _container(client, account: _account(managed: true), preferences: prefs);
    final notifier = container.read(serverIntegrationConfigProvider.notifier);
    await notifier.load();
    expect(container.read(managedIntegrationsProvider), isTrue);
    notifier.useManualIntegrations();
    expect(container.read(managedIntegrationsProvider), isFalse);
    expect(container.read(seerrAvailableProvider), isTrue);
    expect(container.read(sonarrProvider).isConfigured, isTrue);
    expect(container.read(radarrProvider).isConfigured, isTrue);
    final helper = SharedHelper(sharedPreferences: prefs);
    await helper.saveAccounts([container.read(userProvider)!]);
    final restored = helper.getAccounts().single;
    expect(restored.managedIntegrations, isTrue);
    expect(restored.manualIntegrations, isTrue);
    expect(restored.usesManagedIntegrations, isFalse);
    final restarted = _container(client, account: restored, preferences: prefs);
    await restarted.read(serverIntegrationConfigProvider.notifier).load();
    expect(restarted.read(managedIntegrationsProvider), isFalse);
    expect(restarted.read(seerrAvailableProvider), isTrue);
    expect(paths.every((path) => path.endsWith('/capabilities')), isTrue);
    installed = true;
    await restarted.read(serverIntegrationConfigProvider.notifier).load();
    expect(restarted.read(managedIntegrationsProvider), isTrue);
    expect(restarted.read(userProvider)!.manualIntegrations, isFalse);
  });

  for (final code in [401, 403, 502]) {
    test('HTTP $code cannot enable manual recovery', () async {
      final container = _container(MockClient((_) async => http.Response('', code)), account: _account(managed: true));
      final notifier = container.read(serverIntegrationConfigProvider.notifier);
      await notifier.load();
      notifier.useManualIntegrations();
      expect(container.read(managedIntegrationsProvider), isTrue);
      expect(container.read(userProvider)!.manualIntegrations, isFalse);
    });
  }

  test('explicit recovery never activates unknown-origin Seerr credentials', () async {
    final container = _container(
      MockClient((_) async => http.Response('', 404)),
      account: _account(managed: true, origin: CredentialOrigin.unknown),
    );
    final notifier = container.read(serverIntegrationConfigProvider.notifier);
    await notifier.load();
    notifier.useManualIntegrations();
    expect(container.read(managedIntegrationsProvider), isFalse);
    expect(container.read(seerrAvailableProvider), isFalse);
  });

  test('admin diagnostics check only the saved service and expose safe outcomes', () async {
    final caps = _capabilities();
    (caps['features'] as Map)['diagnostics'] = {'supported': true, 'allowed': true};
    var status = 200;
    final container = _container(
      MockClient((request) async {
        if (request.method == 'GET') return http.Response(jsonEncode(caps), 200);
        expect(request.method, 'POST');
        expect(request.url.path, '/base/Driftfin/v1/integrations/sonarr/check');
        expect(request.body, isEmpty);
        return http.Response(
          status == 200
              ? '{"healthy":true,"correlationId":"check-1","checkedAt":"2026-09-19T12:00:00Z"}'
              : 'private upstream failure',
          status,
        );
      }),
    );
    final notifier = container.read(serverIntegrationConfigProvider.notifier);
    await notifier.load();
    final result = await notifier.check('sonarr');
    expect(result.healthy, isTrue);
    expect(result.correlationId, 'check-1');
    expect(result.checkedAt, DateTime.utc(2026, 9, 19, 12));
    for (final code in [401, 403, 502]) {
      status = code;
      final failed = await notifier.check('sonarr');
      expect(failed.healthy, isFalse);
      expect(
        failed.reason,
        code == 401
            ? 'expired_login'
            : code == 403
            ? 'permission_denied'
            : 'unreachable',
      );
      expect(failed.correlationId, isNull);
    }
    await expectLater(notifier.check('http://arbitrary'), throwsArgumentError);
  });

  test('member diagnostics are denied before sending any request', () async {
    var calls = 0;
    final container = _container(
      MockClient((_) async {
        calls++;
        return http.Response(jsonEncode(_capabilities()), 200);
      }),
    );
    final notifier = container.read(serverIntegrationConfigProvider.notifier);
    await notifier.load();
    expect((await notifier.check('sonarr')).reason, 'permission_denied');
    expect(calls, 1);
  });

  test('managed arr actions use Jellyfin and opaque root folders', () async {
    final caps = _capabilities();
    (caps['features'] as Map)['arrManagement'] = {'supported': true, 'allowed': true};
    for (final service in ['sonarr', 'radarr']) {
      (caps['integrations'] as Map)[service] = {'configured': true};
    }
    final posts = <Map<String, dynamic>>[];
    await http.runWithClient(
      () async {
        final container = _container(MockClient((_) async => http.Response(jsonEncode(caps), 200)));
        await container.read(serverIntegrationConfigProvider.notifier).load();
        expect(container.read(sonarrProvider).isConfigured, isTrue);
        expect(container.read(radarrProvider).isConfigured, isTrue);
        expect(await container.read(radarrProvider.notifier).requestMovie(550), RadarrRequestResult.success);
        expect(
          await container.read(sonarrProvider.notifier).requestEpisodeByTvdb(tvdbId: 7, season: 1, episode: 1),
          SonarrRequestResult.success,
        );
      },
      () => MockClient((request) async {
        expect(request.url.host, 'jellyfin.test');
        expect(request.url.path, startsWith('/base/Driftfin/v1/'));
        expect(request.headers['authorization'], contains('alice-token'));
        expect(request.headers.keys.map((key) => key.toLowerCase()), isNot(contains('x-api-key')));
        expect(request.followRedirects, isFalse);
        final path = request.url.path;
        if (request.method != 'GET') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          posts.add(body);
          if (path.endsWith('/movie') || path.endsWith('/series')) {
            expect(body['rootFolderPath'], 'folder:4');
            expect(body['qualityProfileId'], 2);
            expect(body.containsKey('title'), isFalse);
          }
          return http.Response('{"id":9}', 200);
        }
        if (path.endsWith('/rootfolder')) return http.Response('[{"id":4,"path":"folder:4","accessible":true}]', 200);
        if (path.endsWith('/qualityprofile')) return http.Response('[{"id":2}]', 200);
        if (path.endsWith('/movie/lookup/tmdb')) {
          return http.Response('{"tmdbId":550,"title":"Movie","hasFile":false}', 200);
        }
        if (path.endsWith('/series/lookup')) return http.Response('[{"tvdbId":7,"title":"Series"}]', 200);
        if (path.endsWith('/episode')) return http.Response('[{"id":12,"seasonNumber":1,"episodeNumber":1}]', 200);
        return http.Response('[]', 200);
      }),
    );
    expect(posts, hasLength(4));
    expect(posts.last['name'], 'EpisodeSearch');
  });

  test('regular managed users cannot activate direct arr settings', () async {
    final container = _container(MockClient((_) async => http.Response(jsonEncode(_capabilities()), 200)));
    await container.read(serverIntegrationConfigProvider.notifier).load();
    expect(container.read(sonarrProvider).managed, isTrue);
    expect(container.read(radarrProvider).managed, isTrue);
    container.read(sonarrProvider.notifier).setApiKey('should-not-save');
    container.read(radarrProvider.notifier).setEnabled(true);
    expect(container.read(sonarrProvider).apiKey, isEmpty);
    expect(await container.read(radarrProvider.notifier).requestMovie(550), RadarrRequestResult.notConfigured);
  });

  test('managed background requests support a local-only Jellyfin address', () async {
    await http.runWithClient(
      () async {
        final account = _account(managed: true);
        final worker = NotificationHelpers.createSeerrClient(
          account.seerrCredentials!,
          jellyfin: account.credentials.copyWith(url: '', localUrl: 'https://local.test/jellyfin'),
        );
        addTearDown(worker.client.dispose);
        expect((await worker.getMe()).body?.id, 42);
      },
      () => MockClient((request) async {
        expect(request.url.toString(), 'https://local.test/jellyfin/Driftfin/v1/seerr/auth/me');
        return http.Response('{"id":42}', 200);
      }),
    );
  });

  test('managed response is rejected after switching accounts', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(
      () async {
        final container = _container(MockClient((_) async => http.Response('', 404)), account: _account(managed: true));
        final response = container.read(seerrApiProvider).me();
        final rejected = expectLater(response, throwsA(isA<Exception>()));
        await started.future;
        container.read(userProvider.notifier).userState = _account(id: 'bob', managed: true);
        pending.complete(http.Response('{"id":42}', 200));
        await rejected;
      },
      () => MockClient((_) {
        started.complete();
        return pending.future;
      }),
    );
  });

  test('capabilities separate compatibility, permissions, configuration and health', () {
    final json = _capabilities();
    (json['integrations'] as Map)['seerr'] = {'configured': true, 'healthy': false, 'reason': 'unreachable'};
    final capabilities = PluginCapabilities.fromJson(json);
    expect(capabilities.feature('discovery').allowed, isTrue);
    expect(capabilities.integration('seerr').configured, isTrue);
    expect(capabilities.integration('seerr').healthy, isFalse);
    expect(capabilities.feature('diagnostics').allowed, isFalse);
    expect(PluginCapabilities.fromJson(_capabilities(protocol: 2)).feature('discovery').allowed, isFalse);
  });

  for (final entry in {
    401: ServerIntegrationConfigStatus.expiredLogin,
    403: ServerIntegrationConfigStatus.forbidden,
    404: ServerIntegrationConfigStatus.noPlugin,
    502: ServerIntegrationConfigStatus.httpError,
  }.entries) {
    test('capability HTTP ${entry.key} has a distinct outcome', () async {
      final result = await fetchPluginCapabilities(
        'https://server/capabilities',
        {},
        MockClient((_) async => http.Response('private upstream failure', entry.key)),
      );
      expect(result.status, entry.value);
      expect(result.detail, isNot(contains('private')));
    });
  }

  test('only a missing capabilities route permits legacy negotiation', () async {
    final paths = <String>[];
    final container = _container(
      MockClient((request) async {
        paths.add(request.url.path);
        return request.url.path.endsWith('/capabilities') ? http.Response('', 404) : http.Response('{}', 200);
      }),
    );
    final outcome = await container.read(serverIntegrationConfigProvider.notifier).loadWithDiagnostics();
    expect(outcome.status, ServerIntegrationConfigStatus.legacy);
    expect(paths, ['/base/Driftfin/v1/capabilities', '/base/Driftfin/Config']);
  });

  test('expired login never probes the legacy credential endpoint', () async {
    var calls = 0;
    final container = _container(
      MockClient((_) async {
        calls++;
        return http.Response('', 401);
      }),
    );
    final outcome = await container.read(serverIntegrationConfigProvider.notifier).loadWithDiagnostics();
    expect(outcome.status, ServerIntegrationConfigStatus.expiredLogin);
    expect(calls, 1);
  });

  test('successful migration stores no server credentials and retains manual settings', () async {
    final container = _container(MockClient((_) async => http.Response(jsonEncode(_capabilities()), 200)));
    await container.read(serverIntegrationConfigProvider.notifier).load();
    final config = container.read(serverIntegrationConfigProvider)!;
    expect(config.managedProtocol, isTrue);
    expect(config.seerr.isManaged, isTrue);
    expect(config.seerr.apiKey, isEmpty);
    expect(config.seerr.url, isEmpty);
    expect(container.read(userProvider)!.managedIntegrations, isTrue);
    expect(container.read(userProvider)!.seerrCredentials!.apiKey, 'direct-key');
  });

  test('known plugin-injected credentials are removed on migration', () async {
    final container = _container(
      MockClient((_) async => http.Response(jsonEncode(_capabilities()), 200)),
      account: _account(origin: CredentialOrigin.plugin),
    );
    await container.read(serverIntegrationConfigProvider.notifier).load();
    expect(container.read(userProvider)!.seerrCredentials, isNull);
    expect(jsonEncode(container.read(userProvider)!.toJson()), isNot(contains('direct-key')));
  });

  test('previously migrated account fails closed after restart and plugin outage', () async {
    var calls = 0;
    final container = _container(
      MockClient((_) async {
        calls++;
        return http.Response('', 404);
      }),
      account: _account(managed: true),
    );
    await container.read(serverIntegrationConfigProvider.notifier).load();
    expect(calls, 1);
    expect(container.read(managedIntegrationsProvider), isTrue);
    expect(container.read(serverIntegrationConfigProvider)!.seerr.apiKey, isEmpty);
    expect(container.read(seerrAvailableProvider), isFalse);
  });

  test('late capability response cannot resurrect a logged-out account', () async {
    final delayed = Completer<http.Response>();
    final container = _container(MockClient((_) => delayed.future));
    final loading = container.read(serverIntegrationConfigProvider.notifier).load();
    container.read(userProvider.notifier).userState = null;
    delayed.complete(http.Response(jsonEncode(_capabilities()), 200));
    await loading;
    expect(container.read(userProvider), isNull);
    expect(container.read(serverIntegrationConfigProvider), isNull);
  });

  test('late capabilities cannot cross accounts on the same server', () async {
    final delayed = Completer<http.Response>();
    final container = _container(MockClient((_) => delayed.future));
    final loading = container.read(serverIntegrationConfigProvider.notifier).load();
    container.read(userProvider.notifier).userState = _account(id: 'bob');
    delayed.complete(http.Response(jsonEncode(_capabilities()), 200));
    await loading;
    expect(container.read(userProvider)!.id, 'bob');
    expect(container.read(userProvider)!.managedIntegrations, isFalse);
    expect(container.read(serverIntegrationConfigProvider), isNull);
  });

  test('managed Seerr and background requests use only Jellyfin credentials', () async {
    final account = _account(managed: true);
    final requests = <http.Request>[];
    await http.runWithClient(
      () async {
        final container = _container(MockClient((_) async => http.Response('{}', 404)), account: account);
        final response = await container.read(seerrApiProvider).me();
        expect(response.body!.id, 42);
        final worker = NotificationHelpers.createSeerrClient(account.seerrCredentials!, jellyfin: account.credentials);
        await worker.getMe();
        worker.client.dispose();
      },
      () => MockClient((request) async {
        requests.add(request);
        return http.Response('{"id":42,"permissions":32}', 200);
      }),
    );
    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(request.url.toString(), 'https://jellyfin.test/base/Driftfin/v1/seerr/auth/me');
      expect(request.headers['authorization'], contains('alice-token'));
      expect(request.headers.keys.map((key) => key.toLowerCase()), isNot(contains('x-api-key')));
      expect(request.headers.keys.map((key) => key.toLowerCase()), isNot(contains('cookie')));
      expect(request.headers.keys.map((key) => key.toLowerCase()), isNot(contains('x-api-user')));
      expect(request.headers.values.join(), isNot(contains('private')));
      expect(request.followRedirects, isFalse);
    }
  });
}
