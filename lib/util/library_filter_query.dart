import 'package:driftfin/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:driftfin/models/library_filter_model.dart';
import 'package:driftfin/util/map_bool_helper.dart';

/// The subset of `JellyService.itemsGet` parameters that a [LibraryFilterModel]
/// fully describes. Kept as a plain, testable value object so the query
/// construction (which fields map to which itemsGet params) can be verified
/// without a live [JellyService]/network call - see `_loadLibrary` in
/// `library_search_provider.dart` for the equivalent hand-written call this
/// mirrors.
class LibraryFilterQueryParams {
  final List<String> genres;
  final List<String> tags;
  final List<String> officialRatings;
  final List<int> years;
  final List<String> studioIds;
  final List<ItemSortBy> sortBy;
  final List<SortOrder> sortOrder;
  final List<ItemFilter> filters;
  final List<BaseItemKind> includeItemTypes;
  final bool? recursive;

  const LibraryFilterQueryParams({
    required this.genres,
    required this.tags,
    required this.officialRatings,
    required this.years,
    required this.studioIds,
    required this.sortBy,
    required this.sortOrder,
    required this.filters,
    required this.includeItemTypes,
    required this.recursive,
  });
}

extension LibraryFilterModelQuery on LibraryFilterModel {
  LibraryFilterQueryParams toQueryParams() {
    return LibraryFilterQueryParams(
      genres: genres.included,
      tags: tags.included,
      officialRatings: officialRatings.included,
      years: years.included,
      studioIds: studios.included.map((e) => e.id).toList(),
      sortBy: sortingOption.toSortBy,
      sortOrder: [sortOrder.sortOrder],
      filters: [
        ...itemFilters.included,
        if (favourites == true) ItemFilter.isfavorite,
      ],
      includeItemTypes: types.included.expand((e) => e.dtoKind).toList(),
      recursive: recursive,
    );
  }
}
