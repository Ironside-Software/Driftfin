import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driftfin/models/seerr_credentials_model.dart';
import 'package:driftfin/models/settings/settings_entry.dart';
import 'package:driftfin/providers/seerr_user_provider.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/providers/update_notifications_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/screens/settings/client_sections/client_settings_integrations.dart';
import 'package:driftfin/screens/settings/settings_list_tile.dart';
import 'package:driftfin/screens/settings/settings_scaffold.dart';
import 'package:driftfin/screens/settings/widgets/seerr_connection_dialog.dart';
import 'package:driftfin/screens/settings/widgets/settings_label_divider.dart';
import 'package:driftfin/screens/settings/widgets/settings_list_group.dart';
import 'package:driftfin/screens/shared/driftfin_notification_overlay.dart';
import 'package:driftfin/seerr/seerr_models.dart';
import 'package:driftfin/services/notification_service.dart';
import 'package:driftfin/util/localization_helper.dart';

/// One home for all four client integrations (issue #50 Phase 2) — Jellyseerr
/// used to live on the dissolved "Profile" page, Sonarr/Radarr/Trakt in the
/// dissolved "Client" page's Advanced section.
@RoutePage()
class IntegrationsSettingsPage extends ConsumerStatefulWidget {
  const IntegrationsSettingsPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _IntegrationsSettingsPageState();
}

class _IntegrationsSettingsPageState extends ConsumerState<IntegrationsSettingsPage> {
  bool _refreshing = false;

  Future<void> _refreshServerConfig() async {
    setState(() => _refreshing = true);
    // The optional Driftfin server plugin's config (which of these are
    // "Saved on the server") is otherwise only re-fetched on login or the
    // dashboard's 120s poll — this lets a user pull it on demand right after
    // an admin changes it, and reports the *specific* reason it failed
    // (not installed / server error / unreachable) instead of a generic
    // "no response".
    final result = await ref.read(serverIntegrationConfigProvider.notifier).loadWithDiagnostics();
    if (mounted) {
      setState(() => _refreshing = false);
      DriftfinSnack.show(_statusMessage(context, result.status, result.detail), context: context);
    }
  }

  /// Maps a diagnostic status to a specific, user-facing message so a 404
  /// (plugin not installed), a 500/4xx (server error, with the code), and a
  /// timeout/network failure (unreachable) each read differently.
  String _statusMessage(BuildContext context, ServerIntegrationConfigStatus status, String? detail) {
    final l10n = context.localized;
    switch (status) {
      case ServerIntegrationConfigStatus.ok:
        return l10n.settingsIntegrationsRefreshSuccess;
      case ServerIntegrationConfigStatus.noPlugin:
        return l10n.settingsIntegrationsPluginNotInstalled;
      case ServerIntegrationConfigStatus.httpError:
        return detail == null
            ? l10n.settingsIntegrationsServerError
            : '${l10n.settingsIntegrationsServerError} ($detail)';
      case ServerIntegrationConfigStatus.requestFailed:
        return l10n.settingsIntegrationsUnreachable;
      case ServerIntegrationConfigStatus.invalidResponse:
      case ServerIntegrationConfigStatus.notLoggedIn:
        return l10n.somethingWentWrong;
    }
  }

  String _seerrStatusLabel(
    BuildContext context,
    SeerrCredentialsModel? credentials,
    SeerrUserModel? seerrUser,
  ) {
    if (credentials == null || credentials.serverUrl.isEmpty) return context.localized.seerrNotConfigured;

    if (credentials.sessionCookie.isNotEmpty || credentials.apiKey.isNotEmpty) {
      if (seerrUser == null) {
        return context.localized.seerrLoadingUser;
      }
      final displayName =
          seerrUser.displayName ?? seerrUser.username ?? seerrUser.email ?? context.localized.seerrUnknownUser;
      return context.localized.loggedInAs(displayName);
    }

    return context.localized.none;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final seerrUser = ref.watch(seerrUserProvider);

    return SettingsScaffold(
      label: context.localized.settingsIntegrationsTitle,
      items: [
        SettingsListTile(
          label: Text(context.localized.refresh),
          subLabel: Text(context.localized.settingsIntegrationsDesc),
          onTap: _refreshing ? null : _refreshServerConfig,
          trailing: _refreshing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
        ),
        const SizedBox(height: 12),
        ...settingsListGroup(
          context,
          const SettingsLabelDivider(label: "Seerr"),
          [
            SettingsListTile(
              id: SettingId.seerrIntegration,
              label: Text(context.localized.seerr),
              subLabel: Text(_seerrStatusLabel(context, user?.seerrCredentials, seerrUser)),
              onTap: () => showSeerrConnectionDialog(context),
            ),
            if (seerrUser?.canManageRequests ?? false)
              SettingsListTileCheckbox(
                id: SettingId.seerrRequestNotifications,
                label: Text(context.localized.seerrRequestNotifications),
                value: user?.seerrRequestsEnabled ?? false,
                onChanged: (val) async {
                  final current = ref.read(userProvider);
                  if (current == null || val == null) return;

                  ref.read(userProvider.notifier).userState = current.copyWith(seerrRequestsEnabled: val);

                  if (val) {
                    await NotificationService.requestPermission();
                    await ref.read(updateNotificationsProvider).registerBackgroundTask();
                  } else {
                    await ref.read(updateNotificationsProvider).conditionallyUnregisterBackgroundTask();
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...buildIntegrationSettings(context, ref),
      ],
    );
  }
}
