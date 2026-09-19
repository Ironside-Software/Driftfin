import 'package:driftfin/models/settings/home_settings_model.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/screens/settings/filters/filters_dialog_popup.dart';
import 'package:driftfin/screens/settings/settings_list_tile.dart';
import 'package:driftfin/screens/settings/widgets/settings_label_divider.dart';
import 'package:driftfin/screens/settings/widgets/settings_list_group.dart';
import 'package:driftfin/util/map_bool_helper.dart';
import 'package:driftfin/widgets/shared/sortable_item_list.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driftfin/providers/home_preferences_provider.dart';
import 'package:driftfin/screens/settings/client_sections/client_settings_dashboard.dart';
import 'package:driftfin/screens/settings/settings_scaffold.dart';
import 'package:driftfin/screens/settings/widgets/home_preferences_editors.dart';
import 'package:driftfin/util/localization_helper.dart';

/// Unifies the home/library preferences that used to be split across the
/// dissolved "Client" page (Dashboard) and "Profile" page (library order) —
/// issue #50 Phase 2. Every change here saves instantly (Phase 3) — there is
/// no Save button.
@RoutePage()
class HomeLibrarySettingsPage extends ConsumerStatefulWidget {
  const HomeLibrarySettingsPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomeLibrarySettingsPageState();
}

class _HomeLibrarySettingsPageState extends ConsumerState<HomeLibrarySettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homePreferencesProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    return SettingsScaffold(
      label: context.localized.settingsHomeLibraryTitle,
      items: [
        ...settingsListGroup(
          context,
          SettingsLabelDivider(label: context.localized.general),
          [
            SortableItemList(
              items: user?.userSettings?.dashboardSorting.keys.toList() ?? DashboardSorting.values,
              included: user?.userSettings?.dashboardSorting.included ?? <DashboardSorting>[],
              itemBuilder: (filter) => Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  filter.label(context),
                ),
              ),
              onReorder: (reordered) => ref.read(userProvider.notifier).setDashboardSorting(reordered),
              onIncludeChange: (items) => ref.read(userProvider.notifier).setDashboardEnabled(items),
            ),
            SettingsListTile(
              label: Text(context.localized.libraryFilters),
              subLabel: Text(context.localized.editYourLibraryFilters),
              onTap: () => showFiltersDialogue(context),
            ),
          ],
        ),
        ...buildClientSettingsDashboard(context, ref),
        const SizedBox(height: 16),
        const LibraryOrderEditor(),
      ],
    );
  }
}
