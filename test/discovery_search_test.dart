import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/models/discovery_search.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/library_filter_model.dart';
import 'package:driftfin/models/library_search/library_search_model.dart';
import 'package:driftfin/models/plugin_capabilities.dart';
import 'package:driftfin/models/server_integration_config.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/discovery_search_provider.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/providers/user_provider.dart';

class _User extends User {
  @override
  AccountModel build() => AccountModel(
    id: 'alice',
    name: 'Alice',
    avatar: '',
    lastUsed: DateTime(2026),
    credentials: CredentialsModel(serverId: 'server', url: 'https://jellyfin.test/base', token: 'session'),
  );
  @override
  set userState(AccountModel? account) => state = account;
}

class _Config extends ServerIntegrationConfigNotifier {
  _Config(super.ref, {bool allowed = true, String? reason}) {
    state = ServerIntegrationConfig.managed(
      PluginCapabilities(
        protocolVersion: 1,
        features: {'discovery': PluginFeature(supported: true, allowed: allowed, reason: reason)},
      ),
    );
  }
}

Map<String, dynamic> _item(int id, {String type = 'movie', String? libraryId, String status = 'requestable'}) => {
  'tmdbId': id,
  'mediaType': type,
  'title': 'Movie $id',
  'name': 'Series $id',
  'availability': status,
  'libraryItemId': libraryId,
  'canRequest': status != 'available',
  'canPlay': libraryId != null,
};
http.Response _page(int page, List<Map<String, dynamic>> items, {int pages = 2}) =>
    http.Response(jsonEncode({'page': page, 'totalPages': pages, 'results': items}), 200);

ProviderContainer _container({bool allowed = true, String? reason}) {
  final container = ProviderContainer(
    overrides: [
      userProvider.overrideWith(_User.new),
      serverUrlProvider.overrideWith((ref) => ref.watch(userProvider)?.credentials.url),
      serverIntegrationConfigProvider.overrideWith((ref) => _Config(ref, allowed: allowed, reason: reason)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('catalog languages use supported language-country tags', () {
    expect(discoveryLanguage(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')), 'zh-TW');
    expect(discoveryLanguage(const Locale('pt', 'BR')), 'pt-BR');
    expect(discoveryLanguage(const Locale('jp')), 'ja');
  });
  test('deduplication uses type and stable IDs, never the title', () {
    final library = ItemBaseModel.fromBaseDto(
      const BaseItemDto(id: 'owned', name: 'Same title', type: BaseItemKind.movie, providerIds: {'Tmdb': '7'}),
      null,
    );
    final candidates = [
      _item(7),
      _item(7, type: 'tv'),
      _item(8, libraryId: 'owned'),
      _item(9),
      _item(9),
    ].map(DiscoveryResult.fromJson).toList();
    expect(distinctDiscoveryResults(candidates, [library]).map((item) => item.key), ['tv:7', 'movie:9']);
    expect(distinctDiscoveryResults(candidates, []).map((item) => item.key), ['movie:7', 'tv:7', 'movie:8', 'movie:9']);
  });

  test('catalog posters remain catalog entries even when matched', () {
    final item = DiscoveryResult.fromJson(_item(7, libraryId: 'owned', status: 'partial'));
    expect(item.libraryItemId, 'owned');
    expect(item.poster.itemBaseModel, isNull);
    expect(item.availability, DiscoveryAvailability.partial);
    expect(item.canPlay, isTrue);
    expect(DiscoveryResult.fromJson({..._item(7), 'canPlay': true}).canPlay, isFalse);
    expect(() => DiscoveryResult.fromJson(_item(7, type: 'person')), throwsFormatException);
  });

  test('library-only filters do not silently apply to catalog search', () {
    expect(
      hasLibraryOnlySearchFilters(const LibrarySearchModel(filters: LibraryFilterModel(searchQuery: 'test'))),
      isFalse,
    );
    for (final filter in [
      const LibraryFilterModel(favourites: true),
      const LibraryFilterModel(types: {FladderItemType.audio: true}),
      const LibraryFilterModel(genres: {'Drama': true}),
      const LibraryFilterModel(tags: {'family': true}),
    ]) {
      expect(hasLibraryOnlySearchFilters(LibrarySearchModel(filters: filter)), isTrue);
    }
  });

  test('pages advance independently even when every earlier card was a duplicate', () async {
    final seen = <String>[];
    await http.runWithClient(
      () async {
        final container = _container();
        const query = (query: ' movie & more ', language: 'en-US');
        final subscription = container.listen(discoverySearchProvider(query), (_, _) {});
        addTearDown(subscription.close);
        final notifier = container.read(discoverySearchProvider(query).notifier);
        await notifier.loadMore();
        expect(notifier.state.page, 1);
        await notifier.loadMore();
        expect(notifier.state.page, 2);
        expect(notifier.state.results.map((item) => item.tmdbId), [7, 8]);
        expect(notifier.state.hasMore, isFalse);
        await notifier.loadMore();
        expect(seen, ['1', '2']);
      },
      () => MockClient((request) async {
        expect(request.url.path, '/base/Driftfin/v1/discovery/search');
        expect(request.url.queryParameters['query'], 'movie & more');
        expect(request.url.queryParameters['language'], 'en-US');
        expect(request.headers['authorization'], contains('session'));
        expect(request.followRedirects, isFalse);
        seen.add(request.url.queryParameters['page']!);
        return seen.length == 1 ? _page(1, [_item(7)]) : _page(2, [_item(7), _item(8)]);
      }),
    );
  });

  test('failed next page preserves results and retry uses that same page', () async {
    var calls = 0;
    await http.runWithClient(
      () async {
        final container = _container();
        const query = (query: 'movie', language: 'en');
        final subscription = container.listen(discoverySearchProvider(query), (_, _) {});
        addTearDown(subscription.close);
        final notifier = container.read(discoverySearchProvider(query).notifier);
        await notifier.loadMore();
        await notifier.loadMore();
        expect(notifier.state.reason, 'unreachable');
        expect(notifier.state.page, 1);
        expect(notifier.state.results.single.tmdbId, 7);
        await notifier.loadMore();
        expect(notifier.state.reason, isNull);
        expect(notifier.state.page, 2);
      },
      () => MockClient((request) async {
        calls++;
        if (calls == 1) return _page(1, [_item(7)]);
        expect(request.url.queryParameters['page'], '2');
        return calls == 2 ? http.Response('private failure', 502) : _page(2, [_item(8)]);
      }),
    );
  });

  test('restricted accounts and empty queries never send a catalog request', () async {
    await http.runWithClient(() async {
      final container = _container(allowed: false, reason: 'content_restricted');
      const query = (query: 'movie', language: 'en');
      final notifier = container.read(discoverySearchProvider(query).notifier);
      await notifier.loadMore();
      expect(notifier.state.reason, 'content_restricted');
      await container.read(discoverySearchProvider((query: '', language: 'en')).notifier).loadMore();
    }, () => MockClient((_) async => throw StateError('Must not send')));
  });

  test('a pending result cannot cross accounts on the same server', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(
      () async {
        final container = _container();
        const query = (query: 'movie', language: 'en');
        final subscription = container.listen(discoverySearchProvider(query), (_, _) {});
        addTearDown(subscription.close);
        final old = container.read(discoverySearchProvider(query).notifier);
        final loading = old.loadMore();
        await started.future;
        container.read(userProvider.notifier).userState = container.read(userProvider)!.copyWith(id: 'bob');
        await container.pump();
        pending.complete(_page(1, [_item(7)]));
        await loading;
        expect(old.mounted, isFalse);
        expect(container.read(discoverySearchProvider(query)).results, isEmpty);
      },
      () => MockClient((_) {
        if (!started.isCompleted) started.complete();
        return pending.future;
      }),
    );
  });

  test('query changes and disposal discard late results', () async {
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      final container = _container();
      const oldQuery = (query: 'old', language: 'en');
      final subscription = container.listen(discoverySearchProvider(oldQuery), (_, _) {});
      final notifier = container.read(discoverySearchProvider(oldQuery).notifier);
      final loading = notifier.loadMore();
      await Future<void>.delayed(Duration.zero);
      subscription.close();
      await container.pump();
      pending.complete(_page(1, [_item(7)]));
      await loading;
      expect(notifier.mounted, isFalse);
      expect(container.read(discoverySearchProvider((query: 'new', language: 'en'))).results, isEmpty);
    }, () => MockClient((_) => pending.future));
  });
}
