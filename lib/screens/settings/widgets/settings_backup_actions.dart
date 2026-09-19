import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
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
      await FilePicker.platform.saveFile(fileName: _fileName(), bytes: bytes);
      return;
    }

    // `bytes` is *required* on Android & iOS — saveFile throws an ArgumentError
    // without it — and there the picker writes the file itself. On desktop
    // saveFile only returns the chosen path, so we persist the bytes ourselves
    // below. Passing bytes on every platform keeps one code path that works on
    // mobile, desktop and web alike.
    final path = await FilePicker.platform.saveFile(
      dialogTitle: context.localized.settingsExportSettingsTitle,
      fileName: _fileName(),
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
    if (path == null) return;
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      await File(path).writeAsBytes(bytes);
    }
    if (context.mounted) DriftfinSnack.show(context.localized.saved, context: context);
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final bytes = result?.files.singleOrNull?.bytes;
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
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.localized.cancel),
                  ),
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
