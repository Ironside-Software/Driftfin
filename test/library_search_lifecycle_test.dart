import 'dart:async';

import 'package:chopper/chopper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/library_search_provider.dart';
import 'package:driftfin/providers/service_provider.dart';
import 'package:driftfin/providers/user_provider.dart';

class _User extends User {
  @override
  AccountModel build() => AccountModel(
    id: 'alice',
    name: 'Alice',
    avatar: '',
    lastUsed: DateTime(2026),
    credentials: CredentialsModel(serverId: 'server', token: 'session'),
  );
  @override
  set userState(AccountModel? account) => state = account;
}

class _Service implements JellyService {
  _Service(this.fetch);
  final Future<Response<ServerQueryResult>> Function(Invocation) fetch;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #itemsGet ? fetch(invocation) : super.noSuchMethod(invocation);
}

class _Api extends JellyApi {
  _Api(this.service);
  final JellyService service;
  @override
  JellyService build() => service;
}

Response<ServerQueryResult> _page(String id, {int total = 1}) => Response(
  http.Response('', 200),
  ServerQueryResult(
    items: [ItemBaseModel.fromBaseDto(BaseItemDto(id: id, name: id, type: BaseItemKind.movie), null)],
    totalRecordCount: total,
  ),
);

ProviderContainer _container(Future<Response<ServerQueryResult>> Function(Invocation) fetch) {
  final container = ProviderContainer(
    overrides: [userProvider.overrideWith(_User.new), jellyApiProvider.overrideWith(() => _Api(_Service(fetch)))],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = ValueKey('search');

  test('typing updates live results but only submission saves search history', () {
    final container = _container((_) async => _page('movie'));
    final subscription = container.listen(librarySearchProvider(key), (_, _) {});
    addTearDown(subscription.close);
    final notifier = container.read(librarySearchProvider(key).notifier);
    for (final query in ['f', 'fi', 'fig', 'fight']) {
      notifier.setSearch(query);
      expect(notifier.state.filters.searchQuery, query);
      expect(container.read(userProvider)!.searchQueryHistory, isEmpty);
    }
    notifier.submitSearch('fight');
    expect(container.read(userProvider)!.searchQueryHistory, ['fight']);
    notifier.submitSearch('fight');
    expect(container.read(userProvider)!.searchQueryHistory, ['fight']);
    notifier.submitSearch('');
    expect(container.read(userProvider)!.searchQueryHistory, ['fight']);
  });

  test('global library search uses its own offset and requests stable provider IDs', () async {
    final offsets = <int>[];
    final container = _container((call) async {
      offsets.add(call.namedArguments[#startIndex] as int);
      expect(call.namedArguments[#limit], greaterThan(0));
      expect(call.namedArguments[#fields], contains(ItemFields.providerids));
      return _page('item-${offsets.length}', total: 2);
    });
    final subscription = container.listen(librarySearchProvider(key), (_, _) {});
    addTearDown(subscription.close);
    final notifier = container.read(librarySearchProvider(key).notifier)..setSearch('movie');
    await notifier.loadMore();
    await notifier.loadMore();
    await notifier.loadMore();
    expect(offsets, [0, 1]);
    expect(notifier.state.posters.map((item) => item.id), ['item-1', 'item-2']);
  });

  test('new query discards an older library response and clears old cards immediately', () async {
    final pending = Completer<Response<ServerQueryResult>>();
    final container = _container(
      (call) => call.namedArguments[#searchTerm] == 'old' ? pending.future : Future.value(_page('new')),
    );
    final subscription = container.listen(librarySearchProvider(key), (_, _) {});
    addTearDown(subscription.close);
    final notifier = container.read(librarySearchProvider(key).notifier)..setSearch('old');
    final loading = notifier.loadMore();
    notifier.setSearch('new');
    expect(notifier.state.posters, isEmpty);
    await notifier.loadMore();
    pending.complete(_page('old'));
    await loading;
    expect(notifier.state.posters.single.id, 'new');
    notifier.setSearch('');
    expect(notifier.state.posters, isEmpty);
  });

  test('account change replaces the search and ignores pending responses', () async {
    final pending = Completer<Response<ServerQueryResult>>();
    final container = _container((_) => pending.future);
    final subscription = container.listen(librarySearchProvider(key), (_, _) {});
    addTearDown(subscription.close);
    final notifier = container.read(librarySearchProvider(key).notifier)..setSearch('movie');
    final loading = notifier.loadMore();
    container.read(userProvider.notifier).userState = container.read(userProvider)!.copyWith(id: 'bob');
    await container.pump();
    pending.complete(_page('alice-private-item'));
    await loading;
    expect(notifier.mounted, isFalse);
    expect(container.read(librarySearchProvider(key)).posters, isEmpty);
  });

  test('library failure stops loading and permits a retry', () async {
    var calls = 0;
    final container = _container((_) async {
      if (++calls == 1) throw StateError('network failed');
      return _page('retry');
    });
    final subscription = container.listen(librarySearchProvider(key), (_, _) {});
    addTearDown(subscription.close);
    final notifier = container.read(librarySearchProvider(key).notifier)..setSearch('movie');
    await notifier.loadMore();
    expect(notifier.state.loading, isFalse);
    await notifier.loadMore();
    expect(notifier.state.posters.single.id, 'retry');
  });
}
