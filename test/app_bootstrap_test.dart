import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/bootstrap/app_bootstrap.dart';
import 'package:driftfin/models/settings/arguments_model.dart';
import 'package:driftfin/models/settings/client_settings_model.dart';
import 'package:driftfin/models/syncing/transcode_download_model.dart';
import 'package:driftfin/providers/crash_log_provider.dart';
import 'package:driftfin/util/application_info.dart';
import 'package:driftfin/util/driftfin_config.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationCachePath() async => '.';
}

ClientSettingsModel _clientSettings({required bool enableCrashReporting}) => ClientSettingsModel.internal(
      transcodeDownloadModel: TranscodeDownloadModel.fromDefaults(),
      enableCrashReporting: enableCrashReporting,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProviderPlatform();

  tearDown(() => DriftfinConfig.sentryDsn = null);

  group('resolvedSentryDsn', () {
    // `flutter test` always runs on the VM (kIsWeb == false), so the
    // config.json-backed DSN is never preferred here — this pins that guard:
    // DriftfinConfig.sentryDsn must never leak into non-Web builds.
    test('ignores DriftfinConfig.sentryDsn outside Web and falls back to the compile-time value', () {
      DriftfinConfig.sentryDsn = 'https://runtime-only-dsn';

      expect(resolvedSentryDsn, sentryDsn);
      expect(resolvedSentryDsn, isNot('https://runtime-only-dsn'));
    });

    test('compile-time sentryDsn is empty unless --dart-define=SENTRY_DSN is passed', () {
      // Documents the default: without a build-time DSN, resolvedSentryDsn is
      // empty on every non-Web platform regardless of any other setting.
      expect(sentryDsn, isEmpty);
      expect(resolvedSentryDsn, isEmpty);
    });
  });

  group('resolveSentryDsn (pure form, both branches driven directly)', () {
    test('prefers the web-configured DSN when isWeb and it is set', () {
      expect(
        resolveSentryDsn(isWeb: true, webConfiguredDsn: 'https://web-dsn', buildTimeDsn: 'https://build-dsn'),
        'https://web-dsn',
      );
    });

    test('falls back to the build-time DSN when isWeb but nothing is configured', () {
      expect(
        resolveSentryDsn(isWeb: true, webConfiguredDsn: null, buildTimeDsn: 'https://build-dsn'),
        'https://build-dsn',
      );
      expect(
        resolveSentryDsn(isWeb: true, webConfiguredDsn: '', buildTimeDsn: 'https://build-dsn'),
        'https://build-dsn',
      );
    });

    test('ignores the web-configured DSN when not web', () {
      expect(
        resolveSentryDsn(isWeb: false, webConfiguredDsn: 'https://web-dsn', buildTimeDsn: 'https://build-dsn'),
        'https://build-dsn',
      );
    });
  });

  group('computeCrashReportingEnabled', () {
    test('true only when a DSN is resolved and the user opted in', () {
      expect(
        computeCrashReportingEnabled(dsn: 'https://dsn', clientSettings: _clientSettings(enableCrashReporting: true)),
        isTrue,
      );
    });

    test('false without a DSN even if the user opted in', () {
      expect(
        computeCrashReportingEnabled(dsn: '', clientSettings: _clientSettings(enableCrashReporting: true)),
        isFalse,
      );
    });

    test('false when the user has not opted in, even with a DSN', () {
      expect(
        computeCrashReportingEnabled(dsn: 'https://dsn', clientSettings: _clientSettings(enableCrashReporting: false)),
        isFalse,
      );
    });
  });

  group('AppBootstrapResult', () {
    test('exposes every bootstrap field as-constructed', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final crashProvider = CrashLogNotifier();
      addTearDown(crashProvider.dispose);

      final result = AppBootstrapResult(
        sharedPreferences: prefs,
        applicationInfo: ApplicationInfo(
          name: 'Driftfin',
          version: '1.0.0',
          buildNumber: '1',
          platform: TargetPlatform.linux,
        ),
        applicationDirectory: Directory(''),
        argumentsModel: ArgumentsModel(),
        crashProvider: crashProvider,
        crashReportingEnabled: true,
        sentryDsn: 'https://dsn',
      );

      expect(result.sharedPreferences, prefs);
      expect(result.applicationInfo.name, 'Driftfin');
      expect(result.crashProvider, crashProvider);
      expect(result.crashReportingEnabled, isTrue);
      expect(result.sentryDsn, 'https://dsn');
    });
  });
}
