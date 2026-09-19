import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.enums.swagger.dart' as enums;
import 'package:driftfin/models/settings/settings_entry.dart';
import 'package:driftfin/providers/config_sync_provider.dart';
import 'package:driftfin/providers/incognito_mode_provider.dart';
import 'package:driftfin/providers/connectivity_provider.dart';
import 'package:driftfin/providers/cultures_provider.dart';
import 'package:driftfin/providers/settings/client_settings_provider.dart';
import 'package:driftfin/providers/settings/home_settings_provider.dart';
import 'package:driftfin/providers/update_notifications_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/screens/settings/client_sections/client_settings_shortcuts.dart';
import 'package:driftfin/screens/settings/settings_list_tile.dart';
import 'package:driftfin/screens/settings/settings_scaffold.dart';
import 'package:driftfin/screens/settings/widgets/crash_reporting_tile.dart';
import 'package:driftfin/screens/settings/widgets/password_reset_dialog.dart';
import 'package:driftfin/screens/settings/widgets/settings_backup_actions.dart';
import 'package:driftfin/screens/settings/widgets/settings_label_divider.dart';
import 'package:driftfin/screens/settings/widgets/settings_list_group.dart';
import 'package:driftfin/screens/settings/widgets/settings_message_box.dart';
import 'package:driftfin/screens/shared/authenticate_button_options.dart';
import 'package:driftfin/screens/shared/input_fields.dart';
import 'package:driftfin/services/battery_optimization.dart';
import 'package:driftfin/services/notification_service.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/jellyfin_extension.dart';
import 'package:driftfin/util/localization_helper.dart';
import 'package:driftfin/util/option_dialogue.dart';
import 'package:driftfin/util/simple_duration_picker.dart';
import 'package:driftfin/widgets/shared/item_actions.dart';

/// Account (server) + Device (local) + Sync & Backup, unified (issue #50
/// Phase 2) — the successor to the dissolved "Profile" page (path `security`
/// redirects here), absorbing device-local bits that used to live on the
/// dissolved "Client" page (Lockscreen, Shortcuts, Controls, Advanced's
/// sync/layout/IME settings).
@RoutePage()
class AccountDeviceSettingsPage extends ConsumerStatefulWidget {
  const AccountDeviceSettingsPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _AccountDeviceSettingsPageState();
}

class _AccountDeviceSettingsPageState extends ConsumerState<AccountDeviceSettingsPage> with WidgetsBindingObserver {
  bool? enabledBatteryOptimization;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => checkBatteryOptimization());
  }

  Future<bool> checkBatteryOptimization() async {
    if (!kIsWeb && Platform.isAndroid) {
      final optimizing = !(await BatteryOptimization.isIgnoringBatteryOptimizations());
      setState(() {
        enabledBatteryOptimization = optimizing;
      });
      return optimizing;
    }
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      checkBatteryOptimization();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final cultures = ref.watch(culturesProvider);
    final clientSettings = ref.watch(clientSettingsProvider);
    final lastUpdateAt = ref.watch(notificationsProvider).updatedAt;

    final allowedSubModes = {
      enums.SubtitlePlaybackMode.$default,
      enums.SubtitlePlaybackMode.smart,
      enums.SubtitlePlaybackMode.onlyforced,
      enums.SubtitlePlaybackMode.always,
      enums.SubtitlePlaybackMode.none,
    };

    return SettingsScaffold(
      label: context.localized.settingsAccountDeviceTitle,
      items: [
        // ---- Account ----
        ...settingsListGroup(
          context,
          SettingsLabelDivider(label: context.localized.settingsAccountSectionTitle),
          [
            SettingsListTileCheckbox(
              label: Text(context.localized.incognitoModeLocal),
              value: user?.incognitoMode ?? false,
              subLabel: Text(context.localized.incognitoModeDesc),
              onChanged: (value) => ref.read(userProvider.notifier).toggleIncognitoMode(),
            ),
            SettingsListTile(
              label: Text(context.localized.password),
              onTap: () => openPasswordResetDialog(context),
            ),
            Builder(builder: (context) {
              final anyLanguageLabel = context.localized.anyLanguage;
              final subtitleLanguagePreference =
                  user?.userConfiguration?.subtitleLanguagePreference?.trim().toLowerCase();
              final hasSubtitleLanguagePreference = subtitleLanguagePreference?.isNotEmpty == true;

              final currentCulture = cultures.firstWhereOrNull(
                (e) => e.matchesLanguageCode(subtitleLanguagePreference),
              );

              return SettingsListTileEnum(
                id: SettingId.subtitleLanguage,
                label: Text(context.localized.settingsProfileSubtitleLanguage),
                current: !hasSubtitleLanguagePreference
                    ? anyLanguageLabel
                    : currentCulture?.displayName ?? context.localized.unknown,
                itemBuilder: (context) => [
                  ItemActionButton(
                    selected: !hasSubtitleLanguagePreference,
                    label: Text(anyLanguageLabel),
                    action: () {
                      ref.read(userProvider.notifier).updateSubtitleLanguagePreference(null);
                    },
                  ),
                  ...cultures.map(
                    (e) => ItemActionButton(
                      selected: e.matchesLanguageCode(subtitleLanguagePreference),
                      label: Text(e.displayName ?? e.name ?? context.localized.unknown),
                      action: () {
                        ref.read(userProvider.notifier).updateSubtitleLanguagePreference(
                            e.threeLetterISOLanguageName?.toLowerCase() ?? e.twoLetterISOLanguageName?.toLowerCase());
                      },
                    ),
                  ),
                ],
              );
            }),
            SettingsListTileEnum(
              id: SettingId.subtitleMode,
              label: Text(context.localized.settingsProfileSubtitleMode),
              current: user?.userConfiguration?.subtitleMode?.label(context) ?? context.localized.none,
              itemBuilder: (context) => allowedSubModes
                  .map(
                    (mode) => ItemActionButton(
                      selected: user?.userConfiguration?.subtitleMode == mode,
                      label: Text(mode.label(context)),
                      action: () {
                        ref.read(userProvider.notifier).updateSubtitleMode(mode);
                      },
                    ),
                  )
                  .toList(),
            ),
            SettingsListTileCheckbox(
              id: SettingId.includeHiddenItems,
              label: Text(context.localized.includeHiddenItems),
              subLabel: Text(context.localized.includeHiddenItemsDesc),
              value: user?.includeHiddenViews ?? false,
              onChanged: user?.updateNotificationsEnabled ?? false
                  ? (val) async {
                      final current = ref.read(userProvider);
                      if (current == null || val == null) return;
                      ref.read(userProvider.notifier).userState = current.copyWith(
                        includeHiddenViews: val,
                      );
                      await ref.read(updateNotificationsProvider).registerBackgroundTask();
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ---- Device ----
        ...settingsListGroup(
          context,
          SettingsLabelDivider(label: context.localized.settingsDeviceSectionTitle),
          [
            SettingsListTile(
              id: SettingId.appLockEnabled,
              label: Text(context.localized.settingSecurityApplockTitle),
              subLabel: Text(user?.authMethod.name(context) ?? ""),
              onTap: () => showAuthOptionsDialogue(
                context,
                user!,
                (newUser) {
                  ref.read(userProvider.notifier).updateUser(newUser);
                },
              ),
            ),
            SettingsListTileCheckbox(
              id: SettingId.openAuthAtLaunch,
              label: Text(context.localized.profileSettingsOpenAuthAtLaunch),
              value: user?.askForAuthOnLaunch ?? false,
              onChanged: user?.authMethod.shouldLock == true
                  ? (val) async {
                      if (user == null || val == null) return;
                      ref.read(userProvider.notifier).updateUser(
                            user.copyWith(askForAuthOnLaunch: val),
                          );
                    }
                  : null,
            ),
            SettingsListTile(
              id: SettingId.appLockTimeout,
              label: Text(context.localized.timeOut),
              subLabel: Text(timePickerString(context, clientSettings.timeOut)),
              onTap: () async {
                final timePicker = await showSimpleDurationPicker(
                  context: context,
                  initialValue: clientSettings.timeOut ?? const Duration(),
                );

                if (timePicker == null) return;

                ref.read(clientSettingsProvider.notifier).setTimeOut(timePicker != Duration.zero
                    ? Duration(minutes: timePicker.inMinutes, seconds: timePicker.inSeconds % 60)
                    : null);
              },
            ),
          ],
        ),
        if (AdaptiveLayout.inputDeviceOf(context) != InputDevice.touch) ...[
          const SizedBox(height: 12),
          ...buildClientSettingsShortCuts(context, ref),
        ],
        if (AdaptiveLayout.inputDeviceOf(context) == InputDevice.pointer) ...[
          const SizedBox(height: 12),
          ...settingsListGroup(context, SettingsLabelDivider(label: context.localized.controls), [
            SettingsListTile(
              id: SettingId.mouseDragSupport,
              label: Text(context.localized.mouseDragSupport),
              subLabel: Text(clientSettings.mouseDragSupport ? context.localized.enabled : context.localized.disabled),
              onTap: () => ref
                  .read(clientSettingsProvider.notifier)
                  .update((current) => current.copyWith(mouseDragSupport: !clientSettings.mouseDragSupport)),
              trailing: Switch(
                value: clientSettings.mouseDragSupport,
                onChanged: (value) => ref
                    .read(clientSettingsProvider.notifier)
                    .update((current) => current.copyWith(mouseDragSupport: value)),
              ),
            ),
          ]),
        ],
        const SizedBox(height: 12),
        ...settingsListGroup(
          context,
          SettingsLabelDivider(label: context.localized.advanced),
          [
            SettingsListTile(
              label: Text(context.localized.incognitoModeGlobal),
              subLabel: Text(context.localized.incognitoModeDesc),
              onTap: () => ref.read(incognitoModeProvider.notifier).state = !ref.read(incognitoModeProvider),
              trailing: Switch(
                value: ref.watch(incognitoModeProvider),
                onChanged: (value) => ref.read(incognitoModeProvider.notifier).state = value,
              ),
            ),
            if (defaultTargetPlatform == TargetPlatform.android)
              Column(
                children: [
                  SettingsListTileCheckbox(
                    label: Text(context.localized.leanBackModeTitle),
                    subLabel: Text(context.localized.leanBackModeDesc),
                    value: ref.watch(clientSettingsProvider.select((value) => value.forceLeanBackMode)),
                    onChanged: (value) =>
                        ref.read(clientSettingsProvider.notifier).setForceLeanBackMode(value ?? false),
                  ),
                  SettingsMessageBox(
                    context.localized.leanBackModeInfo,
                  ),
                ],
              ),
            if (AdaptiveLayout.inputDeviceOf(context) == InputDevice.dPad)
              SettingsListTile(
                id: SettingId.useSystemIME,
                label: Text(context.localized.clientSettingsUseSystemIMETitle),
                subLabel: Text(context.localized.clientSettingsUseSystemIMEDesc),
                onTap: () => ref
                    .read(clientSettingsProvider.notifier)
                    .useSystemIME(!ref.read(clientSettingsProvider.select((value) => value.useSystemIME))),
                trailing: Switch(
                  value: ref.watch(clientSettingsProvider.select((value) => value.useSystemIME)),
                  onChanged: (value) => ref.read(clientSettingsProvider.notifier).useSystemIME(value),
                ),
              ),
            SettingsListTile(
              id: SettingId.layoutSizes,
              label: Text(context.localized.settingsLayoutSizesTitle),
              subLabel: Text(context.localized.settingsLayoutSizesDesc),
              onTap: () async {
                final newItems = await openMultiSelectOptions<ViewSize>(
                  context,
                  label: context.localized.settingsLayoutSizesTitle,
                  items: ViewSize.values,
                  allowMultiSelection: true,
                  selected: ref.read(homeSettingsProvider.select((value) => value.layoutStates.toList())),
                  itemBuilder: (type, selected, tap) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected,
                    onChanged: (value) => tap(),
                    title: Text(type.label(context)),
                  ),
                );
                ref.read(homeSettingsProvider.notifier).setViewSize(newItems.toSet());
              },
              trailing: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                shadowColor: Colors.transparent,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    spacing: 4,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: ViewSize.values.map((e) {
                      final isCurrent = AdaptiveLayout.viewSizeOf(context) == e;
                      final isEnabled =
                          ref.watch(homeSettingsProvider.select((value) => value.layoutStates.contains(e)));
                      return Row(
                        spacing: 4,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e.label(context),
                              style: TextStyle(color: isEnabled ? null : Theme.of(context).disabledColor)),
                          if (isCurrent) const Icon(IconsaxPlusLinear.tick_circle, size: 16),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            SettingsListTile(
              id: SettingId.layoutModes,
              label: Text(context.localized.settingsLayoutModesTitle),
              subLabel: Text(context.localized.settingsLayoutModesDesc),
              onTap: () async {
                final newItems = await openMultiSelectOptions<LayoutMode>(
                  context,
                  label: context.localized.settingsLayoutModesTitle,
                  items: LayoutMode.values,
                  allowMultiSelection: true,
                  selected: ref.read(homeSettingsProvider.select((value) => value.screenLayouts.toList())),
                  itemBuilder: (type, selected, tap) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected,
                    onChanged: (value) => tap(),
                    title: Text(type.label(context)),
                  ),
                );
                ref.read(homeSettingsProvider.notifier).setLayoutModes(newItems.toSet());
              },
              trailing: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                shadowColor: Colors.transparent,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    spacing: 4,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: LayoutMode.values.map((e) {
                      final isCurrent = AdaptiveLayout.layoutModeOf(context) == e;
                      final isEnabled =
                          ref.watch(homeSettingsProvider.select((value) => value.screenLayouts.contains(e)));
                      return Row(
                        spacing: 4,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(e.label(context),
                              style: TextStyle(color: isEnabled ? null : Theme.of(context).disabledColor)),
                          if (isCurrent) const Icon(IconsaxPlusLinear.tick_circle, size: 16),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            SettingsListTile(
              label: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 8,
                children: [
                  if (user?.credentials.localUrl?.isNotEmpty == true)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: ref.watch(localConnectionAvailableProvider)
                            ? Colors.greenAccent
                            : Theme.of(context).colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(context.localized.settingsLocalUrlTitle),
                ],
              ),
              subLabel: Text(user?.credentials.localUrl ?? context.localized.none),
              onTap: () {
                openSimpleTextInput(
                  context,
                  user?.credentials.localUrl,
                  (value) => ref.read(userProvider.notifier).setLocalURL(value),
                  context.localized.settingsLocalUrlSetTitle,
                  context.localized.settingsLocalUrlSetDesc,
                );
              },
            ),
          ],
        ),
        if (ref.watch(supportsNotificationsProvider)) ...[
          const SizedBox(height: 16),
          ...settingsListGroup(
            context,
            SettingsLabelDivider(label: context.localized.notifications),
            [
              Column(
                children: [
                  SettingsListTileEnum(
                    id: SettingId.updateCheckInterval,
                    label: Text(context.localized.updateCheckInterval),
                    subLabel: Text(context.localized.updateCheckIntervalDesc),
                    current: timePickerString(context, clientSettings.updateNotificationsInterval),
                    itemBuilder: (context) {
                      final durations = const [
                        Duration(minutes: 15),
                        Duration(minutes: 30),
                        Duration(hours: 1),
                        Duration(hours: 3),
                        Duration(hours: 6),
                        Duration(hours: 12),
                        Duration(days: 1),
                      ];
                      return durations.map((duration) {
                        return ItemActionButton(
                          label: Text(timePickerString(context, duration)),
                          action: () =>
                              ref.read(clientSettingsProvider.notifier).setUpdateNotificationsInterval(duration),
                        );
                      }).toList();
                    },
                  ),
                  if (lastUpdateAt != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          context.localized.lastUpdateAt(lastUpdateAt, lastUpdateAt),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(155),
                              ),
                        ),
                      ),
                    ),
                  SettingsMessageBox(
                    context.localized.notificationsIntervalClientReminder,
                    messageType: MessageType.info,
                  ),
                  if (enabledBatteryOptimization == true)
                    SettingsMessageBox(
                      context.localized.batteryOptimizationDesc,
                      messageType: MessageType.warning,
                      onTap: () async {
                        await BatteryOptimization.openBatteryOptimizationSettings();
                        if (!mounted) return;
                        await checkBatteryOptimization();
                      },
                    ),
                  if (!kIsWeb && Platform.isIOS)
                    SettingsMessageBox(
                      context.localized.notificationTimerIOSWarning,
                      messageType: MessageType.info,
                    ),
                ],
              ),
              SettingsListTileCheckbox(
                id: SettingId.showNewItemNotification,
                label: Text(context.localized.showNewItemNotificationTitle),
                value: user?.updateNotificationsEnabled ?? false,
                onChanged: (val) async {
                  final current = ref.read(userProvider);
                  if (current == null || val == null) return;

                  ref.read(userProvider.notifier).userState = current.copyWith(updateNotificationsEnabled: val);

                  if (val) {
                    await NotificationService.requestPermission();
                    await ref.read(updateNotificationsProvider).registerBackgroundTask();
                  } else {
                    await ref.read(updateNotificationsProvider).conditionallyUnregisterBackgroundTask();
                  }
                },
              ),
              if (kDebugMode) ...[
                SettingsListTile(
                  label: const Text('Show notification (debug)'),
                  onTap: () async => await ref.read(updateNotificationsProvider).executeBackgroundTask(),
                ),
                SettingsListTile(
                  label: const Text('Cancel all tasks (debug)'),
                  onTap: () async => await ref.read(updateNotificationsProvider).cancelAllTasks(),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 16),

        // ---- Sync & Backup ----
        ...settingsListGroup(
          context,
          SettingsLabelDivider(label: context.localized.settingsSyncBackupSectionTitle),
          [
            SettingsListTile(
              label: Text(context.localized.syncNow),
              subLabel: Builder(builder: (context) {
                final syncedAt = ref.watch(userProvider.select((value) => value?.userSettings?.syncedAt));
                final parsed = syncedAt == null ? null : DateTime.tryParse(syncedAt);
                return Text(parsed == null
                    ? context.localized.syncedNever
                    : context.localized.syncedAtLabel(DateFormat.yMd().add_jm().format(parsed.toLocal())));
              }),
              onTap: () => ref.read(configSyncProvider).syncNow(),
              trailing: const Icon(Icons.cloud_sync_outlined),
            ),
            Builder(builder: (context) => buildCrashReportingTile(context, ref)),
            const SettingsBackupActions(),
          ],
        ),
      ],
    );
  }
}
