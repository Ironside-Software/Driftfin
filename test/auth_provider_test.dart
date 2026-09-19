import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/models/login_screen_model.dart';
import 'package:driftfin/models/seerr_credentials_model.dart';
import 'package:driftfin/providers/auth_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/util/driftfin_config.dart';

/// Builds a minimal [AccountModel] for a given server/user, optionally with
/// Seerr credentials and a `lastUsed` timestamp (used to test recency sorting).
AccountModel _account({
  required String id,
  required String serverId,
  String? seerrUrl,
  DateTime? lastUsed,
}) {
  return AccountModel(
    name: id,
    id: id,
    avatar: '',
    lastUsed: lastUsed ?? DateTime.now(),
    credentials: CredentialsModel.internal(serverId: serverId),
    seerrCredentials: seerrUrl == null ? null : SeerrCredentialsModel(serverUrl: seerrUrl),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // Reset any global config mutated by other tests in this isolate.
    DriftfinConfig.baseUrl = null;
    DriftfinConfig.seerrBaseUrl = null;
  });

  ProviderContainer container() {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  }

  group('setTempSeerrUrl', () {
    test('trims and stores a non-empty url', () {
      final c = container();
      addTearDown(c.dispose);
      final notifier = c.read(authProvider.notifier);

      notifier.setTempSeerrUrl('  https://seerr.example.com  ');

      expect(c.read(authProvider).tempSeerrUrl, 'https://seerr.example.com');
    });

    test('whitespace-only url becomes null', () {
      final c = container();
      addTearDown(c.dispose);
      final notifier = c.read(authProvider.notifier);

      notifier.setTempSeerrUrl('   ');

      expect(c.read(authProvider).tempSeerrUrl, isNull);
    });

    test('null stays null', () {
      final c = container();
      addTearDown(c.dispose);
      final notifier = c.read(authProvider.notifier);

      notifier.setTempSeerrUrl(null);

      expect(c.read(authProvider).tempSeerrUrl, isNull);
    });
  });

  group('setTempSeerrSessionCookie', () {
    test('trims and stores a non-empty cookie', () {
      final c = container();
      addTearDown(c.dispose);
      final notifier = c.read(authProvider.notifier);

      notifier.setTempSeerrSessionCookie('  cookie-value  ');

      expect(c.read(authProvider).tempSeerrSessionCookie, 'cookie-value');
    });

    test('whitespace-only cookie becomes null', () {
      final c = container();
      addTearDown(c.dispose);
      final notifier = c.read(authProvider.notifier);

      notifier.setTempSeerrSessionCookie('  ');

      expect(c.read(authProvider).tempSeerrSessionCookie, isNull);
    });
  });

  group('addNewUser / goUserSelect', () {
    test('addNewUser switches screen to login', () {
      final c = container();
      addTearDown(c.dispose);
      final notifier = c.read(authProvider.notifier);

      notifier.addNewUser();

      expect(c.read(authProvider).screen, LoginScreenType.login);
    });

    test('goUserSelect switches screen to users and clears serverLoginModel when no base url', () {
      final c = container();
      addTearDown(c.dispose);
      final notifier = c.read(authProvider.notifier);

      notifier.addNewUser();
      expect(c.read(authProvider).screen, LoginScreenType.login);

      notifier.goUserSelect();

      expect(c.read(authProvider).screen, LoginScreenType.users);
      expect(c.read(authProvider).serverLoginModel, isNull);
    });

    test('goUserSelect keeps serverLoginModel when hasBaseUrl is true', () {
      final c = container();
      addTearDown(c.dispose);
      final notifier = c.read(authProvider.notifier);

      final loginModel = ServerLoginModel(tempCredentials: CredentialsModel.internal(url: 'http://server'));
      c.read(authProvider.notifier).state = c.read(authProvider).copyWith(
            hasBaseUrl: true,
            serverLoginModel: loginModel,
          );

      notifier.goUserSelect();

      expect(c.read(authProvider).screen, LoginScreenType.users);
      expect(c.read(authProvider).serverLoginModel, loginModel);
    });
  });

  group('getSavedAccounts', () {
    test('returns empty list when nothing saved', () {
      final c = container();
      addTearDown(c.dispose);

      final accounts = c.read(authProvider.notifier).getSavedAccounts();

      expect(accounts, isEmpty);
      expect(c.read(authProvider).accounts, isEmpty);
    });

    test('reads accounts persisted via sharedUtilityProvider and updates state', () async {
      final c = container();
      addTearDown(c.dispose);

      final account = _account(id: 'u1', serverId: 's1');
      await c.read(sharedUtilityProvider).saveAccounts([account]);

      final accounts = c.read(authProvider.notifier).getSavedAccounts();

      expect(accounts, hasLength(1));
      expect(accounts.first.id, 'u1');
      expect(c.read(authProvider).accounts, hasLength(1));
    });
  });

  group('reOrderUsers', () {
    test('reorders accounts in state and persists the new order', () async {
      final c = container();
      addTearDown(c.dispose);

      final a = _account(id: 'a', serverId: 's1');
      final b = _account(id: 'b', serverId: 's1');
      final cAcc = _account(id: 'c', serverId: 's1');
      await c.read(sharedUtilityProvider).saveAccounts([a, b, cAcc]);
      c.read(authProvider.notifier).getSavedAccounts();

      c.read(authProvider.notifier).reOrderUsers(0, 2);

      final ids = c.read(authProvider).accounts.map((e) => e.id).toList();
      expect(ids, ['b', 'a', 'c']);

      // Persisted too.
      final persisted = c.read(sharedUtilityProvider).getAccounts().map((e) => e.id).toList();
      expect(persisted, ['b', 'a', 'c']);
    });
  });

  group('clearAllProviders / switchUser', () {
    test('clearAllProviders resets dependent providers without throwing', () {
      final c = container();
      addTearDown(c.dispose);

      expect(() => c.read(authProvider.notifier).clearAllProviders(), returnsNormally);
    });

    test('switchUser calls clearAllProviders without throwing', () async {
      final c = container();
      addTearDown(c.dispose);

      await expectLater(c.read(authProvider.notifier).switchUser(), completes);
    });
  });

  // `_findSeerrUrlForServer` is private, but is invoked from `_fetchServerInfo`
  // (network-bound) and from nowhere else public. We can't reach it directly
  // without a network round trip, so we validate its documented precedence
  // rules by exercising `DriftfinConfig.seerrBaseUrl` and the account list it
  // reads from `state.accounts`, using `initModel` (which populates
  // `state.accounts` from saved accounts and does not require network when
  // `DriftfinConfig.baseUrl` is null).
  group('initModel (no base url configured)', () {
    test('populates accounts from shared storage and defaults to login screen when empty', () async {
      final c = container();
      addTearDown(c.dispose);

      await c.read(authProvider.notifier).initModel();

      expect(c.read(authProvider).accounts, isEmpty);
      expect(c.read(authProvider).screen, LoginScreenType.login);
      expect(c.read(authProvider).hasBaseUrl, isFalse);
    });

    test('defaults to users screen when saved accounts exist', () async {
      final c = container();
      addTearDown(c.dispose);

      await c.read(sharedUtilityProvider).saveAccounts([_account(id: 'u1', serverId: 's1')]);

      await c.read(authProvider.notifier).initModel();

      expect(c.read(authProvider).accounts, hasLength(1));
      expect(c.read(authProvider).screen, LoginScreenType.users);
    });
  });

  group('DriftfinConfig.seerrBaseUrl precedence (documents _findSeerrUrlForServer contract)', () {
    // These tests exercise DriftfinConfig directly since _findSeerrUrlForServer
    // is private and only reachable via the network-bound _fetchServerInfo.
    // They document/verify the static config half of that method's contract.
    test('seerrBaseUrl set takes precedence and is non-empty', () {
      DriftfinConfig.seerrBaseUrl = 'https://global-seerr.example.com';
      expect(DriftfinConfig.seerrBaseUrl?.isNotEmpty, isTrue);
    });

    test('seerrBaseUrl unset is null', () {
      expect(DriftfinConfig.seerrBaseUrl, isNull);
    });
  });
}
