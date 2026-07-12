import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/library_filter_model.dart';
import 'package:driftfin/models/library_search/library_search_options.dart';
import 'package:driftfin/util/library_filter_query.dart';

void main() {
  group('LibraryFilterModelQuery.toQueryParams', () {
    test('only includes enabled entries from each filter map', () {
      const model = LibraryFilterModel(
        genres: {'Comedy': true, 'Drama': false},
        tags: {'A24': true, 'Marvel': false},
        officialRatings: {'PG-13': true, 'R': false},
        years: {2020: true, 1990: false},
      );
      final query = model.toQueryParams();
      expect(query.genres, ['Comedy']);
      expect(query.tags, ['A24']);
      expect(query.officialRatings, ['PG-13']);
      expect(query.years, [2020]);
    });

    test('maps enabled studios down to their ids', () {
      final a24 = Studio(id: 's1', name: 'A24');
      final marvel = Studio(id: 's2', name: 'Marvel');
      final model = LibraryFilterModel(studios: {a24: true, marvel: false});
      expect(model.toQueryParams().studioIds, ['s1']);
    });

    test('translates the sorting option and order', () {
      const model = LibraryFilterModel(
        sortingOption: SortingOptions.communityRating,
        sortOrder: SortingOrder.descending,
      );
      final query = model.toQueryParams();
      expect(query.sortBy, contains(ItemSortBy.communityrating));
      expect(query.sortOrder, [SortOrder.descending]);
    });

    test('adds isfavorite to filters when favourites is set', () {
      const model = LibraryFilterModel(favourites: true);
      expect(model.toQueryParams().filters, contains(ItemFilter.isfavorite));
    });

    test('does not add isfavorite when favourites is false', () {
      const model = LibraryFilterModel(favourites: false);
      expect(model.toQueryParams().filters, isNot(contains(ItemFilter.isfavorite)));
    });

    test('includes enabled itemFilters alongside favourites', () {
      const model = LibraryFilterModel(
        favourites: true,
        itemFilters: {ItemFilter.isunplayed: true, ItemFilter.isplayed: false},
      );
      final filters = model.toQueryParams().filters;
      expect(filters, containsAll([ItemFilter.isunplayed, ItemFilter.isfavorite]));
      expect(filters, isNot(contains(ItemFilter.isplayed)));
    });

    test('maps enabled types to their dto kinds', () {
      const model = LibraryFilterModel(types: {FladderItemType.movie: true, FladderItemType.series: false});
      expect(model.toQueryParams().includeItemTypes, [BaseItemKind.movie]);
    });

    test('passes recursive through unchanged', () {
      const model = LibraryFilterModel(recursive: false);
      expect(model.toQueryParams().recursive, false);
    });
  });
}
