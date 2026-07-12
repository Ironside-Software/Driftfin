import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:driftfin/bootstrap/app_bootstrap.dart';
import 'package:driftfin/bootstrap/platform/platform_app_wrapper.dart';
import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/localization_delegates.dart';
import 'package:driftfin/providers/arguments_provider.dart';
import 'package:driftfin/providers/config_sync_provider.dart';
import 'package:driftfin/providers/crash_log_provider.dart';
import 'package:driftfin/providers/settings/client_settings_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/sync_provider.dart';
import 'package:driftfin/routes/auto_router.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/application_info.dart';
import 'package:driftfin/util/deep_link_helper.dart';
import 'package:driftfin/util/localization_helper.dart';
import 'package:driftfin/util/themes_data.dart';
import 'package:driftfin/widgets/media_query_scaler.dart';
import 'package:driftfin/widgets/pip_lifecycle_controller.dart';
import 'package:driftfin/widgets/shared/adaptive_color.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = await bootstrapApplication(args);

  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) => bootstrap.sharedPreferences),
      applicationInfoProvider.overrideWith((ref) => bootstrap.applicationInfo),
      crashLogProvider.overrideWith((ref) => bootstrap.crashProvider),
      argumentsStateProvider.overrideWith((ref) => bootstrap.argumentsModel),
      syncProvider.overrideWith((ref) => SyncNotifier(ref, bootstrap.applicationDirectory)),
    ],
    child: AdaptiveLayoutBuilder(
      child: (context) => const Main(),
    ),
  );

  if (bootstrap.crashReportingEnabled) {
    await SentryFlutter.init(
      (options) {
        options.dsn = bootstrap.sentryDsn;
        options.sendDefaultPii = false;
        options.tracesSampleRate = 0;
      },
      appRunner: () => runApp(app),
    );
  } else {
    runApp(app);
  }
}

class Main extends ConsumerWidget {
  const Main({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlatformAppWrapper(
      builder: (context, autoRouter) {
        return _FladderApp(
          autoRouter: autoRouter,
        );
      },
    );
  }
}

class _FladderApp extends ConsumerWidget {
  const _FladderApp({
    required this.autoRouter,
  });

  final AutoRouter autoRouter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the settings-sync service alive so it applies server config on login
    // and pushes local changes back while enabled.
    ref.watch(configSyncProvider);
    final themeMode = ref.watch(clientSettingsProvider.select((value) => value.themeMode));
    final amoledBlack = ref.watch(clientSettingsProvider.select((value) => value.amoledBlack));
    final mouseDrag = ref.watch(clientSettingsProvider.select((value) => value.mouseDragSupport));
    final reduceAnimations = ref.watch(clientSettingsProvider.select((value) => value.reduceAnimations));
    final language = ref.watch(clientSettingsProvider
        .select((value) => value.selectedLocale ?? WidgetsBinding.instance.platformDispatcher.locale));
    final scrollBehaviour = const MaterialScrollBehavior();
    final amoledOverwrite = amoledBlack ? Colors.black : null;

    return AdaptiveColor(
      child: (darkTheme, lightTheme) => ThemesData(
        light: lightTheme,
        dark: darkTheme,
        child: MaterialApp.router(
          theme: lightTheme,
          scrollBehavior: scrollBehaviour.copyWith(
            dragDevices: {
              ...scrollBehaviour.dragDevices,
              mouseDrag ? PointerDeviceKind.mouse : null,
            }.nonNulls.toSet(),
          ),
          localizationsDelegates: FladderLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: language,
          localeResolutionCallback: (locale, supportedLocales) {
            const fallback = Locale('en');
            if (locale == null) return fallback;
            if (supportedLocales.contains(locale)) {
              return locale;
            }
            final matchByLanguage = supportedLocales.firstWhere(
              (l) => l.languageCode == locale.languageCode,
              orElse: () => fallback,
            );

            return matchByLanguage;
          },
          builder: (context, child) => MediaQuery(
            // "Reduce animations" for low-end devices (issue #50) — most
            // Flutter widgets (AnimatedContainer, page transitions,
            // AnimatedSwitcher, ...) already check MediaQuery.disableAnimations
            // and skip/short-circuit their animation when it's set, so this
            // single override reaches them without touching each widget.
            // Combined with the OS's own reduce-motion setting, not
            // overriding it.
            data: MediaQuery.of(context).copyWith(
              disableAnimations: MediaQuery.of(context).disableAnimations || reduceAnimations,
            ),
            child: MediaQueryScaler(
              child: LocalizationContextWrapper(
                child: PipLifecycleController(child: child ?? Container()),
                currentLocale: language,
              ),
              enable: ref.read(argumentsStateProvider).leanBackMode,
            ),
          ),
          debugShowCheckedModeBanner: false,
          darkTheme: darkTheme.copyWith(
            scaffoldBackgroundColor: amoledOverwrite,
            cardColor: amoledOverwrite,
            canvasColor: amoledOverwrite,
            colorScheme: darkTheme.colorScheme.copyWith(
              surface: amoledOverwrite,
              surfaceContainerHighest: amoledOverwrite,
              surfaceContainerLow: amoledOverwrite,
            ),
          ),
          themeMode: themeMode,
          routerConfig: autoRouter.config(
            deepLinkBuilder: (deepLink) => deepLinkBuilder(deepLink.uri),
          ),
        ),
      ),
    );
  }
}
