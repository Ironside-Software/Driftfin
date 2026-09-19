import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart' as dto;
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/items/overview_model.dart';
import 'package:driftfin/models/library_search/library_search_options.dart';
import 'package:flutter_test/flutter_test.dart';

ItemBaseModel _item({
  String name = '',
  double? communityRating,
  bool isFavourite = false,
  DateTime? lastPlayed,
  int playCount = 0,
  int? productionYear,
  Duration? runTime,
}) =>
    ItemBaseModel(
      name: name,
      id: name,
      overview: OverviewModel(
        communityRating: communityRating,
        productionYear: productionYear,
        runTime: runTime,
      ),
      parentId: null,
      playlistId: null,
      images: null,
      childCount: null,
      primaryRatio: null,
      userData: UserData(
        isFavourite: isFavourite,
        lastPlayed: lastPlayed,
        playCount: playCount,
      ),
      canDownload: null,
      canDelete: null,
      jellyType: null,
    );

void main() {
  group('SortingOptions.toSortBy', () {
    test('always appends a trailing sortname and name tie-breaks', () {
      expect(SortingOptions.communityRating.toSortBy,
          [dto.ItemSortBy.communityrating, dto.ItemSortBy.sortname, dto.ItemSortBy.name]);
    });

    test('sortName itself ends up with a duplicated sortname entry before name', () {
      expect(SortingOptions.sortName.toSortBy,
          [dto.ItemSortBy.sortname, dto.ItemSortBy.name, dto.ItemSortBy.sortname, dto.ItemSortBy.name]);
    });

    test('multi-key options (releaseDate) keep both underlying keys plus the tie-break', () {
      expect(
        SortingOptions.releaseDate.toSortBy,
        [dto.ItemSortBy.productionyear, dto.ItemSortBy.premieredate, dto.ItemSortBy.sortname, dto.ItemSortBy.name],
      );
    });
  });

  group('SortingOrder.sortOrder', () {
    test('maps 1:1 to the dto SortOrder enum', () {
      expect(SortingOrder.ascending.sortOrder, dto.SortOrder.ascending);
      expect(SortingOrder.descending.sortOrder, dto.SortOrder.descending);
    });
  });

  group('ItemFilterExtension.label coverage', () {
    test('only isplayed/isunplayed/isresumable are documented as having real (non-fallback) labels', () {
      const handled = {dto.ItemFilter.isplayed, dto.ItemFilter.isunplayed, dto.ItemFilter.isresumable};
      const allValues = dto.ItemFilter.values;
      final unhandled = allValues.where((v) => !handled.contains(v)).toList();
      expect(unhandled, isNotEmpty, reason: 'sanity check: there exist ItemFilter values with no explicit label');
      expect(unhandled.contains(dto.ItemFilter.isfavorite), isTrue);
    });
  });

  group('sortItems', () {
    test('communityRating: missing rating defaults to 0', () {
      final a = _item(name: 'a', communityRating: null);
      final b = _item(name: 'b', communityRating: 5.0);
      expect(sortItems(a, b, SortingOptions.communityRating, SortingOrder.ascending) < 0, isTrue);
      expect(sortItems(a, b, SortingOptions.communityRating, SortingOrder.descending) > 0, isTrue);
    });

    test('isFavoriteOrLiked: favourites sort after non-favourites in ascending order', () {
      final nonFav = _item(name: 'a', isFavourite: false);
      final fav = _item(name: 'b', isFavourite: true);
      expect(sortItems(nonFav, fav, SortingOptions.favorite, SortingOrder.ascending) < 0, isTrue);
    });

    test('dateplayed: never-played (null) sorts as epoch, before any real lastPlayed date', () {
      final neverPlayed = _item(name: 'a', lastPlayed: null);
      final playedRecently = _item(name: 'b', lastPlayed: DateTime(2024));
      expect(sortItems(neverPlayed, playedRecently, SortingOptions.datePlayed, SortingOrder.ascending) < 0, isTrue);
    });

    test('playCount: direct integer comparison', () {
      final low = _item(name: 'a', playCount: 1);
      final high = _item(name: 'b', playCount: 10);
      expect(sortItems(low, high, SortingOptions.playCount, SortingOrder.ascending) < 0, isTrue);
    });

    test('releaseDate: premieredate case reuses productionYear (not a separate field)', () {
      final older = _item(name: 'a', productionYear: 2000);
      final newer = _item(name: 'b', productionYear: 2020);
      expect(sortItems(older, newer, SortingOptions.releaseDate, SortingOrder.ascending) < 0, isTrue);
    });

    test('runtime: missing runtime defaults to Duration.zero', () {
      final noRuntime = _item(name: 'a', runTime: null);
      final withRuntime = _item(name: 'b', runTime: const Duration(hours: 2));
      expect(sortItems(noRuntime, withRuntime, SortingOptions.runTime, SortingOrder.ascending) < 0, isTrue);
    });

    test('default (e.g. sortName) falls back to comparing item name', () {
      final a = _item(name: 'Alpha');
      final b = _item(name: 'Zulu');
      expect(sortItems(a, b, SortingOptions.sortName, SortingOrder.ascending) < 0, isTrue);
      expect(sortItems(a, b, SortingOptions.sortName, SortingOrder.descending) > 0, isTrue);
    });

    test('ties on the primary key fall through to the trailing name tie-break', () {
      final a = _item(name: 'Alpha', communityRating: 5.0);
      final b = _item(name: 'Zulu', communityRating: 5.0);
      expect(sortItems(a, b, SortingOptions.communityRating, SortingOrder.ascending) < 0, isTrue);
    });

    test('fully equal items return 0', () {
      final a = _item(name: 'same');
      final b = _item(name: 'same');
      expect(sortItems(a, b, SortingOptions.communityRating, SortingOrder.ascending), 0);
    });
  });
}
