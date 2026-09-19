import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driftfin/models/settings/home_settings_model.dart';
import 'package:driftfin/models/settings/settings_entry.dart';
import 'package:driftfin/providers/home_collections_provider.dart';
import 'package:driftfin/providers/settings/client_settings_provider.dart';
import 'package:driftfin/providers/settings/home_settings_provider.dart';
import 'package:driftfin/screens/settings/settings_list_tile.dart';
import 'package:driftfin/screens/settings/widgets/settings_label_divider.dart';
import 'package:driftfin/screens/settings/widgets/settings_list_group.dart';
import 'package:driftfin/util/localization_helper.dart';
import 'package:driftfin/widgets/shared/item_actions.dart';

List<Widget> buildClientSettingsDashboard(BuildContext context, WidgetRef ref) {
  final clientSettings = ref.watch(clientSettingsProvider);
  return settingsListGroup(context, SettingsLabelDivider(label: context.localized.dashboard), [
    SettingsListTileEnum(
      id: SettingId.homeBanner,
      label: Text(context.localized.settingsHomeBannerTitle),
      subLabel: Text(context.localized.settingsHomeBannerDescription),
      current: ref.watch(homeSettingsProvider.select((value) => value.homeBanner.label(context))),
      itemBuilder: (context) => HomeBanner.values
          .map(
            (entry) => ItemActionButton(
              label: Text(entry.label(context)),
              action: () =>
                  ref.read(homeSettingsProvider.notifier).update((context) => context.copyWith(homeBanner: entry)),
            ),
          )
          .toList(),
    ),
    if (ref.watch(homeSettingsProvider.select((value) => value.homeBanner)) != HomeBanner.hide)
      SettingsListTileEnum(
        id: SettingId.homeBannerInformation,
        label: Text(context.localized.settingsHomeBannerInformationTitle),
        subLabel: Text(context.localized.settingsHomeBannerInformationDesc),
        current: ref.watch(homeSettingsProvider.select((value) => value.carouselSettings.label(context))),
        itemBuilder: (context) => HomeCarouselSettings.values
            .map(
              (entry) => ItemActionButton(
                label: Text(entry.label(context)),
                action: () => ref
                    .read(homeSettingsProvider.notifier)
                    .update((context) => context.copyWith(carouselSettings: entry)),
              ),
            )
            .toList(),
      ),
    SettingsListTileEnum(
      id: SettingId.homeNextUp,
      label: Text(context.localized.settingsHomeNextUpTitle),
      subLabel: Text(context.localized.settingsHomeNextUpDesc),
      current: ref.watch(homeSettingsProvider.select((value) => value.nextUp.label(context))),
      itemBuilder: (context) => HomeNextUp.values
          .map(
            (entry) => ItemActionButton(
              label: Text(entry.label(context)),
              action: () =>
                  ref.read(homeSettingsProvider.notifier).update((context) => context.copyWith(nextUp: entry)),
            ),
          )
          .toList(),
    ),
    SettingsListTile(
      id: SettingId.showAllCollectionTypes,
      label: Text(context.localized.clientSettingsShowAllCollectionsTitle),
      subLabel: Text(context.localized.clientSettingsShowAllCollectionsDesc),
      onTap: () => ref
          .read(clientSettingsProvider.notifier)
          .update((current) => current.copyWith(showAllCollectionTypes: !current.showAllCollectionTypes)),
      trailing: Switch(
        value: clientSettings.showAllCollectionTypes,
        onChanged: (value) => ref
            .read(clientSettingsProvider.notifier)
            .update((current) => current.copyWith(showAllCollectionTypes: value)),
      ),
    ),
    if (ref.watch(homeSettingsProvider.select((value) => value.pinnedCollectionIds)).isNotEmpty)
      SettingsListTile(
        id: SettingId.managePinnedCollections,
        label: Text(context.localized.managePinnedCollections),
        subLabel: Text(context.localized.managePinnedCollectionsDesc),
        onTap: () => _showManagePinnedCollections(context),
        trailing: const Icon(Icons.dashboard_customize_outlined),
      ),
  ]);
}

Future<void> _showManagePinnedCollections(BuildContext context) {
  return showDialog(
    context: context,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final ids = ref.watch(homeSettingsProvider.select((value) => value.pinnedCollectionIds));
        final collections = ref.watch(homeCollectionsProvider).value ?? [];
        String nameFor(String id) =>
            collections.firstWhereOrNull((collection) => collection.container.id == id)?.name ?? id;
        return AlertDialog(
          title: Text(context.localized.managePinnedCollections),
          content: SizedBox(
            width: 400,
            height: 360,
            child: ids.isEmpty
                ? Center(child: Text(context.localized.noPinnedCollections, textAlign: TextAlign.center))
                : ReorderableListView(
                    onReorderItem: (oldIndex, newIndex) {
                      final reordered = [...ids];
                      reordered.insert(newIndex, reordered.removeAt(oldIndex));
                      ref.read(homeSettingsProvider.notifier).setPinnedCollections(reordered);
                    },
                    children: [
                      for (final id in ids)
                        ListTile(
                          key: ValueKey(id),
                          title: Text(nameFor(id)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => ref.read(homeSettingsProvider.notifier).toggleHomeCollection(id),
                          ),
                        ),
                    ],
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.localized.close))],
        );
      },
    ),
  );
}
