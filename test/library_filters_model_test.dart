import 'package:driftfin/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:driftfin/models/library_filter_model.dart';
import 'package:driftfin/models/library_filters_model.dart';
import 'package:driftfin/models/library_search/library_search_model.dart';
import 'package:driftfin/models/view_model.dart';
import 'package:flutter_test/flutter_test.dart';

ViewModel _view(String id) => ViewModel(
      name: 'View $id',
      id: id,
      serverId: 'server',
      dateCreated: DateTime(2020),
      canDelete: false,
      canDownload: false,
      parentId: '',
      collectionType: CollectionType.movies,
      playAccess: PlayAccess.full,
      recentlyAdded: const [],
      imageData: null,
      childCount: 0,
      path: null,
    );

void main() {
  group('LibraryFiltersModel.fromLibrarySearch', () {
    test('uses only included (enabled) view ids', () {
      final v1 = _view('v1');
      final v2 = _view('v2');
      final searchModel = LibrarySearchModel(
        views: {v1: true, v2: false},
        filters: const LibraryFilterModel(),
      );
      final result = LibraryFiltersModel.fromLibrarySearch('Saved', searchModel);
      expect(result.ids, ['v1']);
      expect(result.name, 'Saved');
      expect(result.isFavourite, isFalse);
    });

    test('generates a non-empty id when none is provided', () {
      final searchModel = const LibrarySearchModel(views: {}, filters: LibraryFilterModel());
      final result = LibraryFiltersModel.fromLibrarySearch('Saved', searchModel);
      expect(result.id, isNotEmpty);
    });

    test('uses the provided id/isFavourite when given', () {
      final searchModel = const LibrarySearchModel(views: {}, filters: LibraryFilterModel());
      final result =
          LibraryFiltersModel.fromLibrarySearch('Saved', searchModel).copyWith(id: 'explicit-id', isFavourite: true);
      expect(result.id, 'explicit-id');
      expect(result.isFavourite, isTrue);
    });

    test('carries over the filter from the search model', () {
      const filter = LibraryFilterModel(favourites: true);
      final searchModel = const LibrarySearchModel(filters: filter);
      final result = LibraryFiltersModel.fromLibrarySearch('Saved', searchModel);
      expect(result.filter, filter);
    });
  });

  group('LibraryFiltersModel.showOnHome', () {
    test('defaults to false so existing saved filters do not appear as smart shelves', () {
      final model = LibraryFiltersModel(id: 'x', name: 'x', isFavourite: false);
      expect(model.showOnHome, isFalse);
    });

    test('can be toggled independently of isFavourite', () {
      final model = LibraryFiltersModel(id: 'x', name: 'x', isFavourite: true, showOnHome: true);
      expect(model.showOnHome, isTrue);
      expect(model.isFavourite, isTrue);
    });
  });

  group('LibraryFiltersModel.containsSameIds', () {
    test('true for the same set of ids regardless of order', () {
      final model = LibraryFiltersModel(id: 'x', name: 'x', isFavourite: false, ids: ['a', 'b']);
      expect(model.containsSameIds(['b', 'a']), isTrue);
    });

    test('false when lengths differ', () {
      final model = LibraryFiltersModel(id: 'x', name: 'x', isFavourite: false, ids: ['a']);
      expect(model.containsSameIds(['a', 'b']), isFalse);
    });

    test('empty lists are considered the same', () {
      final model = LibraryFiltersModel(id: 'x', name: 'x', isFavourite: false, ids: const []);
      expect(model.containsSameIds(const []), isTrue);
    });

    test(
      'duplicate elements can produce a false positive: differently-shaped lists of equal length '
      'are reported as matching (set-membership, not multiset equality)',
      () {
        final model = LibraryFiltersModel(id: 'x', name: 'x', isFavourite: false, ids: ['a', 'b']);
        // ids=['a','b'] vs otherIds=['a','a']: same length (2), and Set({'a','b'}).containsAll(['a','a']) is true,
        // even though ['a','a'] is not the same multiset as ['a','b'].
        expect(model.containsSameIds(['a', 'a']), isTrue);
      },
    );

    test('correctly returns false for genuinely different id sets of the same length', () {
      final model = LibraryFiltersModel(id: 'x', name: 'x', isFavourite: false, ids: ['a', 'a']);
      expect(model.containsSameIds(['a', 'b']), isFalse);
    });
  });
}
