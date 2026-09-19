import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/seerr_watched_provider.dart';
import 'package:driftfin/providers/service_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/user_provider.dart';

AccountModel account(String id, {String server = 'server'}) => AccountModel(
  name: id,
  id: id,
  avatar: '',
  lastUsed: DateTime(2026),
  credentials: CredentialsModel(serverId: server),
);

class TestUser extends User {
  TestUser(this.account);
  final AccountModel account;
  bool fail = false;
  final calls = <(bool, String)>[];
  @override
  AccountModel build() => account;
  @override
  Future<Response<UserData>?> markAsPlayed(bool enable, String itemId) async {
    calls.add((enable, itemId));
    return Response(http.Response('', fail ? 500 : 200), UserData(played: enable));
  }
}

class _Jelly extends JellyService {
  _Jelly(Ref ref) : super(ref, JellyfinOpenApi.create());
  @override
  Future<Response<UserData>> userItemsItemIdUserDataGet({String? itemId}) async =>
      Response(http.Response('', 200), const UserData(played: true));
}

class _Api extends JellyApi {
  @override
  JellyService build() => _Jelly(ref);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  ProviderContainer containerFor(TestUser user) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        userProvider.overrideWith(() => user),
        jellyApiProvider.overrideWith(_Api.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  const key = (mediaType: 'movie', tmdbId: 42, jellyfinItemId: null);

  test('external watched status survives recreation and is isolated by user, server and type', () async {
    final provider = seerrWatchedProvider(key);
    final container = containerFor(TestUser(account('one')));
    container.listen(provider, (_, _) {});
    expect(await container.read(provider.future), isFalse);
    await container.read(provider.notifier).setWatched(true);
    final restored = containerFor(TestUser(account('one')));
    restored.listen(provider, (_, _) {});
    expect(await restored.read(provider.future), isTrue);
    for (final other in [account('two'), account('one', server: 'other')]) {
      final isolated = containerFor(TestUser(other));
      isolated.listen(provider, (_, _) {});
      expect(await isolated.read(provider.future), isFalse);
    }
    expect(
      await restored.read(seerrWatchedProvider((mediaType: 'tvshow', tmdbId: 42, jellyfinItemId: null)).future),
      isFalse,
    );
    await restored.read(provider.notifier).setWatched(false);
    expect(await restored.read(provider.future), isFalse);
  });

  test('library status reads Jellyfin, writes its item id, and preserves status on failure', () async {
    final user = TestUser(account('one'));
    final container = containerFor(user);
    final provider = seerrWatchedProvider((mediaType: 'movie', tmdbId: 42, jellyfinItemId: 'jellyfin-id'));
    container.listen(provider, (_, _) {});
    expect(await container.read(provider.future), isTrue);
    user.fail = true;
    await expectLater(container.read(provider.notifier).setWatched(false), throwsStateError);
    expect(container.read(provider).value, isTrue);
    user.fail = false;
    await container.read(provider.notifier).setWatched(false);
    expect(container.read(provider).value, isFalse);
    expect(user.calls, [(false, 'jellyfin-id'), (false, 'jellyfin-id')]);
    expect(prefs.getKeys(), isEmpty);
  });
}
