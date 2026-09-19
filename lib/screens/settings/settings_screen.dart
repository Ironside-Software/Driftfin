import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:driftfin/providers/arguments_provider.dart';
import 'package:driftfin/providers/auth_provider.dart';
import 'package:driftfin/providers/update_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/routes/auto_router.gr.dart';
import 'package:driftfin/screens/settings/quick_connect_window.dart';
import 'package:driftfin/screens/settings/settings_list_tile.dart';
import 'package:driftfin/screens/settings/settings_scaffold.dart';
import 'package:driftfin/screens/settings/widgets/settings_search_field.dart';
import 'package:driftfin/screens/shared/default_alert_dialog.dart';
import 'package:driftfin/screens/shared/driftfin_icon.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/localization_helper.dart';
import 'package:driftfin/util/theme_extensions.dart';
import 'package:driftfin/util/window_actions.dart';

@RoutePage()
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final scrollController = ScrollController();
  final minVerticalPadding = 20.0;
  late LayoutMode lastAdaptiveLayout = AdaptiveLayout.layoutModeOf(context);

  @override
  Widget build(BuildContext context) {
    return AutoTabsRouter(
      builder: (context, content) {
        checkForNullIndex(context);
        return PopScope(
          canPop: context.tabsRouter.activeIndex == 0 || AdaptiveLayout.layoutModeOf(context) == LayoutMode.dual,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              context.tabsRouter.setActiveIndex(0);
            }
          },
          child: AdaptiveLayout.layoutModeOf(context) == LayoutMode.single
              ? Card(
                  elevation: 0,
                  child: Stack(
                    children: [
                      _leftPane(context),
                      content,
                    ],
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: _leftPane(context)),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: MediaQuery.paddingOf(context).left,
                        ),
                        child: content,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  //We have to navigate to the first screen after switching layouts && index == 0 otherwise the dual-layout is empty
  void checkForNullIndex(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentIndex = context.tabsRouter.activeIndex;
      if (AdaptiveLayout.layoutModeOf(context) == LayoutMode.dual && currentIndex == 0) {
        context.tabsRouter.setActiveIndex(1);
      }
    });
  }

  Widget _leftPane(BuildContext context) {
    void navigateTo(PageRouteInfo route) => context.tabsRouter.navigate(route);

    bool containsRoute(PageRouteInfo route) =>
        AdaptiveLayout.layoutModeOf(context) == LayoutMode.dual && context.tabsRouter.current.name == route.routeName;

    final quickConnectAvailable =
        ref.watch(userProvider.select((value) => value?.serverConfiguration?.quickConnectAvailable ?? false));

    final newRelease = ref.watch(updateProvider.select((value) => value.latestRelease));

    final hasNewUpdate = ref.watch(hasNewUpdateProvider);

    final isAdmin = ref.watch(userProvider.select((value) => value?.policy?.isAdministrator ?? false));

    return Padding(
      padding: EdgeInsetsDirectional.only(start: AdaptiveLayout.of(context).sideBarWidth),
      child: Container(
        color: context.colors.surface,
        child: SettingsScaffold(
          label: context.localized.settings,
          scrollController: scrollController,
          showBackButtonNested: AdaptiveLayout.inputDeviceOf(context) != InputDevice.dPad,
          showUserIcon: true,
          items: [
            const SettingsSearchField(),
            const SizedBox(height: 8),
            if (hasNewUpdate && newRelease != null) ...[
              Card(
                color: context.colors.secondaryContainer,
                child: SettingsListTile(
                  label: Text(context.localized.newReleaseFoundTitle(newRelease.version)),
                  subLabel: Text(context.localized.newUpdateFoundOnGithub),
                  icon: IconsaxPlusLinear.information,
                  onTap: () => navigateTo(const AboutSettingsRoute()),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SettingsListTile(
              label: Text(context.localized.settingsPlaybackTitle),
              subLabel: Text(context.localized.settingsPlaybackDesc),
              autoFocus: true,
              selected: containsRoute(const PlayerSettingsRoute()),
              icon: IconsaxPlusLinear.video_play,
              onTap: () => navigateTo(const PlayerSettingsRoute()),
            ),
            if (isAdmin)
              SettingsListTile(
                label: Text(context.localized.controlPanel),
                subLabel: Text(context.localized.controlPanelDesc),
                selected: containsRoute(const ControlPanelSelectionRoute()),
                icon: IconsaxPlusLinear.chart_3,
                onTap: () => const ControlPanelSelectionRoute().navigate(context),
              ),
            SettingsListTile(
              label: Text(context.localized.settingsAccountDeviceTitle),
              subLabel: Text(context.localized.settingsAccountDeviceDesc),
              selected: containsRoute(const AccountDeviceSettingsRoute()),
              icon: IconsaxPlusLinear.security_user,
              onTap: () => navigateTo(const AccountDeviceSettingsRoute()),
            ),
            SettingsListTile(
              label: Text(context.localized.settingsAppearanceTitle),
              subLabel: Text(context.localized.settingsAppearanceDesc),
              selected: containsRoute(const AppearanceSettingsRoute()),
              icon: IconsaxPlusLinear.brush_2,
              onTap: () => navigateTo(const AppearanceSettingsRoute()),
            ),
            SettingsListTile(
              label: Text(context.localized.settingsHomeLibraryTitle),
              subLabel: Text(context.localized.settingsHomeLibraryDesc),
              selected: containsRoute(const HomeLibrarySettingsRoute()),
              icon: IconsaxPlusLinear.home_1,
              onTap: () => navigateTo(const HomeLibrarySettingsRoute()),
            ),
            SettingsListTile(
              label: Text(context.localized.settingsDownloadsOfflineTitle),
              subLabel: Text(context.localized.settingsDownloadsOfflineDesc),
              selected: containsRoute(const DownloadsSettingsRoute()),
              icon: IconsaxPlusLinear.document_download,
              onTap: () => navigateTo(const DownloadsSettingsRoute()),
            ),
            SettingsListTile(
              label: Text(context.localized.settingsIntegrationsTitle),
              subLabel: Text(context.localized.settingsIntegrationsDesc),
              selected: containsRoute(const IntegrationsSettingsRoute()),
              icon: IconsaxPlusLinear.link_2,
              onTap: () => navigateTo(const IntegrationsSettingsRoute()),
            ),
            SettingsListTile(
              label: Text(context.localized.about),
              subLabel: Text("Driftfin, ${context.localized.latestReleases}"),
              selected: containsRoute(const AboutSettingsRoute()),
              leading: Opacity(
                opacity: 1,
                child: DriftfinIconOutlined(
                  size: 24,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              onTap: () => navigateTo(const AboutSettingsRoute()),
            ),
            const FractionallySizedBox(
              widthFactor: 0.25,
              child: Divider(),
            ),
            if (quickConnectAvailable)
              SettingsListTile(
                label: Text(context.localized.settingsQuickConnectTitle),
                icon: IconsaxPlusLinear.password_check,
                onTap: () => openQuickConnectDialog(context),
              ),
            if (ref.watch(argumentsStateProvider.select((value) => value.htpcMode)))
              SettingsListTile(
                label: Text(context.localized.exitDriftfinTitle),
                icon: IconsaxPlusLinear.close_square,
                onTap: () async {
                  showDefaultAlertDialog(
                    context,
                    context.localized.exitDriftfinTitle,
                    context.localized.exitDriftfinDesc,
                    (context) async {
                      if (AdaptiveLayout.of(context).isDesktop) {
                        await quitApplication(context);
                      } else {
                        SystemNavigator.pop();
                      }
                    },
                    context.localized.close,
                    (context) => context.pop(),
                    context.localized.cancel,
                  );
                },
              ),
            SettingsListTile(
              label: Text(context.localized.switchUser),
              icon: IconsaxPlusLinear.arrow_swap_horizontal,
              contentColor: Colors.greenAccent,
              onTap: () async {
                await ref.read(userProvider.notifier).logoutUser();
                context.router.replaceAll([LoginRoute()]);
              },
            ),
            SettingsListTile(
              label: Text(context.localized.logout),
              icon: IconsaxPlusLinear.logout,
              contentColor: Theme.of(context).colorScheme.error,
              onTap: () {
                final user = ref.read(userProvider);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.localized.logoutUserPopupTitle(user?.name ?? "")),
                    scrollable: true,
                    content: Text(
                      context.localized.logoutUserPopupContent(user?.name ?? "", user?.credentials.url ?? ""),
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(context.localized.cancel),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom().copyWith(
                          iconColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.onErrorContainer),
                          foregroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.onErrorContainer),
                          backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.errorContainer),
                        ),
                        onPressed: () async {
                          await ref.read(authProvider.notifier).logOutUser();
                          if (context.mounted) {
                            context.router.replaceAll([LoginRoute()]);
                          }
                        },
                        child: Text(context.localized.logout),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
