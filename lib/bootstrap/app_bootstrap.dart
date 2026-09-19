import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/models/settings/arguments_model.dart';
import 'package:driftfin/models/settings/client_settings_model.dart';
import 'package:driftfin/providers/crash_log_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/src/video_player_helper.g.dart';
import 'package:driftfin/util/application_info.dart';
import 'package:driftfin/util/driftfin_config.dart';
import 'package:driftfin/util/string_extensions.dart';
import 'package:driftfin/util/svg_utils.dart';

/// Sentry DSN, supplied at build time via `--dart-define=SENTRY_DSN=...`.
/// Never hardcoded — without it, crash reporting stays fully inert even if opted in.
const sentryDsn = String.fromEnvironment('SENTRY_DSN');

/// The DSN actually used at runtime. On Web this prefers the DSN injected into
/// `config/config.json` at container start (docker-compose's `SENTRY_DSN` env
/// var) over the compile-time [sentryDsn], since a single Web build is shared
/// across deployments and can't bake in a deployment-specific value. Every
/// other platform only ever has the compile-time value.
String get resolvedSentryDsn => resolveSentryDsn(
      isWeb: kIsWeb,
      webConfiguredDsn: DriftfinConfig.sentryDsn,
      buildTimeDsn: sentryDsn,
    );

/// Pure form of [resolvedSentryDsn]. `kIsWeb` is a compile-time constant that
/// gets folded to `false` on the VM, so its branch is unreachable in
/// `flutter test`; taking `isWeb` as a plain parameter keeps both branches
/// testable.
@visibleForTesting
String resolveSentryDsn({required bool isWeb, required String? webConfiguredDsn, required String buildTimeDsn}) {
  if (isWeb && (webConfiguredDsn?.isNotEmpty ?? false)) {
    return webConfiguredDsn!;
  }
  return buildTimeDsn;
}

/// Whether crash reporting should actually run: the app needs somewhere to
/// send to (a resolved DSN) *and* the user has to have opted in themselves.
@visibleForTesting
bool computeCrashReportingEnabled({required String dsn, required ClientSettingsModel clientSettings}) =>
    dsn.isNotEmpty && clientSettings.enableCrashReporting;

bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);
}

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.sharedPreferences,
    required this.applicationInfo,
    required this.applicationDirectory,
    required this.argumentsModel,
    required this.crashProvider,
    required this.crashReportingEnabled,
    required this.sentryDsn,
  });

  final SharedPreferences sharedPreferences;
  final ApplicationInfo applicationInfo;
  final Directory applicationDirectory;
  final ArgumentsModel argumentsModel;
  final CrashLogNotifier crashProvider;

  /// Whether the user has opted in to crash reporting, read directly from
  /// disk since this is decided before the Riverpod tree exists.
  final bool crashReportingEnabled;

  /// The DSN to hand to `SentryFlutter.init` when [crashReportingEnabled] is
  /// true — see [resolvedSentryDsn].
  final String sentryDsn;
}

Future<AppBootstrapResult> bootstrapApplication(List<String> args) async {
  final crashProvider = CrashLogNotifier();

  if (kIsWeb) {
    final configString = await rootBundle.loadString('config/config.json');
    DriftfinConfig.fromJson(jsonDecode(configString) as Map<String, dynamic>);
  }

  await SvgUtils.preCacheSVGs();

  final leanBackEnabled = await resolveLeanBackEnabled();

  var windowArguments = '';
  if (isDesktopPlatform) {
    windowArguments = await _resolveWindowArguments();
  }

  final sharedPreferences = await SharedPreferences.getInstance();
  final packageInfo = await PackageInfo.fromPlatform();

  var applicationDirectory = Directory('');
  if (!kIsWeb) {
    applicationDirectory = await getApplicationDocumentsDirectory();
  }

  final applicationInfo = ApplicationInfo(
    name: packageInfo.appName.capitalize(),
    version: packageInfo.version,
    buildNumber: packageInfo.buildNumber,
    platform: defaultTargetPlatform,
  );

  final argumentsModel = ArgumentsModel.fromArguments(
    args,
    windowArguments,
    leanBackEnabled,
  );

  final effectiveSentryDsn = resolvedSentryDsn;
  final crashReportingEnabled = computeCrashReportingEnabled(
    dsn: effectiveSentryDsn,
    clientSettings: SharedHelper(sharedPreferences: sharedPreferences).clientSettings,
  );

  return AppBootstrapResult(
    sharedPreferences: sharedPreferences,
    applicationInfo: applicationInfo,
    applicationDirectory: applicationDirectory,
    argumentsModel: argumentsModel,
    crashProvider: crashProvider,
    crashReportingEnabled: crashReportingEnabled,
    sentryDsn: effectiveSentryDsn,
  );
}

Future<bool> resolveLeanBackEnabled() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return false;
  }

  try {
    return await NativeVideoActivity().isLeanBackEnabled();
  } catch (e) {
    print('Leanback detection failed (non-TV Android device): $e');
    return false;
  }
}

Future<String> _resolveWindowArguments() async {
  try {
    final windowController = await WindowController.fromCurrentEngine();
    return windowController.arguments;
  } catch (e) {
    print('Window arguments resolution failed: $e');
    return '';
  }
}
