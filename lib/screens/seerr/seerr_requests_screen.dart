import 'package:flutter/material.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:driftfin/models/seerr/seerr_dashboard_model.dart';
import 'package:driftfin/providers/seerr_requests_provider.dart';
import 'package:driftfin/providers/seerr_user_provider.dart';
import 'package:driftfin/routes/auto_router.gr.dart';
import 'package:driftfin/screens/seerr/widgets/download_status_label.dart';
import 'package:driftfin/screens/seerr/widgets/seerr_user_label.dart';
import 'package:driftfin/seerr/seerr_models.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/fladder_image.dart';
import 'package:driftfin/util/localization_helper.dart';

/// Full requests manager: filter tabs, sort, mine/all scope, infinite scroll,
/// inline approve/decline, bulk-approve, and pull-to-refresh.
@RoutePage()
class SeerrRequestsScreen extends ConsumerStatefulWidget {
  const SeerrRequestsScreen({super.key});

  @override
  ConsumerState<SeerrRequestsScreen> createState() => _SeerrRequestsScreenState();
}

class _SeerrRequestsScreenState extends ConsumerState<SeerrRequestsScreen> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      ref.read(seerrRequestsProvider.notifier).loadMore();
    }
  }

  String _filterLabel(BuildContext context, RequestFilter filter) => switch (filter) {
        RequestFilter.all => context.localized.requestFilterAll,
        RequestFilter.pending => context.localized.seerrRequestStatusPending,
        RequestFilter.processing => context.localized.seerrMediaStatusProcessing,
        RequestFilter.available => context.localized.seerrMediaStatusAvailable,
        RequestFilter.approved => context.localized.seerrRequestStatusApproved,
        RequestFilter.unavailable => context.localized.requestFilterUnavailable,
      };

  String _sortLabel(BuildContext context, RequestSort sort) => switch (sort) {
        RequestSort.added => context.localized.requestSortAdded,
        RequestSort.modified => context.localized.requestSortModified,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(seerrRequestsProvider);
    final notifier = ref.read(seerrRequestsProvider.notifier);
    final canManage = ref.watch(seerrUserProvider.select((user) => user?.canManageRequests ?? false));
    final hasPending = state.entries.any((e) => e.request.requestStatus == SeerrRequestStatus.pending);

    return Padding(
      padding: EdgeInsetsDirectional.only(start: AdaptiveLayout.maybeOf(context)?.data.sideBarWidth ?? 0),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.localized.requestsTitle),
          actions: [
            IconButton(
              tooltip: state.sortDirection == SortDirection.desc ? 'Descending' : 'Ascending',
              icon: Icon(state.sortDirection == SortDirection.desc ? Icons.arrow_downward : Icons.arrow_upward),
              onPressed: notifier.toggleSortDirection,
            ),
            PopupMenuButton<RequestSort>(
              icon: const Icon(Icons.sort),
              initialValue: state.sort,
              onSelected: notifier.setSort,
              itemBuilder: (context) =>
                  RequestSort.values.map((s) => PopupMenuItem(value: s, child: Text(_sortLabel(context, s)))).toList(),
            ),
          ],
        ),
        floatingActionButton: (canManage && hasPending)
            ? FloatingActionButton.extended(
                onPressed: state.processing ? null : notifier.approveAllPending,
                icon: state.processing
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.done_all),
                label: Text(context.localized.approveAllPending),
              )
            : null,
        body: Column(
          children: [
            if (state.hasError)
              ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(context.localized.somethingWentWrong),
                trailing: TextButton(
                  onPressed: state.loading || state.loadingMore ? null : notifier.load,
                  child: Text(context.localized.retry),
                ),
              ),
            if (canManage)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(context.localized.requestsScopeAll)),
                    ButtonSegment(value: true, label: Text(context.localized.requestsScopeMine)),
                  ],
                  selected: {state.mineOnly},
                  onSelectionChanged: (s) => notifier.setMineOnly(s.first),
                ),
              ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final filter in RequestFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_filterLabel(context, filter)),
                        selected: state.filter == filter,
                        onSelected: (_) => notifier.setFilter(filter),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: notifier.load,
                child: state.loading && state.entries.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : state.entries.isEmpty
                        ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                            const SizedBox(height: 120),
                            if (!state.hasError) Center(child: Text(context.localized.noRequestsFound)),
                          ])
                        : GridView.builder(
                            controller: _scroll,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 480,
                              mainAxisExtent: 170,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: state.entries.length + (state.canLoadMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= state.entries.length) {
                                return Center(
                                  child: state.loadingMore
                                      ? const CircularProgressIndicator()
                                      : IconButton(
                                          tooltip:
                                              state.hasError ? context.localized.retry : context.localized.showMore,
                                          onPressed: notifier.loadMore,
                                          icon: const Icon(Icons.expand_more),
                                        ),
                                );
                              }
                              return _RequestCard(
                                entry: state.entries[index],
                                canManage: canManage,
                                onApprove: (id) => notifier.approve(id),
                                onDecline: (id) => notifier.decline(id),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A request rendered as a rich grid card: poster, title, year, status/4K/download
/// badges, a multi-line description, requested-by, and inline approve/decline.
class _RequestCard extends StatelessWidget {
  final SeerrRequestEntry entry;
  final bool canManage;
  final void Function(int requestId) onApprove;
  final void Function(int requestId) onDecline;

  const _RequestCard({
    required this.entry,
    required this.canManage,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final poster = entry.poster;
    final request = entry.request;
    final status = request.requestStatus;
    final image = poster?.images.primary ?? poster?.images.backDrop?.lastOrNull;
    final isPending = status == SeerrRequestStatus.pending;
    final requestId = request.id;
    final overview = poster?.overview.trim() ?? '';
    final year = poster?.releaseYear;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: poster == null
            ? null
            : () => context.router.push(SeerrDetailsRoute(
                  mediaType: poster.type == SeerrMediaType.tvshow ? 'tvshow' : 'movie',
                  tmdbId: poster.tmdbId,
                  poster: poster,
                )),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 96,
                  child: FladderImage(
                    image: image,
                    placeHolder: Container(
                      color: theme.colorScheme.surfaceContainer,
                      child: Icon(
                        poster?.type == SeerrMediaType.tvshow ? Icons.live_tv_outlined : Icons.movie_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            poster?.title ?? '#${request.id}',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (canManage && isPending && requestId != null) ...[
                          _CompactIconButton(
                            tooltip: context.localized.approve,
                            icon: IconsaxPlusLinear.tick_circle,
                            color: Colors.green,
                            onPressed: () => onApprove(requestId),
                          ),
                          _CompactIconButton(
                            tooltip: context.localized.decline,
                            icon: IconsaxPlusLinear.close_circle,
                            color: Colors.red,
                            onPressed: () => onDecline(requestId),
                          ),
                        ],
                      ],
                    ),
                    if (year != null && year.isNotEmpty)
                      Text(
                        year,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: status.color, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            status.label(context),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (request.is4k == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                            ),
                            child: const Text('4K', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        if (poster != null) DownloadStatusLabel(poster: poster),
                      ],
                    ),
                    if (overview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          overview,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    if (request.requestedBy != null) SeerrUserLabel(user: request.requestedBy),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tight, borderless icon button so the approve/decline pair fits in a card header.
class _CompactIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _CompactIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      icon: Icon(icon, color: color),
      onPressed: onPressed,
    );
  }
}
