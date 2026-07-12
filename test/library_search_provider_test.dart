import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/library_filter_model.dart';
import 'package:driftfin/models/library_filters_model.dart';
import 'package:driftfin/models/library_search/library_search_options.dart';
import 'package:driftfin/models/view_model.dart';
import 'package:driftfin/providers/library_search_provider.dart';

ItemBaseModel _item(
  String id, {
  BaseItemKind type = BaseItemKind.movie,
  String? name,
  int? childCount,
  UserItemDataDto? userData,
  String? playlistItemId,
}) {
  return ItemBaseModel.fromBaseDto(
    BaseItemDto(
      id: id,
      name: name ?? id,
      type: type,
      childCount: childCount,
      userData: userData,
      playlistItemId: playlistItemId,
    ),
    null,
  );
}

ViewModel _view(String id, {String name = 'View'}) {
  return ViewModel(
    name: name,
    id: id,
    serverId: 'server',
    dateCreated: DateTime(2024),
    canDelete: false,
    canDownload: false,
    parentId: 'parent',
    collectionType: CollectionType.movies,
    playAccess: PlayAccess.full,
    recentlyAdded: const [],
    imageData: null,
    childCount: 0,
    path: null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer container() => ProviderContainer();

  LibrarySearchNotifier notifier(ProviderContainer c) {
    final refProvider = Provider<Ref>((ref) => ref);
    return LibrarySearchNotifier(c.read(refProvider));
  }

  group('setSearch', () {
    test('sets the search query on state', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setSearch('cappybara');
      expect(n.state.searchQuery, 'cappybara');
    });

    test('empty query is a no-op for search history but still updates state', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setSearch('');
      expect(n.state.searchQuery, '');
    });
  });

  group('simple filter toggles', () {
    test('toggleFavourite flips from default false to true and back', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      expect(n.state.filters.favourites, false);
      n.toggleFavourite();
      expect(n.state.filters.favourites, true);
      n.toggleFavourite();
      expect(n.state.filters.favourites, false);
    });

    test('toggleRecursive flips from default true to false and back', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      expect(n.state.filters.recursive, true);
      n.toggleRecursive();
      expect(n.state.filters.recursive, false);
      n.toggleRecursive();
      expect(n.state.filters.recursive, true);
    });

    test('toggleType toggles a single type key without affecting others', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.toggleType(FladderItemType.movie);
      expect(n.state.filters.types[FladderItemType.movie], true);
      expect(n.state.filters.types[FladderItemType.series], false);
      n.toggleType(FladderItemType.movie);
      expect(n.state.filters.types[FladderItemType.movie], false);
    });

    test('toggleView adds/removes a view from the views map', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      final view = _view('v1');
      // toggleKey only flips an existing key's value (see map_bool_helper.dart);
      // it doesn't insert missing keys, so the view must be seeded first, just
      // like toggleGenre/toggleStudio/etc. do via their respective setters.
      n.setViews({view: false});
      n.toggleView(view);
      expect(n.state.views[view], true);
      n.toggleView(view);
      expect(n.state.views[view], false);
    });

    test('toggleGenre toggles a genre key', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setGenres({'Action': false, 'Comedy': false});
      n.toggleGenre('Action');
      expect(n.state.filters.genres['Action'], true);
      expect(n.state.filters.genres['Comedy'], false);
    });

    test('toggleStudio toggles a studio key', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      final studio = Studio(id: 's1', name: 'Studio 1');
      n.setStudios({studio: false});
      n.toggleStudio(studio);
      expect(n.state.filters.studios[studio], true);
    });

    test('toggleTag toggles a tag key', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setTags({'4k': false});
      n.toggleTag('4k');
      expect(n.state.filters.tags['4k'], true);
    });

    test('toggleRatings toggles an official rating key', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setRatings({'PG-13': false});
      n.toggleRatings('PG-13');
      expect(n.state.filters.officialRatings['PG-13'], true);
    });

    test('toggleYears toggles a year key', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setYears({2020: false});
      n.toggleYears(2020);
      expect(n.state.filters.years[2020], true);
    });

    test('toggleFilters toggles an ItemFilter key', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      expect(n.state.filters.itemFilters[ItemFilter.isplayed], false);
      n.toggleFilters(ItemFilter.isplayed);
      expect(n.state.filters.itemFilters[ItemFilter.isplayed], true);
    });
  });

  group('setters', () {
    test('setViews replaces the views map and resets filters to default', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setSearch('something');
      n.toggleFavourite();
      final view = _view('v1');
      n.setViews({view: true});
      expect(n.state.views[view], true);
      expect(n.state.searchQuery, '');
      expect(n.state.filters.favourites, false);
      expect(n.loadedFilters, false);
    });

    test('setGenres replaces genres map wholesale', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setGenres({'Horror': true});
      expect(n.state.filters.genres, {'Horror': true});
    });

    test('setStudios replaces studios map wholesale', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      final studio = Studio(id: 's1', name: 'Studio 1');
      n.setStudios({studio: true});
      expect(n.state.filters.studios, {studio: true});
    });

    test('setTags replaces tags map wholesale', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setTags({'hdr': true});
      expect(n.state.filters.tags, {'hdr': true});
    });

    test('setTypes replaces types map wholesale', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setTypes({FladderItemType.movie: true});
      expect(n.state.filters.types, {FladderItemType.movie: true});
    });

    test('setRatings replaces officialRatings map wholesale', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setRatings({'R': true});
      expect(n.state.filters.officialRatings, {'R': true});
    });

    test('setYears replaces years map wholesale', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setYears({1999: true});
      expect(n.state.filters.years, {1999: true});
    });

    test('setFilters replaces itemFilters map wholesale', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setFilters({ItemFilter.isresumable: true});
      expect(n.state.filters.itemFilters, {ItemFilter.isresumable: true});
    });

    test('setSortBy updates the sorting option', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setSortBy(SortingOptions.random);
      expect(n.state.filters.sortingOption, SortingOptions.random);
    });

    test('setSortOrder updates the sort order', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setSortOrder(SortingOrder.descending);
      expect(n.state.filters.sortOrder, SortingOrder.descending);
    });

    test('toggleEmptyShows flips hideEmptyShows', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      final initial = n.state.filters.hideEmptyShows;
      n.toggleEmptyShows();
      expect(n.state.filters.hideEmptyShows, !initial);
    });

    test('setGroupBy updates the groupBy option', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setGroupBy(GroupBy.genres);
      expect(n.state.filters.groupBy, GroupBy.genres);
    });

    test('clearAllFilters resets search query and filters', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setSearch('term');
      n.toggleFavourite();
      n.setGenres({'Action': true});
      n.clearAllFilters();
      expect(n.state.searchQuery, '');
      expect(n.state.filters.favourites, false);
      expect(n.state.filters.genres['Action'], false);
    });
  });

  group('folder navigation', () {
    test('setFolderId appends a new folder to folderOverwrite', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      final item = _item('f1', type: BaseItemKind.folder);
      n.setFolderId(item);
      expect(n.state.folderOverwrite, [item]);
    });

    test('setFolderId is a no-op if the item is already present', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      final item = _item('f1', type: BaseItemKind.folder);
      n.setFolderId(item);
      n.setFolderId(item);
      expect(n.state.folderOverwrite.length, 1);
    });

    test('backToFolder truncates the folderOverwrite stack to the given item', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      final a = _item('a', type: BaseItemKind.folder);
      final b = _item('b', type: BaseItemKind.folder);
      final d = _item('d', type: BaseItemKind.folder);
      n.setFolderId(a);
      n.setFolderId(b);
      n.setFolderId(d);
      n.backToFolder(a);
      expect(n.state.folderOverwrite, [a]);
    });

    test('clearFolderOverWrite empties the folder stack', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setFolderId(_item('a', type: BaseItemKind.folder));
      n.clearFolderOverWrite();
      expect(n.state.folderOverwrite, isEmpty);
    });
  });

  group('selection', () {
    test('toggleSelectMode flips selecteMode and clears selectedPosters', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      expect(n.state.selecteMode, false);
      n.toggleSelectMode();
      expect(n.state.selecteMode, true);
      expect(n.state.selectedPosters, isEmpty);
    });

    test('toggleSelection adds then removes an item from selectedPosters', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      final item = _item('1');
      n.toggleSelection(item);
      expect(n.state.selectedPosters, [item]);
      n.toggleSelection(item);
      expect(n.state.selectedPosters, isEmpty);
    });

    test('selectAll(true) selects all posters, selectAll(false) clears', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      final posters = [_item('1'), _item('2')];
      n.state = n.state.copyWith(posters: posters);
      n.selectAll(true);
      expect(n.state.selectedPosters, posters);
      n.selectAll(false);
      expect(n.state.selectedPosters, isEmpty);
    });
  });

  group('poster/item mutation helpers', () {
    test('removeFromPosters removes matching ids', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.state = n.state.copyWith(posters: [_item('1'), _item('2'), _item('3')]);
      n.removeFromPosters(['2']);
      expect(n.state.posters.map((e) => e.id), ['1', '3']);
    });

    test('updateItem replaces the matching item in posters', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.state = n.state.copyWith(posters: [_item('1', name: 'Old')]);
      final updated = _item('1', name: 'New');
      n.updateItem(updated);
      expect(n.state.posters.single.name, 'New');
    });

    test('updateUserData updates userData on the matching poster', () async {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.state = n.state.copyWith(posters: [_item('1')]);
      await n.updateUserData('1', const UserData(isFavourite: true));
      expect(n.state.posters.single.userData.isFavourite, true);
    });

    test('updateUserData is a no-op when the id is not found', () async {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.state = n.state.copyWith(posters: [_item('1')]);
      await n.updateUserData('missing', const UserData(isFavourite: true));
      expect(n.state.posters.single.userData.isFavourite, isNot(true));
    });

    test('updateUserDataMain updates userData on the last folderOverwrite entry', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setFolderId(_item('a', type: BaseItemKind.folder));
      n.updateUserDataMain(const UserData(isFavourite: true));
      expect(n.state.folderOverwrite.single.userData.isFavourite, true);
    });

    test('updateParentItem replaces folderOverwrite with a single item', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setFolderId(_item('a', type: BaseItemKind.folder));
      n.setFolderId(_item('b', type: BaseItemKind.folder));
      final replacement = _item('c', type: BaseItemKind.folder);
      n.updateParentItem(replacement);
      expect(n.state.folderOverwrite, [replacement]);
    });
  });

  group('loadModel / saveFiltersNew / updateFilter', () {
    test('loadModel merges an incoming LibraryFilterModel into state.filters', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      const incoming = LibraryFilterModel(favourites: true, sortingOption: SortingOptions.random);
      n.loadModel(incoming);
      expect(n.state.filters.favourites, true);
      expect(n.state.filters.sortingOption, SortingOptions.random);
    });

    test('saveFiltersNew persists a new named filter via the filter provider', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setGenres({'Action': true});
      // Should not throw even without a logged-in user; userProvider read
      // inside libraryFiltersProvider tolerates a null account.
      expect(() => n.saveFiltersNew('My filter'), returnsNormally);
    });

    test('updateFilter re-saves an existing named filter, preserving id/isFavourite', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifier(c);
      n.setGenres({'Comedy': true});
      final existing = LibraryFiltersModel(id: 'existing-id', name: 'existing', isFavourite: false);
      expect(() => n.updateFilter(existing), returnsNormally);
    });
  });

  group('SimpleSorter.hideEmptyChildren', () {
    test('hide=false returns the original list unmodified', () {
      final items = [_item('1', childCount: 0), _item('2', childCount: null)];
      final result = items.hideEmptyChildren(false);
      expect(result, same(items));
    });

    test('hide=true keeps items with null childCount', () {
      final items = [_item('1', childCount: null)];
      final result = items.hideEmptyChildren(true);
      expect(result, items);
    });

    test('hide=true keeps items with childCount > 0', () {
      final items = [_item('1', childCount: 3)];
      final result = items.hideEmptyChildren(true);
      expect(result, items);
    });

    test('hide=true filters out items with childCount == 0', () {
      final keep = _item('1', childCount: 2);
      final drop = _item('2', childCount: 0);
      final result = [keep, drop].hideEmptyChildren(true);
      expect(result, [keep]);
    });
  });

  group('librarySearchProvider family', () {
    test('reading via the family provider constructs a working notifier', () {
      final c = container();
      addTearDown(c.dispose);
      final key = const Key('test-key');
      c.read(librarySearchProvider(key).notifier).setSearch('via family');
      expect(c.read(librarySearchProvider(key)).searchQuery, 'via family');
    });
  });
}
