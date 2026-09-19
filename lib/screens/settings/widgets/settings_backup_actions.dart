import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/providers/config_sync_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/routes/auto_router.gr.dart';
import 'package:driftfin/screens/settings/settings_list_tile.dart';
import 'package:driftfin/screens/shared/driftfin_notification_overlay.dart';
import 'package:driftfin/util/localization_helper.dart';

/// Export/Import/Reset for the local settings (issue #50 Phase 5), built on
/// the same serializable [UserSettings] payload the sync feature already
/// uses. Reset graduates the previous kDebugMode-only clear (formerly on the
/// dissolved "Client" settings page) into a guarded, always-available action.
class SettingsBackupActions extends ConsumerWidget {
  const SettingsBackupActions({super.key});

  String _fileName() {
    final now = DateTime.now();
    final stamp = now.toIso8601String().split('T').first;
    return 'driftfin-settings-$stamp.json';
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(configSyncProvider).buildCurrentSettings();
    final jsonString = const JsonEncoder.withIndent('  ').convert(settings.toJson());
    final bytes = Uint8List.fromList(utf8.encode(jsonString));

    if (kIsWeb) {
      await FilePicker.saveFile(fileName: _fileName(), bytes: bytes);
      return;
    }

    // The picker writes the supplied bytes on every platform.
    final path = await FilePicker.saveFile(
      dialogTitle: context.localized.settingsExportSettingsTitle,
      fileName: _fileName(),
      mimeType: 'application/json',
      bytes: bytes,
    );
    if (path == null) return;
    if (context.mounted) DriftfinSnack.show(context.localized.saved, context: context);
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['json']);
    final bytes = await result?.readAsBytes();
    if (bytes == null) return;

    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException('not a JSON object');
      final settings = UserSettings.fromJson(decoded);
      ref.read(configSyncProvider).applySettings(settings);
      if (context.mounted) DriftfinSnack.show(context.localized.saved, context: context);
    } catch (_) {
      if (context.mounted) DriftfinSnack.show(context.localized.somethingWentWrong, context: context);
    }
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.localized.clearAllSettingsQuestion, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(context.localized.unableToReverseAction),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.localized.cancel)),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await ref.read(sharedPreferencesProvider).clear();
                      if (context.mounted) context.router.push(LoginRoute());
                    },
                    child: Text(context.localized.clear),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SettingsListTile(
          label: Text(context.localized.settingsExportSettingsTitle),
          subLabel: Text(context.localized.settingsExportSettingsDesc),
          onTap: () => _export(context, ref),
          trailing: const Icon(Icons.upload_file_outlined),
        ),
        SettingsListTile(
          label: Text(context.localized.settingsImportSettingsTitle),
          subLabel: Text(context.localized.settingsImportSettingsDesc),
          onTap: () => _import(context, ref),
          trailing: const Icon(Icons.download_outlined),
        ),
        SettingsListTile(
          label: Text(context.localized.clearAllSettings),
          contentColor: Theme.of(context).colorScheme.error,
          onTap: () => _confirmReset(context, ref),
        ),
      ],
    );
  }
}
