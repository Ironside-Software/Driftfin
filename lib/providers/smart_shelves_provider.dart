import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driftfin/models/recommended_model.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/util/library_filter_query.dart';

/// Smart Shelves - a saved `LibraryFiltersModel` marked `showOnHome`
/// promoted to a self-updating home rail (e.g. "unwatched sci-fi 7+",
/// "everything from A24"). Re-runs the saved filter's query on every fetch,
/// so the shelf always reflects the current library state.
final smartShelvesProvider = FutureProvider<List<RecommendedModel>>((ref) async {
  final savedFilters = ref
      .watch(userProvider.select((value) => value?.userSettings?.libraryFilters ?? value?.libraryFilters ?? const []));
  final shelves = savedFilters.where((filter) => filter.showOnHome).toList();
  if (shelves.isEmpty) return const [];

  final api = ref.read(jellyApiProvider);

  final rails = await Future.wait(shelves.map((shelf) async {
    final query = shelf.filter.toQueryParams();
    final response = await api.itemsGet(
      parentId: shelf.ids.length == 1 ? shelf.ids.first : null,
      recursive: query.recursive,
      genres: query.genres,
      tags: query.tags,
      officialRatings: query.officialRatings,
      years: query.years,
      studioIds: query.studioIds,
      sortBy: query.sortBy,
      sortOrder: query.sortOrder,
      filters: query.filters,
      includeItemTypes: query.includeItemTypes,
      limit: 24,
    );
    return RecommendedModel(name: Other(shelf.name), posters: response.body?.items ?? []);
  }));

  return rails.where((rail) => rail.posters.isNotEmpty).toList();
});
