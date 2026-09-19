import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';

import 'package:driftfin/models/discovery_search.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/providers/discovery_search_provider.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/routes/auto_router.gr.dart';
import 'package:driftfin/screens/seerr/widgets/seerr_poster_card.dart';
import 'package:driftfin/util/localization_helper.dart';
import 'package:driftfin/util/plugin_reason_message.dart';
import 'package:driftfin/util/refresh_state.dart';
import 'package:driftfin/widgets/shared/grid_focus_traveler.dart';

class DiscoverySearchResults extends ConsumerWidget {
  const DiscoverySearchResults({required this.query, this.libraryItems = const [], super.key});
  final String query;
  final List<ItemBaseModel> libraryItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (query: query, language: discoveryLanguage(Localizations.localeOf(context)));
    final state = ref.watch(discoverySearchProvider(key));
    final results = distinctDiscoveryResults(state.results, libraryItems);
    final l10n = context.localized;
    return MultiSliver(
      children: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(l10n.discover, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        if (state.reason != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(pluginReasonMessage(context, state.reason)),
                  TextButton(
                    onPressed: () async {
                      if (ref.read(serverIntegrationConfigProvider)?.capabilities?.feature('discovery').allowed !=
                          true) {
                        await ref.read(serverIntegrationConfigProvider.notifier).load();
                      } else {
                        await ref.read(discoverySearchProvider(key).notifier).loadMore();
                      }
                    },
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          ),
        if (results.isNotEmpty)
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.crossAxisExtent / 180).floor().clamp(1, 10);
              return GridFocusTraveler(
                itemCount: results.length,
                crossAxisCount: columns,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.55,
                ),
                itemBuilder: (_, _, index) {
                  final item = results[index];
                  final label = switch (item.availability) {
                    DiscoveryAvailability.available => l10n.seerrMediaStatusAvailable,
                    DiscoveryAvailability.partial => l10n.seerrMediaStatusPartiallyAvailable,
                    DiscoveryAvailability.requested => l10n.discoveryRequested,
                    DiscoveryAvailability.requestable => l10n.discoveryRequestable,
                    DiscoveryAvailability.unavailable => l10n.discoveryUnavailable,
                  };
                  return Column(
                    key: ValueKey(item.key),
                    children: [
                      Expanded(
                        child: SeerrPosterCard(
                          poster: item.poster,
                          requestAllowed: item.canRequest,
                          onTap: item.libraryItemId == null
                              ? null
                              : () async {
                                  await context.router.push(DetailsRoute(id: item.libraryItemId!));
                                  if (context.mounted) await context.refreshData();
                                },
                        ),
                      ),
                      Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium),
                    ],
                  );
                },
              );
            },
          ),
        if (state.loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (state.reason == null && state.page > 0 && state.hasMore)
          SliverToBoxAdapter(
            child: Center(
              child: TextButton(
                onPressed: () => ref.read(discoverySearchProvider(key).notifier).loadMore(),
                child: Text(l10n.discoveryLoadMore),
              ),
            ),
          )
        else if (state.reason == null && state.page > 0 && results.isEmpty)
          SliverToBoxAdapter(
            child: Padding(padding: const EdgeInsets.all(12), child: Text(l10n.noItemsToShow)),
          ),
      ],
    );
  }
}
