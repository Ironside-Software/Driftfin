import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/models/seerr_credentials_model.dart';
import 'package:driftfin/providers/shared_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('account migration removes only known plugin credentials, including inactive accounts', () async {
    final accounts = CredentialOrigin.values
        .map(
          (origin) => AccountModel(
            name: origin.name,
            id: origin.name,
            avatar: '',
            lastUsed: DateTime(2026),
            credentials: CredentialsModel(serverId: 'server', token: 'jellyfin-token'),
            seerrCredentials: SeerrCredentialsModel(
              origin: origin,
              serverUrl: 'https://seerr.test',
              apiKey: '${origin.name}-key',
            ),
          ),
        )
        .toList();
    SharedPreferences.setMockInitialValues({'loginCredentialsKey': accounts.map(jsonEncode).toList()});
    final prefs = await SharedPreferences.getInstance();
    final helper = SharedHelper(sharedPreferences: prefs);
    final restored = helper.getAccounts();
    expect(restored.singleWhere((account) => account.id == 'plugin').seerrCredentials, isNull);
    expect(restored.singleWhere((account) => account.id == 'manual').seerrCredentials?.apiKey, 'manual-key');
    expect(restored.singleWhere((account) => account.id == 'unknown').seerrCredentials?.apiKey, 'unknown-key');
    expect(restored.every((account) => account.credentials.token == 'jellyfin-token'), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getStringList('loginCredentialsKey').toString(), isNot(contains('plugin-key')));
    // Every subsequent save uses the same sanitization, even for stale in-memory accounts.
    await helper.saveAccounts(accounts);
    expect(prefs.getStringList('loginCredentialsKey').toString(), isNot(contains('plugin-key')));
  });
}
