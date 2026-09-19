import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driftfin/providers/radarr_provider.dart';
import 'package:driftfin/providers/sonarr_provider.dart';
import 'package:driftfin/providers/trakt_provider.dart';
import 'package:driftfin/screens/settings/settings_list_tile.dart';
import 'package:driftfin/screens/settings/widgets/trakt_connect_dialog.dart';
import 'package:driftfin/screens/shared/driftfin_notification_overlay.dart';
import 'package:driftfin/util/localization_helper.dart';

/// Sonarr / Radarr / Trakt settings tiles. When an integration is configured by
/// the optional Driftfin server plugin it is shown as read-only ("Managed by
/// server") — the toggle and fields are disabled and edits are no-ops.
List<Widget> buildIntegrationSettings(BuildContext context, WidgetRef ref) {
  final sonarrManaged = ref.watch(sonarrProvider.select((value) => value.managed));
  final radarrManaged = ref.watch(radarrProvider.select((value) => value.managed));
  final traktManaged = ref.watch(traktProvider.select((value) => value.managed));

  return [
    SettingsListTile(
      label: Text(context.localized.sonarrIntegrationTitle),
      subLabel: Text(sonarrManaged ? context.localized.managedByServerPlugin : context.localized.sonarrIntegrationDesc),
      onTap:
          sonarrManaged ? null : () => ref.read(sonarrProvider.notifier).setEnabled(!ref.read(sonarrProvider).enabled),
      trailing: Switch(
        value: ref.watch(sonarrProvider.select((value) => value.enabled)),
        onChanged: sonarrManaged ? null : (value) => ref.read(sonarrProvider.notifier).setEnabled(value),
      ),
    ),
    if (ref.watch(sonarrProvider.select((value) => value.enabled))) ...[
      SettingsListTile(
        label: Text(context.localized.sonarrUrlTitle),
        subLabel: Text(ref.watch(sonarrProvider.select((value) => value.baseUrl)).isEmpty
            ? '—'
            : ref.watch(sonarrProvider.select((value) => value.baseUrl))),
        onTap: sonarrManaged
            ? null
            : () async {
                final value = await promptText(context,
                    title: context.localized.sonarrUrlTitle, initial: ref.read(sonarrProvider).baseUrl);
                if (value != null) ref.read(sonarrProvider.notifier).setBaseUrl(value);
              },
        trailing: const Icon(Icons.link),
      ),
      SettingsListTile(
        label: Text(context.localized.sonarrApiKeyTitle),
        subLabel: Text(ref.watch(sonarrProvider.select((value) => value.apiKey)).isEmpty ? '—' : '••••••••'),
        onTap: sonarrManaged
            ? null
            : () async {
                final value = await promptText(context,
                    title: context.localized.sonarrApiKeyTitle,
                    initial: ref.read(sonarrProvider).apiKey,
                    obscure: true);
                if (value != null) ref.read(sonarrProvider.notifier).setApiKey(value);
              },
        trailing: const Icon(Icons.key),
      ),
    ],
    SettingsListTile(
      label: Text(context.localized.radarrIntegrationTitle),
      subLabel: Text(radarrManaged ? context.localized.managedByServerPlugin : context.localized.radarrIntegrationDesc),
      onTap:
          radarrManaged ? null : () => ref.read(radarrProvider.notifier).setEnabled(!ref.read(radarrProvider).enabled),
      trailing: Switch(
        value: ref.watch(radarrProvider.select((value) => value.enabled)),
        onChanged: radarrManaged ? null : (value) => ref.read(radarrProvider.notifier).setEnabled(value),
      ),
    ),
    if (ref.watch(radarrProvider.select((value) => value.enabled))) ...[
      SettingsListTile(
        label: Text(context.localized.radarrUrlTitle),
        subLabel: Text(ref.watch(radarrProvider.select((value) => value.baseUrl)).isEmpty
            ? '—'
            : ref.watch(radarrProvider.select((value) => value.baseUrl))),
        onTap: radarrManaged
            ? null
            : () async {
                final value = await promptText(context,
                    title: context.localized.radarrUrlTitle, initial: ref.read(radarrProvider).baseUrl);
                if (value != null) ref.read(radarrProvider.notifier).setBaseUrl(value);
              },
        trailing: const Icon(Icons.link),
      ),
      SettingsListTile(
        label: Text(context.localized.radarrApiKeyTitle),
        subLabel: Text(ref.watch(radarrProvider.select((value) => value.apiKey)).isEmpty ? '—' : '••••••••'),
        onTap: radarrManaged
            ? null
            : () async {
                final value = await promptText(context,
                    title: context.localized.radarrApiKeyTitle,
                    initial: ref.read(radarrProvider).apiKey,
                    obscure: true);
                if (value != null) ref.read(radarrProvider.notifier).setApiKey(value);
              },
        trailing: const Icon(Icons.key),
      ),
    ],
    SettingsListTile(
      label: Text(context.localized.traktTitle),
      subLabel: Text(traktManaged ? context.localized.managedByServerPlugin : context.localized.traktDesc),
      onTap: traktManaged ? null : () => ref.read(traktProvider.notifier).setEnabled(!ref.read(traktProvider).enabled),
      trailing: Switch(
        value: ref.watch(traktProvider.select((value) => value.enabled)),
        onChanged: traktManaged ? null : (value) => ref.read(traktProvider.notifier).setEnabled(value),
      ),
    ),
    if (ref.watch(traktProvider.select((value) => value.enabled))) ...[
      SettingsListTile(
        label: Text(context.localized.traktClientId),
        subLabel: Text(ref.watch(traktProvider.select((value) => value.clientId)).isEmpty ? '—' : '••••••••'),
        onTap: traktManaged
            ? null
            : () async {
                final value = await promptText(context,
                    title: context.localized.traktClientId, initial: ref.read(traktProvider).clientId);
                if (value != null) ref.read(traktProvider.notifier).setClientId(value);
              },
        trailing: const Icon(Icons.badge_outlined),
      ),
      SettingsListTile(
        label: Text(context.localized.traktClientSecret),
        subLabel: Text(ref.watch(traktProvider.select((value) => value.clientSecret)).isEmpty ? '—' : '••••••••'),
        onTap: traktManaged
            ? null
            : () async {
                final value = await promptText(context,
                    title: context.localized.traktClientSecret,
                    initial: ref.read(traktProvider).clientSecret,
                    obscure: true);
                if (value != null) ref.read(traktProvider.notifier).setClientSecret(value);
              },
        trailing: const Icon(Icons.key),
      ),
      Builder(builder: (context) {
        final authed = ref.watch(traktProvider.select((value) => value.isAuthenticated));
        final hasCreds = ref.watch(traktProvider.select((value) => value.hasCredentials));
        return SettingsListTile(
          label: Text(authed ? context.localized.traktDisconnect : context.localized.traktConnect),
          subLabel: Text(authed ? context.localized.traktConnected : context.localized.traktNotConnected),
          onTap: !hasCreds
              ? null
              : () async {
                  if (authed) {
                    ref.read(traktProvider.notifier).logout();
                    return;
                  }
                  final connected = await showTraktConnectDialog(context);
                  if (context.mounted) {
                    DriftfinSnack.show(connected == true
                        ? context.localized.traktConnectedSuccess
                        : context.localized.traktConnectFailed);
                  }
                },
          trailing: Icon(authed ? Icons.link_off : Icons.link),
        );
      }),
    ],
  ];
}

/// Small text-entry dialog used by the settings tiles.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String initial,
  bool obscure = false,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        obscureText: obscure,
        autofocus: true,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.localized.cancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: Text(context.localized.save)),
      ],
    ),
  );
}
