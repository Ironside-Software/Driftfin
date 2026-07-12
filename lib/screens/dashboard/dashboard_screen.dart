import 'dart:async';

import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/collection_types.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/library_search/library_search_options.dart';
import 'package:driftfin/models/settings/home_settings_model.dart';
import 'package:driftfin/providers/dashboard_mode_provider.dart';
import 'package:driftfin/providers/dashboard_provider.dart';
import 'package:driftfin/providers/living_home_provider.dart';
import 'package:driftfin/providers/settings/client_settings_provider.dart';
import 'package:driftfin/providers/home_collections_provider.dart';
import 'package:driftfin/providers/settings/home_settings_provider.dart';
import 'package:driftfin/providers/smart_shelves_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/providers/views_provider.dart';
import 'package:driftfin/routes/auto_router.gr.dart';
import 'package:driftfin/screens/dashboard/home_banner_widget.dart';
import 'package:driftfin/screens/dashboard/music_dashboard_screen.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/shared/media/poster_row.dart';
import 'package:driftfin/screens/shared/nested_scaffold.dart';
import 'package:driftfin/screens/shared/nested_sliver_appbar.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/focus_provider.dart';
import 'package:driftfin/util/list_padding.dart';
import 'package:driftfin/util/localization_helper.dart';
import 'package:driftfin/util/sliver_list_padding.dart';
import 'package:driftfin/widgets/navigation_scaffold/components/background_image.dart';
import 'package:driftfin/widgets/shared/pinch_poster_zoom.dart';
import 'package:driftfin/widgets/shared/poster_size_slider.dart';
import 'package:driftfin/widgets/shared/pull_to_refresh.dart';

@RoutePage()
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({
    super.key,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final Timer _timer;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  final textController = TextEditingController();

  final selectedPoster = ValueNotifier<ItemBaseModel?>(null);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 120), (timer) {
      _refreshIndicatorKey.currentState?.show();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(livingHomeProvider.notifier).refreshIfStale();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _refreshHome() async {
    if (mounted) {
      refreshHomeCollections();
      ref.invalidate(homeCollectionsProvider);
      ref.invalidate(smartShelvesProvider);
      await ref.read(userProvider.notifier).updateInformation();
      await ref.read(viewsProvider.notifier).fetchViews();
      await ref.read(dashboardProvider.notifier).fetchNextUpAndResume();
      // Rails are more expensive than the 120s dashboard poll warrants, so
      // they self-throttle via refreshIfStale rather than refetching here.
      await ref.read(livingHomeProvider.notifier).refreshIfStale();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(musicDashboardModeProvider)) {
      return const MusicDashboardScreen();
    }

    final padding = AdaptiveLayout.adaptivePadding(context);
    final bannerType = ref.watch(homeSettingsProvider.select((value) => value.homeBanner));
    final dashboardData = ref.watch(dashboardProvider);
    final views = ref.watch(viewsProvider);
    final pinnedCollections = ref.watch(homeCollectionsProvider).valueOrNull ?? [];
    final livingHomeRails = ref.watch(livingHomeProvider.select((value) => value.rails));
    final smartShelves = ref.watch(smartShelvesProvider).valueOrNull ?? [];
    final homeSettings = ref.watch(homeSettingsProvider);
    final homeBanner = ref.watch(homeSettingsProvider.select((value) => value.homeBanner)) != HomeBanner.hide;
    final resumeVideo = dashboardData.resumeVideo;
    final resumeAudio = dashboardData.resumeAudio;
    final resumeBooks = dashboardData.resumeBooks;
    final tvChannels = dashboardData.activePrograms;

    final allResume = [...resumeVideo, ...resumeAudio, ...resumeBooks].toList();

    final homeCarouselItems = switch (homeSettings.carouselSettings) {
      HomeCarouselSettings.nextUp => dashboardData.nextUp,
      HomeCarouselSettings.combined => [...allResume, ...dashboardData.nextUp],
      HomeCarouselSettings.cont => allResume,
    };

    final viewSize = AdaptiveLayout.viewSizeOf(context);

    final useTVExpandedLayout = ref.watch(clientSettingsProvider.select((value) => value.useTVExpandedLayout));

    return NestedScaffold(
      background: ValueListenableBuilder<ItemBaseModel?>(
        valueListenable: selectedPoster,
        builder: (_, value, __) {
          return BackgroundImage(
            images: (value != null
                    ? [value]
                    : [
                        ...homeCarouselItems,
                        ...dashboardData.nextUp,
                        ...allResume,
                      ])
                .map((e) => e.images)
                .nonNulls
                .toList(),
          );
        },
      ),
      body: PullToRefresh(
        refreshKey: _refreshIndicatorKey,
        displacement: 80 + MediaQuery.of(context).viewPadding.top,
        onRefresh: () async => await _refreshHome(),
        child: (context) => PinchPosterZoom(
          scaleDifference: (difference) => ref.read(clientSettingsProvider.notifier).addPosterSize(difference),
          child: CustomScrollView(
            controller: AdaptiveLayout.scrollOf(context, HomeTabs.dashboard),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (bannerType != HomeBanner.detailedBanner) const DefaultSliverTopBadding(),
              if (viewSize == ViewSize.phone)
                NestedSliverAppBar(
                  route: LibrarySearchRoute(),
                  parent: context,
                ),
              if (homeBanner && homeCarouselItems.isNotEmpty) ...{
                SliverToBoxAdapter(
                  child: Padding(
                    padding: AdaptiveLayout.adaptivePadding(
                      context,
                      horizontalPadding: 0,
                    ),
                    child: HomeBannerWidget(
                      posters: homeCarouselItems,
                      onSelect: (poster) => selectedPoster.value = poster,
                    ),
                  ),
                ),
              },
              SliverToBoxAdapter(
                child: Padding(
                  padding: AdaptiveLayout.adaptivePadding(context, horizontalPadding: 8),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        icon: const Icon(IconsaxPlusLinear.medal_star),
                        label: Text(context.localized.tastePassport),
                        onPressed: () => const TastePassportRoute().navigate(context),
                      ),
                      TextButton.icon(
                        icon: const Icon(IconsaxPlusLinear.moon),
                        label: Text(context.localized.tonight),
                        onPressed: () => const TonightRoute().navigate(context),
                      ),
                      if (AdaptiveLayout.of(context).isDesktop) const PosterSizeWidget(),
                    ],
                  ),
                ),
              ),
              ...[
                if (tvChannels.isNotEmpty)
                  PosterRow(
                    contentPadding: padding,
                    tvMode: useTVExpandedLayout,
                    label: context.localized.activeTvChannels,
                    collectionAspectRatio: 0.55,
                    onLabelClick: () {
                      return LiveTvRoute().navigate(context);
                    },
                    posters: tvChannels,
                  ),
                if (resumeVideo.isNotEmpty &&
                    (homeSettings.nextUp == HomeNextUp.cont || homeSettings.nextUp == HomeNextUp.separate))
                  PosterRow(
                    tvMode: useTVExpandedLayout,
                    contentPadding: padding,
                    label: context.localized.dashboardContinueWatching,
                    posters: resumeVideo,
                  ),
                if (resumeAudio.isNotEmpty &&
                    (homeSettings.nextUp == HomeNextUp.cont || homeSettings.nextUp == HomeNextUp.separate))
                  PosterRow(
                    tvMode: useTVExpandedLayout,
                    contentPadding: padding,
                    label: context.localized.dashboardContinueListening,
                    posters: resumeAudio,
                  ),
                if (resumeBooks.isNotEmpty &&
                    (homeSettings.nextUp == HomeNextUp.cont || homeSettings.nextUp == HomeNextUp.separate))
                  PosterRow(
                    tvMode: useTVExpandedLayout,
                    contentPadding: padding,
                    label: context.localized.dashboardContinueReading,
                    posters: resumeBooks,
                  ),
                if (dashboardData.nextUp.isNotEmpty &&
                    (homeSettings.nextUp == HomeNextUp.nextUp || homeSettings.nextUp == HomeNextUp.separate))
                  PosterRow(
                    tvMode: useTVExpandedLayout,
                    contentPadding: padding,
                    label: context.localized.nextUp,
                    posters: dashboardData.nextUp,
                  ),
                if ([...allResume, ...dashboardData.nextUp].isNotEmpty && homeSettings.nextUp == HomeNextUp.combined)
                  PosterRow(
                    tvMode: useTVExpandedLayout,
                    contentPadding: padding,
                    label: context.localized.dashboardContinue,
                    posters: [...allResume, ...dashboardData.nextUp],
                  ),
                ...pinnedCollections.where((collection) => collection.items.isNotEmpty).map(
                      (collection) => PosterRow(
                        tvMode: useTVExpandedLayout,
                        contentPadding: padding,
                        label: collection.name,
                        posters: collection.items,
                        onLabelClick: () => collection.container.navigateTo(context),
                      ),
                    ),
                ...livingHomeRails.map(
                  (rail) => PosterRow(
                    tvMode: useTVExpandedLayout,
                    contentPadding: padding,
                    label: rail.name.label(context.localized),
                    posters: rail.posters,
                  ),
                ),
                ...smartShelves.map(
                  (shelf) => PosterRow(
                    tvMode: useTVExpandedLayout,
                    contentPadding: padding,
                    label: shelf.name.label(context.localized),
                    posters: shelf.posters,
                  ),
                ),
                ...views.dashboardViews
                    .where(
                      (element) => element.recentlyAdded.isNotEmpty && element.collectionType != CollectionType.livetv,
                    )
                    .map(
                      (view) => PosterRow(
                        tvMode: useTVExpandedLayout,
                        contentPadding: padding,
                        label: context.localized.dashboardRecentlyAdded(view.name),
                        collectionAspectRatio: view.collectionType.aspectRatio,
                        onLabelClick: () {
                          if (view.collectionType == CollectionType.livetv) {
                            return LiveTvRoute().navigate(context);
                          }
                          return context.router.push(
                            LibrarySearchRoute(
                              viewModelId: view.id,
                              types: switch (view.collectionType) {
                                CollectionType.tvshows => {
                                    FladderItemType.episode: true,
                                  },
                                _ => {},
                              },
                              sortingOptions: switch (view.collectionType) {
                                CollectionType.books ||
                                CollectionType.boxsets ||
                                CollectionType.folders ||
                                CollectionType.music =>
                                  SortingOptions.dateLastContentAdded,
                                _ => SortingOptions.dateAdded,
                              },
                              sortOrder: SortingOrder.descending,
                              recursive: true,
                            ),
                          );
                        },
                        posters: view.recentlyAdded,
                      ),
                    ),
              ]
                  .nonNulls
                  .toList()
                  .mapIndexed(
                    (index, child) => SliverToBoxAdapter(
                      child: FocusProvider(
                        autoFocus: homeCarouselItems.isEmpty ? index == 0 : false,
                        child: child,
                      ),
                    ),
                  )
                  .toList()
                  .addInBetween(
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 16),
                    ),
                  ),
              const DefaultSliverBottomPadding(),
            ],
          ),
        ),
      ),
    );
  }
}
