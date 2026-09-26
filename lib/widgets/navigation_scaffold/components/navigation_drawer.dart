import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:driftfin/models/view_model.dart';
import 'package:driftfin/providers/connectivity_provider.dart';
import 'package:driftfin/routes/auto_router.gr.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/localization_helper.dart';
import 'package:driftfin/widgets/navigation_scaffold/components/destination_model.dart';
import 'package:driftfin/widgets/navigation_scaffold/components/navigation_button.dart';
import 'package:driftfin/widgets/navigation_scaffold/components/settings_user_icon.dart';
import 'package:driftfin/widgets/navigation_scaffold/components/side_navigation_buttons.dart';
import 'package:driftfin/widgets/shared/custom_tooltip.dart';

class NestedNavigationDrawer extends ConsumerWidget {
  final bool isExpanded;
  final Function(bool expanded) toggleExpanded;
  final List<DestinationModel> destinations;
  final List<ViewModel> views;
  final String currentLocation;
  final int currentIndex;
  const NestedNavigationDrawer({
    this.isExpanded = false,
    required this.toggleExpanded,
    required this.destinations,
    required this.views,
    required this.currentLocation,
    required this.currentIndex,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationDrawer(
      key: const Key('navigation_drawer'),
      backgroundColor: isExpanded ? Colors.transparent : null,
      surfaceTintColor: isExpanded ? Colors.transparent : null,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(8, AdaptiveLayout.of(context).isDesktop || kIsWeb ? 0 : 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.localized.navigation,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75)),
                ),
              ),
              IconButton(onPressed: () => toggleExpanded(false), icon: const Icon(IconsaxPlusLinear.sidebar_left)),
            ],
          ),
        ),
        SideNavigationButtons(
          largeBar: true,
          destinations: destinations,
          tooltipPosition: TooltipPosition.right,
          currentIndex: currentIndex,
          shouldExpand: true,
          useOverflow: false,
        ),
        const Divider(indent: 28, endIndent: 28),
        if (!ref.watch(offlineStateProvider))
          NavigationButton(
            horizontal: true,
            expanded: true,
            label: context.localized.calendarTitle,
            selected: currentLocation.contains(const CalendarRoute().routeName),
            selectedIcon: const Icon(IconsaxPlusBold.calendar_1),
            icon: const Icon(IconsaxPlusLinear.calendar_1),
            onPressed: () {
              context.router.push(const CalendarRoute());
              Scaffold.of(context).closeDrawer();
            },
          ),
        NavigationButton(
          label: context.localized.settings,
          selected: currentLocation.contains(const SettingsRoute().routeName),
          selectedIcon: const Icon(IconsaxPlusBold.setting_3),
          horizontal: true,
          expanded: true,
          icon: const SizedBox.shrink(),
          customIcon: const ExcludeFocusTraversal(child: SizedBox.square(dimension: 40, child: SettingsUserIcon())),
          onPressed: () {
            if (AdaptiveLayout.layoutModeOf(context) == LayoutMode.single) {
              context.router.push(const SettingsRoute());
            } else {
              context.router.push(const PlayerSettingsRoute());
            }
          },
        ),
        if (AdaptiveLayout.of(context).isDesktop || kIsWeb) const SizedBox(height: 8),
      ],
    );
  }
}
