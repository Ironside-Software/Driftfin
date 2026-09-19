import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/models/seerr_credentials_model.dart';
import 'package:driftfin/providers/seerr_api_provider.dart';
import 'package:driftfin/providers/seerr_user_provider.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/providers/user_provider.dart';

class _User extends User {
  @override
  AccountModel build() => AccountModel(
    name: 'Test',
    id: '1',
    avatar: '',
    lastUsed: DateTime(2026),
    credentials: CredentialsModel(),
    seerrCredentials: const SeerrCredentialsModel(
      origin: CredentialOrigin.manual,
      serverUrl: 'https://seerr.test',
      apiKey: 'test-key',
    ),
  );

  @override
  set userState(AccountModel? account) => state = account;
}

ProviderContainer _container() {
  final container = ProviderContainer(overrides: [userProvider.overrideWith(_User.new)]);
  addTearDown(container.dispose);
  return container;
}

http.Response _profile() => http.Response('{"id":1,"avatar":"/avatar.png"}', 200);

Widget _screen(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: Consumer(
    builder: (_, ref, _) {
      ref.watch(seerrUserProvider);
      return const SizedBox();
    },
  ),
);

void main() {
  test('unknown saved credentials stay dormant after plugin negotiation', () async {
    var calls = 0;
    await http.runWithClient(
      () async {
        final container = _container();
        final account = container.read(userProvider)!;
        container.read(userProvider.notifier).userState = account.copyWith(
          seerrCredentials: account.seerrCredentials!.copyWith(origin: CredentialOrigin.unknown),
        );
        final subscription = container.listen(seerrUserProvider, (_, _) {});
        addTearDown(subscription.close);
        await container.pump();
        expect(calls, 0);
        container.read(serverIntegrationConnectionProvider.notifier).state = ServerIntegrationConfigStatus.noPlugin;
        await container.pump();
        await Future<void>.delayed(Duration.zero);
        expect(calls, 0);
        expect(container.read(seerrUserProvider), isNull);
        expect(container.read(seerrAvailableProvider), isFalse);
        expect(container.read(userProvider)?.seerrCredentials?.apiKey, 'test-key');
      },
      () => MockClient((_) async {
        calls++;
        return _profile();
      }),
    );
  });

  test('reconnecting unknown credentials never sends the stored key or custom headers', () async {
    final requests = <http.Request>[];
    await http.runWithClient(
      () async {
        final container = _container();
        final account = container.read(userProvider)!;
        container.read(userProvider.notifier).userState = account.copyWith(
          seerrCredentials: account.seerrCredentials!.copyWith(
            origin: CredentialOrigin.unknown,
            sessionCookie: 'old-cookie',
            customHeaders: {'Authorization': 'old-secret'},
          ),
        );
        final cookie = await container
            .read(seerrApiProvider)
            .authenticateLocal(email: 'user@example.test', password: 'new-password');
        expect(cookie, contains('new-session'));
        expect(requests, hasLength(1));
        expect(requests.single.url.path, '/api/v1/auth/local');
        expect(
          requests.single.headers.keys.map((key) => key.toLowerCase()),
          isNot(anyOf(contains('x-api-key'), contains('cookie'), contains('authorization'))),
        );
        expect(requests.single.body, contains('new-password'));
      },
      () => MockClient((request) async {
        requests.add(request);
        return http.Response('{"id":1}', 200, headers: {'set-cookie': 'connect.sid=new-session; Path=/; HttpOnly'});
      }),
    );
  });

  test('cached Seerr API works after an idle frame without listeners', () async {
    await http.runWithClient(() async {
      final container = _container();
      final api = container.read(seerrApiProvider);
      await container.pump();

      final response = await api.me();
      expect(response.body?.id, 1);
      expect(response.body?.avatar, 'https://seerr.test/avatar.png');
      expect(container.read(seerrApiProvider), same(api));
    }, () => MockClient((_) async => _profile()));
  });

  test('cached Seerr API uses updated credentials without rebuilding', () async {
    final requests = <http.Request>[];
    await http.runWithClient(
      () async {
        final container = _container();
        final subscription = container.listen(seerrApiProvider, (_, _) {});
        addTearDown(subscription.close);
        final api = container.read(seerrApiProvider);
        await api.me();
        container.read(userProvider.notifier).userState = container
            .read(userProvider)!
            .copyWith(
              seerrCredentials: const SeerrCredentialsModel(
                origin: CredentialOrigin.manual,
                serverUrl: 'https://new-seerr.test',
                apiKey: 'new-test-key',
              ),
            );
        await container.pump();

        final response = await api.me();
        expect(container.read(seerrApiProvider), same(api));
        expect(requests.first.url.host, 'seerr.test');
        expect(requests.last.url.host, 'new-seerr.test');
        expect(requests.last.headers['X-Api-Key'], 'new-test-key');
        expect(response.body?.avatar, 'https://new-seerr.test/avatar.png');
      },
      () => MockClient((request) async {
        requests.add(request);
        return _profile();
      }),
    );
  });

  testWidgets('failed initial Seerr profile fetch is handled and can be retried', (tester) async {
    var fail = true;
    await http.runWithClient(
      () async {
        final container = _container();
        await tester.pumpWidget(_screen(container));
        await tester.pump();
        expect(container.read(seerrUserProvider), isNull);
        expect(tester.takeException(), isNull);

        fail = false;
        final refreshed = container.read(seerrUserProvider.notifier).refreshUser();
        await tester.pump();
        expect((await refreshed)?.id, 1);
        expect(container.read(seerrUserProvider)?.id, 1);
      },
      () => MockClient((_) async {
        if (fail) throw const SocketException('Offline');
        return _profile();
      }),
    );
  });

  for (final fail in [false, true]) {
    test('Seerr profile ${fail ? 'error' : 'response'} after disposal is safe', () async {
      final response = Completer<http.Response>();
      await http.runWithClient(() async {
        final container = _container();
        final subscription = container.listen(seerrUserProvider, (_, _) {});
        await Future<void>.delayed(Duration.zero);
        subscription.close();
        await container.pump();
        expect(container.exists(seerrUserProvider), isFalse);

        if (fail) {
          response.completeError(const SocketException('Offline'));
        } else {
          response.complete(_profile());
        }
        await Future<void>.delayed(Duration.zero);
      }, () => MockClient((_) => response.future));
    });
  }
}
