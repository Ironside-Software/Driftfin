import 'dart:async';
import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:driftfin/providers/connectivity_provider.dart';
import 'package:driftfin/providers/seerr_api_provider.dart';
import 'package:driftfin/providers/seerr_requests_provider.dart';
import 'package:driftfin/providers/seerr_service_provider.dart';
import 'package:driftfin/providers/seerr_user_provider.dart';
import 'package:driftfin/seerr/seerr_chopper_service.dart';
import 'package:driftfin/seerr/seerr_json_converter.dart';
import 'package:driftfin/seerr/seerr_models.dart';

class _User extends SeerrUser {
  @override
  SeerrUserModel build() => const SeerrUserModel(id: 1);
}

class _Api extends SeerrApi {
  _Api(this.client);
  final ChopperClient client;
  @override
  SeerrService build() => SeerrService(ref, SeerrChopperService.create(client));
}

ProviderContainer _container(Future<http.Response> Function(http.Request) handler) {
  final client = ChopperClient(
    baseUrl: Uri.parse('https://seerr.test'),
    client: MockClient(handler),
    converter: const SeerrJsonConverter(),
  );
  final container = ProviderContainer(
    overrides: [
      offlineStateProvider.overrideWithValue(false),
      seerrUserProvider.overrideWith(_User.new),
      seerrApiProvider.overrideWith(() => _Api(client)),
      seerrRequestsProvider.overrideWith(SeerrRequestsNotifier.new),
    ],
  );
  container.listen(seerrRequestsProvider, (_, _) {});
  addTearDown(container.dispose);
  addTearDown(client.dispose);
  return container;
}

http.Response _page({int id = 1, int pages = 1, String type = 'movie'}) => http.Response(
  jsonEncode({
    'pageInfo': {'pages': pages},
    'results': [
      {
        'id': id,
        'status': 1,
        'media': {'tmdbId': id, 'mediaType': type},
      },
    ],
  }),
  200,
);

void main() {
  test('requests appear even when metadata never completes', () async {
    final poster = Completer<http.Response>();
    final container = _container(
      (request) async => request.url.path.endsWith('/request') ? _page() : await poster.future,
    );
    await container.read(seerrRequestsProvider.notifier).load();
    expect(container.read(seerrRequestsProvider).loading, isFalse);
    expect(container.read(seerrRequestsProvider).entries.single.request.id, 1);
    poster.complete(http.Response('{}', 503));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(seerrRequestsProvider).entries, hasLength(1));
  });

  test('HTTP errors are retryable errors, not empty results', () async {
    var fail = true;
    final container = _container((_) async => fail ? http.Response('{}', 401) : _page());
    final notifier = container.read(seerrRequestsProvider.notifier);
    await notifier.load();
    expect(container.read(seerrRequestsProvider).hasError, isTrue);
    expect(container.read(seerrRequestsProvider).loading, isFalse);
    fail = false;
    await notifier.load();
    expect(container.read(seerrRequestsProvider).hasError, isFalse);
    expect(container.read(seerrRequestsProvider).entries, hasLength(1));
  });

  testWidgets('a stalled request times out and clears loading', (tester) async {
    final response = Completer<http.Response>();
    final container = _container((_) => response.future);
    final load = container.read(seerrRequestsProvider.notifier).load();
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    await load;
    expect(container.read(seerrRequestsProvider).loading, isFalse);
    expect(container.read(seerrRequestsProvider).hasError, isTrue);
    response.complete(http.Response('{}', 500));
    await tester.pump();
  });

  test('TV requests without TVDB ids use TV metadata', () async {
    final paths = <String>[];
    final container = _container((request) async {
      paths.add(request.url.path);
      return request.url.path.endsWith('/request') ? _page(type: 'tv') : http.Response('{"id":1,"name":"A show"}', 200);
    });
    await container.read(seerrRequestsProvider.notifier).load();
    await Future<void>.delayed(Duration.zero);
    expect(paths, contains('/api/v1/tv/1'));
    expect(container.read(seerrRequestsProvider).entries.single.poster?.title, 'A show');
  });

  test('filter reload resets pagination and ignores old page responses', () async {
    final oldPage = Completer<http.Response>();
    final container = _container((request) async {
      if (!request.url.path.endsWith('/request')) return http.Response('{}', 503);
      if (request.url.queryParameters['skip'] == '20') return oldPage.future;
      return _page(id: request.url.queryParameters['filter'] == 'pending' ? 2 : 1, pages: 2);
    });
    final notifier = container.read(seerrRequestsProvider.notifier);
    await notifier.load();
    final more = notifier.loadMore();
    notifier.setFilter(RequestFilter.pending);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(seerrRequestsProvider).loadingMore, isFalse);
    oldPage.complete(_page(id: 99));
    await more;
    expect(container.read(seerrRequestsProvider).entries.map((e) => e.request.id), [2]);
  });
}
