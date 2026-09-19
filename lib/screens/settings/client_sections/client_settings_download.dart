import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:driftfin/models/settings/settings_entry.dart';
import 'package:driftfin/providers/settings/client_settings_provider.dart';
import 'package:driftfin/providers/sync/background_download_provider.dart';
import 'package:driftfin/providers/sync_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/screens/settings/settings_list_tile.dart';
import 'package:driftfin/screens/settings/widgets/settings_label_divider.dart';
import 'package:driftfin/screens/settings/widgets/settings_list_group.dart';
import 'package:driftfin/screens/settings/widgets/transcode_music_settings_popup.dart';
import 'package:driftfin/screens/settings/widgets/transcode_settings_popup.dart';
import 'package:driftfin/screens/shared/default_alert_dialog.dart';
import 'package:driftfin/screens/shared/input_fields.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/localization_helper.dart';
import 'package:driftfin/util/size_formatting.dart';

/// Renders the current Smart Downloads budget (bytes) as whole MB for the
/// input field; empty when unset (no budget/unlimited).
String smartDownloadBudgetFieldText(int? budgetBytes) =>
    budgetBytes != null ? (budgetBytes ~/ (1024 * 1024)).toString() : "";

/// Converts the user-entered MB value back to bytes for storage; null (no
/// budget) when the field is empty or cleared.
int? smartDownloadBudgetBytesFromMb(int? megaBytes) => megaBytes != null ? megaBytes * 1024 * 1024 : null;

List<Widget> buildClientSettingsDownload(BuildContext context, WidgetRef ref, Function setState) {
  final clientSettings = ref.watch(clientSettingsProvider);
  final currentFolder = ref.watch(syncProvider.notifier).savePath;
  final canSync = ref.watch(userProvider.select((value) => value?.canDownload ?? false));

  return [
    if (canSync && !kIsWeb) ...[
      ...settingsListGroup(
        context,
        SettingsLabelDivider(label: context.localized.downloadsTitle),
        [
          if (AdaptiveLayout.of(context).isDesktop) ...[
            SettingsListTile(
              label: Text(context.localized.downloadsPath),
              subLabel: Text(currentFolder ?? "-"),
              onTap: currentFolder != null
                  ? () async => await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(context.localized.pathEditTitle),
                          content: Text(context.localized.pathEditDesc),
                          actions: [
                            ElevatedButton(
                              onPressed: () async {
                                String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
                                    dialogTitle: context.localized.pathEditSelect, initialDirectory: currentFolder);
                                if (selectedDirectory != null) {
                                  await ref.read(clientSettingsProvider.notifier).setSyncPath(selectedDirectory);
                                }
                                Navigator.of(context).pop();
                              },
                              child: Text(context.localized.change),
                            )
                          ],
                        ),
                      )
                  : () async {
                      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
                          dialogTitle: context.localized.pathEditSelect, initialDirectory: currentFolder);
                      if (selectedDirectory != null) {
                        ref.read(clientSettingsProvider.notifier).setSyncPath(selectedDirectory);
                      }
                    },
              trailing: currentFolder?.isNotEmpty == true
                  ? IconButton(
                      color: Theme.of(context).colorScheme.error,
                      onPressed: () async => await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(context.localized.pathClearTitle),
                          content: Text(context.localized.pathEditDesc),
                          actions: [
                            ElevatedButton(
                              onPressed: () {
                                ref.read(clientSettingsProvider.notifier).setSyncPath(null);
                                Navigator.of(context).pop();
                              },
                              child: Text(context.localized.clear),
                            )
                          ],
                        ),
                      ),
                      icon: const Icon(IconsaxPlusLinear.folder_minus),
                    )
                  : null,
            ),
          ],
          FutureBuilder(
            future: ref.watch(syncProvider.notifier).directorySize,
            builder: (context, snapshot) {
              final data = snapshot.data ?? 0;
              return SettingsListTile(
                label: Text(context.localized.downloadsSyncedData),
                subLabel: Text(data.byteFormat ?? ""),
                onTap: () {
                  showDefaultAlertDialog(
                    context,
                    context.localized.downloadsClearTitle,
                    context.localized.downloadsClearDesc,
                    (context) async {
                      await ref.read(syncProvider.notifier).removeAllSyncedData();
                      setState(() {});
                      Navigator.of(context).pop();
                    },
                    context.localized.clear,
                    (context) => Navigator.of(context).pop(),
                    context.localized.cancel,
                  );
                },
                trailing: FilledButton(
                  onPressed: () {
                    showDefaultAlertDialog(
                      context,
                      context.localized.downloadsClearTitle,
                      context.localized.downloadsClearDesc,
                      (context) async {
                        await ref.read(syncProvider.notifier).removeAllSyncedData();
                        setState(() {});
                        Navigator.of(context).pop();
                      },
                      context.localized.clear,
                      (context) => Navigator.of(context).pop(),
                      context.localized.cancel,
                    );
                  },
                  child: Text(context.localized.clear),
                ),
              );
            },
          ),
          SettingsListTile(
            label: Text(context.localized.clientSettingsRequireWifiTitle),
            subLabel: Text(context.localized.clientSettingsRequireWifiDesc),
            onTap: () => ref.read(clientSettingsProvider.notifier).setRequireWifi(!clientSettings.requireWifi),
            trailing: Switch(
              value: clientSettings.requireWifi,
              onChanged: (value) => ref.read(clientSettingsProvider.notifier).setRequireWifi(value),
            ),
          ),
          SettingsListTile(
            id: SettingId.downloadsVideoQuality,
            label: Text(context.localized.downloadsVideoQualityTitle),
            subLabel: Text(clientSettings.transcodeDownloadModel.label(context)),
            onTap: () => showTranscodeSettingsPopup(
              context: context,
              current: clientSettings.transcodeDownloadModel,
              onChanged: (value) {
                ref.read(clientSettingsProvider.notifier).update(
                      (current) => current.copyWith(transcodeDownloadModel: value),
                    );
              },
            ),
          ),
          SettingsListTile(
            id: SettingId.downloadsMusicQuality,
            label: Text(context.localized.downloadsMusicQualityTitle),
            subLabel: Text(clientSettings.transcodeMusicDownloadModel.label(context)),
            onTap: () => showTranscodeMusicSettingsPopup(
              context: context,
              current: clientSettings.transcodeMusicDownloadModel,
              onChanged: (value) {
                ref.read(clientSettingsProvider.notifier).update(
                      (current) => current.copyWith(transcodeMusicDownloadModel: value),
                    );
              },
            ),
          ),
          SettingsListTile(
            label: Text(context.localized.maxConcurrentDownloadsTitle),
            subLabel: Text(context.localized.maxConcurrentDownloadsDesc),
            trailing: SizedBox(
              width: 150,
              child: IntInputField(
                controller: TextEditingController(text: clientSettings.maxConcurrentDownloads.toString()),
                onSubmitted: (value) {
                  if (value != null) {
                    ref.read(clientSettingsProvider.notifier).update(
                          (current) => current.copyWith(
                            maxConcurrentDownloads: value,
                          ),
                        );

                    ref.read(backgroundDownloaderProvider.notifier).setMaxConcurrent(value);
                  }
                },
              ),
            ),
          ),
          SettingsListTile(
            label: Text(context.localized.smartDownloadBudgetTitle),
            subLabel: Text(context.localized.smartDownloadBudgetDesc),
            trailing: SizedBox(
              width: 150,
              child: IntInputField(
                controller: TextEditingController(
                  text: smartDownloadBudgetFieldText(clientSettings.smartDownloadBudgetBytes),
                ),
                onSubmitted: (value) {
                  ref
                      .read(clientSettingsProvider.notifier)
                      .setSmartDownloadBudget(smartDownloadBudgetBytesFromMb(value));
                },
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
    ],
  ];
}
