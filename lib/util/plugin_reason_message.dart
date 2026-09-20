import 'package:flutter/material.dart';
import 'package:driftfin/util/localization_helper.dart';

String pluginReasonMessage(BuildContext context, String? reason) => switch (reason) {
  'no_plugin' => context.localized.settingsIntegrationsPluginNotInstalled,
  'legacy_plugin' => context.localized.pluginLegacy,
  'checking' => context.localized.pluginChecking,
  'incompatible_protocol' => context.localized.pluginIncompatible,
  'not_configured' || 'invalid_configuration' => context.localized.pluginNotConfigured,
  'user_not_linked' => context.localized.pluginUserNotLinked,
  'server_not_linked' => context.localized.pluginServerNotLinked,
  'permission_denied' => context.localized.pluginDenied,
  'expired_login' => context.localized.pluginExpired,
  'invalid_credentials' => context.localized.pluginInvalidCredentials,
  'content_restricted' => context.localized.pluginContentRestricted,
  'unsupported_version' => context.localized.pluginUnsupportedVersion,
  'rate_limited' => context.localized.pluginRateLimited,
  null => context.localized.pluginManaged,
  _ => context.localized.pluginUnreachable,
};
