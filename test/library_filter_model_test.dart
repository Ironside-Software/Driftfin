import 'package:driftfin/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/library_filter_model.dart';
import 'package:driftfin/models/library_search/library_search_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LibraryFilterModel.hasActiveFilters', () {
    test('a brand-new default model already has active filters (hideEmptyShows defaults true)', () {
      expect(const LibraryFilterModel().hasActiveFilters, isTrue);
    });

    test('is false when hideEmptyShows is off and nothing else is set', () {
      const model = LibraryFilterModel(hideEmptyShows: false);
      expect(model.hasActiveFilters, isFalse);
    });

    test('is true when any genre is enabled', () {
      const model = LibraryFilterModel(hideEmptyShows: false, genres: {'Action': true});
      expect(model.hasActiveFilters, isTrue);
    });

    test('is true when recursive is explicitly false', () {
      const model = LibraryFilterModel(hideEmptyShows: false, recursive: false);
      expect(model.hasActiveFilters, isTrue);
    });

    test('is true when favourites is true', () {
      const model = LibraryFilterModel(hideEmptyShows: false, favourites: true);
      expect(model.hasActiveFilters, isTrue);
    });

    test('is true when an itemFilter is enabled', () {
      const model = LibraryFilterModel(
        hideEmptyShows: false,
        itemFilters: {ItemFilter.isplayed: true},
      );
      expect(model.hasActiveFilters, isTrue);
    });
  });

  group('LibraryFilterModel.loadModel', () {
    test('keys present only in the incoming map are dropped; missing keys default to false', () {
      const current = LibraryFilterModel(genres: {'Action': false, 'Drama': false});
      const incoming = LibraryFilterModel(genres: {'Action': true, 'Comedy': true});
      final result = current.loadModel(incoming);
      expect(result.genres, {'Action': true, 'Drama': false});
    });

    test('an empty incoming map field keeps the current map unchanged', () {
      const current = LibraryFilterModel(genres: {'Action': true});
      const incoming = LibraryFilterModel();
      final result = current.loadModel(incoming);
      expect(result.genres, {'Action': true});
    });

    test('scalar fields are taken wholesale from the incoming model', () {
      const current = LibraryFilterModel();
      const incoming = LibraryFilterModel(
        sortOrder: SortingOrder.descending,
        favourites: true,
        hideEmptyShows: false,
        recursive: false,
      );
      final result = current.loadModel(incoming);
      expect(result.sortOrder, SortingOrder.descending);
      expect(result.favourites, isTrue);
      expect(result.hideEmptyShows, isFalse);
      expect(result.recursive, isFalse);
    });
  });

  group('LibraryFilterModel equality/hashCode', () {
    test('differing only in hideEmptyShows are still == (inconsistency in the hand-written operator)', () {
      const a = LibraryFilterModel(hideEmptyShows: true);
      const b = LibraryFilterModel(hideEmptyShows: false);
      expect(a == b, isTrue);
    });

    test('differing only in groupBy are still == (groupBy excluded from comparison)', () {
      const a = LibraryFilterModel(groupBy: GroupBy.name);
      const b = LibraryFilterModel(groupBy: GroupBy.rating);
      expect(a == b, isTrue);
    });

    test('differing in genres are not equal', () {
      const a = LibraryFilterModel(genres: {'Action': true});
      const b = LibraryFilterModel(genres: {'Action': false});
      expect(a == b, isFalse);
    });

    test('hashCode does not distinguish differing itemFilters (double-XOR cancels out)', () {
      const a = LibraryFilterModel(itemFilters: {ItemFilter.isplayed: true});
      const b = LibraryFilterModel(itemFilters: {ItemFilter.isplayed: false});
      expect(a.hashCode, b.hashCode);
    });
  });

  group('LibraryFilterModel.clear', () {
    test('resets bool maps, favourites, studios, itemFilters and hideEmptyShows/recursive', () {
      const model = LibraryFilterModel(
        genres: {'Action': true},
        tags: {'HDR': true},
        officialRatings: {'PG': true},
        years: {2020: true},
        itemFilters: {ItemFilter.isplayed: true},
        favourites: true,
        recursive: false,
        hideEmptyShows: true,
      );
      final cleared = model.clear();
      expect(cleared.genres, {'Action': false});
      expect(cleared.tags, {'HDR': false});
      expect(cleared.officialRatings, {'PG': false});
      expect(cleared.years, {2020: false});
      expect(cleared.itemFilters, {ItemFilter.isplayed: false});
      expect(cleared.favourites, isFalse);
      expect(cleared.recursive, isTrue);
      expect(cleared.hideEmptyShows, isFalse);
    });

    test('sortingOption, sortOrder, groupBy and types are untouched by clear()', () {
      const model = LibraryFilterModel(
        sortingOption: SortingOptions.communityRating,
        sortOrder: SortingOrder.descending,
        groupBy: GroupBy.genres,
        types: {FladderItemType.movie: true},
      );
      final cleared = model.clear();
      expect(cleared.sortingOption, SortingOptions.communityRating);
      expect(cleared.sortOrder, SortingOrder.descending);
      expect(cleared.groupBy, GroupBy.genres);
      expect(cleared.types, {FladderItemType.movie: true});
    });
  });

  group('StudioEncoder', () {
    const encoder = StudioEncoder();

    test('round-trips a studios map through JSON string encoding', () {
      final studios = {Studio(id: 's1', name: 'Studio One'): true};
      final json = encoder.toJson(studios);
      final decoded = encoder.fromJson(json);
      expect(decoded.length, 1);
      expect(decoded.values.first, isTrue);
      expect(decoded.keys.first.id, 's1');
      expect(decoded.keys.first.name, 'Studio One');
    });

    test('empty map round-trips to empty map', () {
      final json = encoder.toJson({});
      expect(encoder.fromJson(json), isEmpty);
    });

    test('throws on invalid JSON input', () {
      expect(() => encoder.fromJson('not json'), throwsFormatException);
    });
  });

  group('LibraryFilterModel.fromJson', () {
    test('parses scalar fields and genres from a raw json map', () {
      final restored = LibraryFilterModel.fromJson({
        'genres': {'Action': true},
        'favourites': true,
        'recursive': false,
        'studios': const StudioEncoder().toJson({}),
      });
      expect(restored.genres, {'Action': true});
      expect(restored.favourites, isTrue);
      expect(restored.recursive, isFalse);
    });

    test('missing fields fall back to their declared defaults', () {
      final restored = LibraryFilterModel.fromJson({});
      expect(restored, const LibraryFilterModel());
    });
  });

  group('LibraryFilterModelMerge.mergeEnabledFrom', () {
    test('applies enabled entries from the incoming filter without dropping the known universe', () {
      const known = LibraryFilterModel(
        genres: {'Action': false, 'Comedy': false},
        tags: {'A24': false, 'Marvel': false},
        years: {1999: false, 2020: false},
        officialRatings: {'PG-13': false, 'R': false},
      );
      const incoming = LibraryFilterModel(
        genres: {'Action': true},
        tags: {'A24': true},
        years: {2020: true},
        officialRatings: {'R': true},
      );

      final merged = known.mergeEnabledFrom(incoming);

      expect(merged.genres, {'Action': true, 'Comedy': false});
      expect(merged.tags, {'A24': true, 'Marvel': false});
      expect(merged.years, {1999: false, 2020: true});
      expect(merged.officialRatings, {'PG-13': false, 'R': true});
    });

    test('merges enabled studios by matching the studio object, not just id text', () {
      final a24 = Studio(id: 's1', name: 'A24');
      final marvel = Studio(id: 's2', name: 'Marvel');
      final known = LibraryFilterModel(studios: {a24: false, marvel: false});
      final incoming = LibraryFilterModel(studios: {a24: true});

      final merged = known.mergeEnabledFrom(incoming);

      expect(merged.studios, {a24: true, marvel: false});
    });

    test('defaults recursive to true and favourites to false when the incoming filter leaves them unset', () {
      const known = LibraryFilterModel(recursive: false, favourites: true);
      const incoming = LibraryFilterModel();

      final merged = known.mergeEnabledFrom(incoming);

      expect(merged.recursive, isTrue);
      expect(merged.favourites, isFalse);
    });
  });
}
