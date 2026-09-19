import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/items/overview_model.dart';
import 'package:driftfin/models/library_filters_model.dart';
import 'package:driftfin/models/seerr_credentials_model.dart';
import 'package:driftfin/models/syncing/sync_settings_model.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/sync_provider.dart';
import 'package:driftfin/providers/user_provider.dart';

ItemBaseModel _item({required String id}) => ItemBaseModel(
  name: 'Item',
  id: id,
  overview: const OverviewModel(),
  parentId: null,
  playlistId: null,
  images: null,
  childCount: null,
  primaryRatio: null,
  userData: const UserData(),
  canDownload: null,
  canDelete: null,
  jellyType: null,
);

/// Test double for [SyncNotifier] so `showSyncButtonProvider` can be driven
/// without touching the database/background-downloader machinery the real
/// notifier wires up in its constructor.
class _FakeSyncNotifier extends StateNotifier<SyncSettingsModel> implements SyncNotifier {
  _FakeSyncNotifier([SyncSettingsModel? initial]) : super(initial ?? SyncSettingsModel());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AccountModel _account({
  String id = 'user-1',
  bool canDownload = false,
  List<String> searchQueryHistory = const [],
  List<LibraryFiltersModel> libraryFilters = const [],
  SeerrCredentialsModel? seerrCredentials,
}) {
  return AccountModel(
    name: 'Test User',
    id: id,
    avatar: '',
    lastUsed: DateTime(2020),
    credentials: CredentialsModel(token: 'token-123', url: 'https://jellyfin.example.com', deviceId: 'device-1'),
    searchQueryHistory: searchQueryHistory,
    libraryFilters: libraryFilters,
    seerrCredentials: seerrCredentials,
    policy: canDownload
        ? const UserPolicy(enableContentDownloading: true, authenticationProviderId: '', passwordResetProviderId: '')
        : null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  ProviderContainer makeContainer({SharedPreferences? prefs}) {
    return ProviderContainer(overrides: [if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs)]);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = makeContainer(prefs: prefs);
  });

  tearDown(() => container.dispose());

  group('User.build', () {
    test('starts with a null account', () {
      expect(container.read(userProvider), isNull);
    });
  });

  group('User.loginUser / clear / updateUser', () {
    test('loginUser sets state directly without touching lastUsed', () {
      final account = _account().copyWith(lastUsed: DateTime(2000));
      container.read(userProvider.notifier).loginUser(account);
      expect(container.read(userProvider), account);
      expect(container.read(userProvider)?.lastUsed, DateTime(2000));
    });

    test('loginUser(null) clears state', () {
      container.read(userProvider.notifier).loginUser(_account());
      container.read(userProvider.notifier).loginUser(null);
      expect(container.read(userProvider), isNull);
    });

    test('clear sets state to null', () {
      container.read(userProvider.notifier).loginUser(_account());
      container.read(userProvider.notifier).clear();
      expect(container.read(userProvider), isNull);
    });

    test('clear on already-null state is a no-op', () {
      container.read(userProvider.notifier).clear();
      expect(container.read(userProvider), isNull);
    });

    test('updateUser replaces the account and stamps lastUsed to now', () {
      final account = _account().copyWith(lastUsed: DateTime(2000));
      final before = DateTime.now();
      container.read(userProvider.notifier).updateUser(account);
      final after = DateTime.now();
      final result = container.read(userProvider);
      expect(result?.id, account.id);
      expect(result!.lastUsed.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(result.lastUsed.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('updateUser(null) clears state', () {
      container.read(userProvider.notifier).loginUser(_account());
      container.read(userProvider.notifier).updateUser(null);
      expect(container.read(userProvider), isNull);
    });
  });

  group('User.setAuthMethod', () {
    test('updates the auth method when logged in', () {
      container.read(userProvider.notifier).loginUser(_account());
      container.read(userProvider.notifier).setAuthMethod(Authentication.biometrics);
      expect(container.read(userProvider)?.authMethod, Authentication.biometrics);
    });

    test('is a no-op when logged out', () {
      container.read(userProvider.notifier).setAuthMethod(Authentication.biometrics);
      expect(container.read(userProvider), isNull);
    });
  });

  group('User.setLocalURL', () {
    test('sets a non-empty local url', () {
      container.read(userProvider.notifier).loginUser(_account());
      container.read(userProvider.notifier).setLocalURL('http://192.168.1.5:8096');
      expect(container.read(userProvider)?.credentials.localUrl, 'http://192.168.1.5:8096');
    });

    test('an empty string is normalized to null', () {
      container.read(userProvider.notifier).loginUser(_account());
      container.read(userProvider.notifier).setLocalURL('http://192.168.1.5:8096');
      container.read(userProvider.notifier).setLocalURL('');
      expect(container.read(userProvider)?.credentials.localUrl, isNull);
    });

    test('null clears the local url', () {
      container.read(userProvider.notifier).loginUser(_account());
      container.read(userProvider.notifier).setLocalURL('http://192.168.1.5:8096');
      container.read(userProvider.notifier).setLocalURL(null);
      expect(container.read(userProvider)?.credentials.localUrl, isNull);
    });

    test('is a no-op when logged out', () {
      container.read(userProvider.notifier).setLocalURL('http://x');
      expect(container.read(userProvider), isNull);
    });
  });

  group('Seerr credential setters', () {
    test('setSeerrServerUrl trims and creates credentials if absent', () {
      container.read(userProvider.notifier).loginUser(_account());
      container.read(userProvider.notifier).setSeerrServerUrl('  https://seerr.example.com  ');
      expect(container.read(userProvider)?.seerrCredentials?.serverUrl, 'https://seerr.example.com');
    });

    test('setSeerrServerUrl(null) sets an empty string', () {
      container.read(userProvider.notifier).loginUser(_account());
      container.read(userProvider.notifier).setSeerrServerUrl(null);
      expect(container.read(userProvider)?.seerrCredentials?.serverUrl, '');
    });

    test('setSeerrServerUrl is a no-op when logged out', () {
      container.read(userProvider.notifier).setSeerrServerUrl('https://x');
      expect(container.read(userProvider), isNull);
    });

    test('setSeerrApiKey trims and preserves other seerr fields', () {
      final account = _account(seerrCredentials: const SeerrCredentialsModel(serverUrl: 'https://seerr.example.com'));
      container.read(userProvider.notifier).loginUser(account);
      container.read(userProvider.notifier).setSeerrApiKey('  abc123  ');
      final creds = container.read(userProvider)?.seerrCredentials;
      expect(creds?.apiKey, 'abc123');
      expect(creds?.serverUrl, 'https://seerr.example.com');
    });

    test('setSeerrSessionCookie trims the cookie', () {
      container.read(userProvider.notifier).loginUser(_account());
      container.read(userProvider.notifier).setSeerrSessionCookie('  cookie-value  ');
      expect(container.read(userProvider)?.seerrCredentials?.sessionCookie, 'cookie-value');
    });

    test('setSeerrCustomHeaders replaces the header map', () {
      container.read(userProvider.notifier).loginUser(_account());
      container.read(userProvider.notifier).setSeerrCustomHeaders({'X-Foo': 'bar'});
      expect(container.read(userProvider)?.seerrCredentials?.customHeaders, {'X-Foo': 'bar'});
    });

    test('clearSeerrCustomHeaders empties the header map', () {
      container.read(userProvider.notifier).loginUser(_account());
      container.read(userProvider.notifier).setSeerrCustomHeaders({'X-Foo': 'bar'});
      container.read(userProvider.notifier).clearSeerrCustomHeaders();
      expect(container.read(userProvider)?.seerrCredentials?.customHeaders, {});
    });

    test('logoutSeerr clears api key and session cookie but keeps the server url', () {
      final account = _account(
        seerrCredentials: const SeerrCredentialsModel(
          serverUrl: 'https://seerr.example.com',
          apiKey: 'abc',
          sessionCookie: 'cookie',
        ),
      );
      container.read(userProvider.notifier).loginUser(account);
      container.read(userProvider.notifier).logoutSeerr();
      final creds = container.read(userProvider)?.seerrCredentials;
      expect(creds?.apiKey, '');
      expect(creds?.sessionCookie, '');
      expect(creds?.serverUrl, 'https://seerr.example.com');
    });

    test('logoutSeerr is a no-op when logged out', () {
      container.read(userProvider.notifier).logoutSeerr();
      expect(container.read(userProvider), isNull);
    });
  });

  group('User.addSearchQuery', () {
    test('appends a new query', () {
      container.read(userProvider.notifier).loginUser(_account());
      container.read(userProvider.notifier).addSearchQuery('batman');
      expect(container.read(userProvider)?.searchQueryHistory, ['batman']);
    });

    test('empty values are ignored', () {
      container.read(userProvider.notifier).loginUser(_account());
      container.read(userProvider.notifier).addSearchQuery('');
      expect(container.read(userProvider)?.searchQueryHistory, isEmpty);
    });

    test('re-adding an existing query moves it to the end (dedupe)', () {
      container.read(userProvider.notifier).loginUser(_account(searchQueryHistory: ['a', 'b', 'c']));
      container.read(userProvider.notifier).addSearchQuery('a');
      expect(container.read(userProvider)?.searchQueryHistory, ['b', 'c', 'a']);
    });

    test('is a no-op (state stays null) when logged out', () {
      container.read(userProvider.notifier).addSearchQuery('batman');
      expect(container.read(userProvider), isNull);
    });
  });

  group('User.removeSearchQuery', () {
    // BUG (documented, not fixed): removeSearchQuery is implemented as
    //   state?.searchQueryHistory ?? []
    //     ..remove(value)
    //     ..take(50)
    // `state?.searchQueryHistory` is a freezed-generated getter that always
    // returns an `EqualUnmodifiableListView` wrapper, regardless of what
    // list was originally passed in to the model. Calling `..remove(value)`
    // on that unmodifiable view throws `UnsupportedError` at runtime instead
    // of producing an updated history. (Separately, even if it didn't throw,
    // `..take(50)` is a cascade that discards the lazy Iterable it returns,
    // so the "cap history at 50 items" intent would never be applied either.)
    test('throws because the underlying list is unmodifiable', () {
      container.read(userProvider.notifier).loginUser(_account(searchQueryHistory: ['a', 'b', 'c']));
      expect(() => container.read(userProvider.notifier).removeSearchQuery('b'), throwsUnsupportedError);
    });

    test('still throws when the value is not present in the history', () {
      container.read(userProvider.notifier).loginUser(_account(searchQueryHistory: ['a', 'b']));
      expect(() => container.read(userProvider.notifier).removeSearchQuery('zzz'), throwsUnsupportedError);
    });

    test('is a no-op (state stays null) when logged out', () {
      // No account is logged in, so `state` is null and `state?.searchQueryHistory`
      // short-circuits to null before the `?? []` fallback - a fresh, mutable
      // list literal - so no unmodifiable list is ever touched and no
      // exception is thrown here.
      container.read(userProvider.notifier).removeSearchQuery('a');
      expect(container.read(userProvider), isNull);
    });
  });

  group('User.clearSearchQuery', () {
    test('empties the search history', () {
      container.read(userProvider.notifier).loginUser(_account(searchQueryHistory: ['a', 'b']));
      container.read(userProvider.notifier).clearSearchQuery();
      expect(container.read(userProvider)?.searchQueryHistory, isEmpty);
    });

    test('is a no-op when logged out', () {
      container.read(userProvider.notifier).clearSearchQuery();
      expect(container.read(userProvider), isNull);
    });
  });

  group('User.removeFilter', () {
    test('removes a matching filter from the list', () {
      final f1 = LibraryFiltersModel(id: 'f1', name: 'Filter 1', isFavourite: false);
      final f2 = LibraryFiltersModel(id: 'f2', name: 'Filter 2', isFavourite: false);
      container.read(userProvider.notifier).loginUser(_account(libraryFilters: [f1, f2]));
      container.read(userProvider.notifier).removeFilter(f1);
      expect(container.read(userProvider)?.libraryFilters, [f2]);
    });

    test('removing a filter not present is a no-op on the list contents', () {
      final f1 = LibraryFiltersModel(id: 'f1', name: 'Filter 1', isFavourite: false);
      final other = LibraryFiltersModel(id: 'other', name: 'Other', isFavourite: false);
      container.read(userProvider.notifier).loginUser(_account(libraryFilters: [f1]));
      container.read(userProvider.notifier).removeFilter(other);
      expect(container.read(userProvider)?.libraryFilters, [f1]);
    });

    test('is a no-op when logged out', () {
      final f1 = LibraryFiltersModel(id: 'f1', name: 'Filter 1', isFavourite: false);
      container.read(userProvider.notifier).removeFilter(f1);
      expect(container.read(userProvider), isNull);
    });
  });

  group('User.saveFilter', () {
    test('prepends a new filter (by id) to the front of the list', () {
      final f1 = LibraryFiltersModel(id: 'f1', name: 'Filter 1', isFavourite: false);
      container.read(userProvider.notifier).loginUser(_account(libraryFilters: [f1]));

      final f2 = LibraryFiltersModel(id: 'f2', name: 'Filter 2', isFavourite: false);
      container.read(userProvider.notifier).saveFilter(f2);

      expect(container.read(userProvider)?.libraryFilters, [f2, f1]);
    });

    test('replaces an existing filter with the same id in place', () {
      final f1 = LibraryFiltersModel(id: 'f1', name: 'Filter 1', isFavourite: false, ids: ['a']);
      final f2 = LibraryFiltersModel(id: 'f2', name: 'Filter 2', isFavourite: false, ids: ['b']);
      container.read(userProvider.notifier).loginUser(_account(libraryFilters: [f1, f2]));

      final updatedF1 = f1.copyWith(name: 'Filter 1 renamed');
      container.read(userProvider.notifier).saveFilter(updatedF1);

      final result = container.read(userProvider)?.libraryFilters;
      // LibraryFiltersModel has no generated value equality (no `==`/`hashCode`
      // override), so `saveFilter`'s internal `.map(...)` rebuild of every
      // entry (even ones left logically unchanged, via a no-op `copyWith`)
      // produces a new `f2` instance that is not identical/`==` to the
      // original `f2`. Compare field-by-field instead of list identity.
      expect(result, hasLength(2));
      expect(result?[0].id, updatedF1.id);
      expect(result?[0].name, updatedF1.name);
      expect(result?[0].ids, updatedF1.ids);
      expect(result?[1].id, f2.id);
      expect(result?[1].name, f2.name);
      expect(result?[1].ids, f2.ids);
    });

    test('marking a filter favourite unsets isFavourite on other entries sharing the same ids', () {
      final f1 = LibraryFiltersModel(id: 'f1', name: 'Filter 1', isFavourite: true, ids: ['a', 'b']);
      final f2 = LibraryFiltersModel(id: 'f2', name: 'Filter 2', isFavourite: false, ids: ['x']);
      container.read(userProvider.notifier).loginUser(_account(libraryFilters: [f1, f2]));

      // Save an update to f1 that is favourite and has the same ids as f1 itself;
      // f2 has different ids so it must be unaffected.
      final updatedF1 = f1.copyWith(isFavourite: true);
      container.read(userProvider.notifier).saveFilter(updatedF1);

      final result = container.read(userProvider)?.libraryFilters;
      final resultF1 = result?.firstWhere((e) => e.id == 'f1');
      final resultF2 = result?.firstWhere((e) => e.id == 'f2');
      expect(resultF1?.isFavourite, isTrue);
      expect(resultF2?.isFavourite, isFalse, reason: 'unrelated ids are untouched, not "unset"');
    });

    test('marking a filter favourite unsets isFavourite on a different filter with the same ids', () {
      final f1 = LibraryFiltersModel(id: 'f1', name: 'Filter 1', isFavourite: false, ids: ['a', 'b']);
      final f2 = LibraryFiltersModel(id: 'f2', name: 'Filter 2 (dup ids)', isFavourite: true, ids: ['a', 'b']);
      container.read(userProvider.notifier).loginUser(_account(libraryFilters: [f1, f2]));

      final updatedF1 = f1.copyWith(isFavourite: true);
      container.read(userProvider.notifier).saveFilter(updatedF1);

      final result = container.read(userProvider)?.libraryFilters;
      final resultF1 = result?.firstWhere((e) => e.id == 'f1');
      final resultF2 = result?.firstWhere((e) => e.id == 'f2');
      expect(resultF1?.isFavourite, isTrue, reason: 'the saved filter itself keeps its own isFavourite value');
      expect(resultF2?.isFavourite, isFalse, reason: 'other entries containing the same id-set get isFavourite unset');
    });

    test('is a no-op when logged out', () {
      final f1 = LibraryFiltersModel(id: 'f1', name: 'Filter 1', isFavourite: false);
      container.read(userProvider.notifier).saveFilter(f1);
      expect(container.read(userProvider), isNull);
    });
  });

  group('User.deleteAllFilters', () {
    test('empties the filters list', () {
      final f1 = LibraryFiltersModel(id: 'f1', name: 'Filter 1', isFavourite: false);
      container.read(userProvider.notifier).loginUser(_account(libraryFilters: [f1]));
      container.read(userProvider.notifier).deleteAllFilters();
      expect(container.read(userProvider)?.libraryFilters, isEmpty);
    });

    test('is a no-op when logged out', () {
      container.read(userProvider.notifier).deleteAllFilters();
      expect(container.read(userProvider), isNull);
    });
  });

  group('User.createDownloadUrl', () {
    test('builds a url-encoded download link from credentials', () {
      container.read(userProvider.notifier).loginUser(_account());
      final item = _item(id: 'item-42');
      final url = container.read(userProvider.notifier).createDownloadUrl(item);
      expect(url, 'https://jellyfin.example.com/Items/item-42/Download?ApiKey=token-123');
    });

    test('still builds a (blank-credential) url when logged out', () {
      final item = _item(id: 'item-42');
      final url = container.read(userProvider.notifier).createDownloadUrl(item);
      // `state` is null here, so both `state?.credentials.url` and
      // `state?.credentials.token` evaluate to null, and their string
      // interpolation renders as the literal word "null".
      expect(url, 'null/Items/item-42/Download?ApiKey=null');
    });
  });

  group('showSyncButtonProvider', () {
    ProviderContainer syncContainer({required bool canDownload, required bool hasSyncedItems}) {
      final account = canDownload ? _account(canDownload: true) : null;
      return ProviderContainer(
        overrides: [
          userProvider.overrideWith(() {
            final notifier = User();
            return notifier;
          }),
          syncProvider.overrideWith((ref) => _FakeSyncNotifier(SyncSettingsModel(items: hasSyncedItems ? [] : []))),
        ],
      )..read(userProvider.notifier).loginUser(account);
    }

    test('false when neither can download nor has synced items', () {
      final c = syncContainer(canDownload: false, hasSyncedItems: false);
      addTearDown(c.dispose);
      expect(c.read(showSyncButtonProviderProvider), isFalse);
    });

    test('true when the user can download even with no synced items', () {
      final c = syncContainer(canDownload: true, hasSyncedItems: false);
      addTearDown(c.dispose);
      expect(c.read(showSyncButtonProviderProvider), isTrue);
    });
  });
}
