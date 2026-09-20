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
import 'package:driftfin/providers/user_provider.dart';

class _User extends User {
  @override
  AccountModel build() => AccountModel(
    name: 'Test',
    id: '1',
    avatar: '',
    lastUsed: DateTime(2026),
    credentials: CredentialsModel(),
    seerrCredentials: const SeerrCredentialsModel(serverUrl: 'https://seerr.test', apiKey: 'test-key'),
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

  for (final changeCredentials in [false, true]) {
    test('stale profile is discarded after ${changeCredentials ? 'credential change' : 'newer refresh'}', () async {
      final responses = <Completer<http.Response>>[];
      await http.runWithClient(
        () async {
          final container = _container();
          final subscription = container.listen(seerrUserProvider, (_, _) {});
          addTearDown(subscription.close);
          await Future<void>.delayed(Duration.zero);
          expect(responses, hasLength(1));
          Future<dynamic>? refreshed;
          if (changeCredentials) {
            container.read(userProvider.notifier).userState = container
                .read(userProvider)!
                .copyWith(
                  seerrCredentials: const SeerrCredentialsModel(serverUrl: 'https://new-seerr.test', apiKey: 'new-key'),
                );
            await container.pump();
          } else {
            refreshed = container.read(seerrUserProvider.notifier).refreshUser();
          }
          await Future<void>.delayed(Duration.zero);
          expect(responses, hasLength(2));
          responses[1].complete(http.Response('{"id":2,"permissions":0}', 200));
          await Future<void>.delayed(Duration.zero);
          if (refreshed != null) await refreshed;
          expect(container.read(seerrUserProvider)?.id, 2);
          responses[0].complete(http.Response('{"id":1,"permissions":16}', 200));
          await Future<void>.delayed(Duration.zero);
          expect(container.read(seerrUserProvider)?.id, 2);
          expect(container.read(seerrUserProvider)?.permissions, 0);
        },
        () => MockClient((_) {
          final response = Completer<http.Response>();
          responses.add(response);
          return response.future;
        }),
      );
    });
  }

  test('clearing profile discards pending responses', () async {
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      final container = _container();
      final subscription = container.listen(seerrUserProvider, (_, _) {});
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);
      container.read(seerrUserProvider.notifier).clearUser();
      response.complete(_profile());
      await Future<void>.delayed(Duration.zero);
      expect(container.read(seerrUserProvider), isNull);
    }, () => MockClient((_) => response.future));
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
