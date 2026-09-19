import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/util/auth_service.dart';

class _Auth extends LocalAuthPlatform {
  AuthenticationOptions? options;
  bool cancelled = false;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    this.options = options;
    if (cancelled) throw const LocalAuthException(code: LocalAuthExceptionCode.userCanceled);
    return true;
  }
}

void main() {
  final user = AccountModel(
    name: 'Test',
    id: 'user',
    avatar: '',
    lastUsed: DateTime(2026),
    credentials: CredentialsModel(),
  );

  testWidgets('preserves auth options and treats cancellation as failed authentication', (tester) async {
    final original = LocalAuthPlatform.instance;
    final auth = _Auth();
    LocalAuthPlatform.instance = auth;
    addTearDown(() => LocalAuthPlatform.instance = original);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(await AuthService.authenticateUser(context, user, sensitiveTransaction: true), isTrue);
    expect(auth.options!.stickyAuth, isTrue);
    expect(auth.options!.sensitiveTransaction, isTrue);
    auth.cancelled = true;
    expect(await AuthService.authenticateUser(context, user), isFalse);
    expect(tester.takeException(), isNull);
  });
}
