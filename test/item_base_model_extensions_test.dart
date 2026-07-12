import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/episode_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/items/media_streams_model.dart';
import 'package:driftfin/models/items/movie_model.dart';
import 'package:driftfin/models/items/overview_model.dart';
import 'package:driftfin/models/items/series_model.dart';
import 'package:driftfin/util/item_base_model/item_base_model_extensions.dart';
import 'package:flutter_test/flutter_test.dart';

ItemBaseModel _item(String id, {double? primaryRatio}) => ItemBaseModel(
      name: id,
      id: id,
      overview: const OverviewModel(),
      parentId: null,
      playlistId: null,
      images: null,
      childCount: null,
      primaryRatio: primaryRatio,
      userData: const UserData(),
      canDownload: null,
      canDelete: null,
      jellyType: null,
    );

EpisodeModel _episode(String id) => EpisodeModel(
      name: id,
      id: id,
      overview: const OverviewModel(),
      parentId: null,
      playlistId: null,
      images: null,
      childCount: null,
      primaryRatio: null,
      userData: const UserData(),
      parentImages: null,
      mediaStreams: MediaStreamsModel(versionStreams: const []),
      canDownload: null,
      canDelete: null,
      seriesName: null,
      season: 1,
      episode: 1,
      episodeEnd: null,
    );

MovieModel _movie(String id, {Map<String, dynamic>? providerIds}) => MovieModel(
      originalTitle: id,
      premiereDate: DateTime(2020),
      sortName: id,
      status: '',
      providerIds: providerIds,
      name: id,
      id: id,
      overview: const OverviewModel(),
      parentId: null,
      playlistId: null,
      images: null,
      childCount: null,
      primaryRatio: null,
      userData: const UserData(),
      parentImages: null,
      mediaStreams: MediaStreamsModel(versionStreams: const []),
      canDownload: null,
      canDelete: null,
    );

SeriesModel _series(String id, {Map<String, dynamic>? providerIds}) => SeriesModel(
      originalTitle: id,
      sortName: id,
      status: '',
      providerIds: providerIds,
      name: id,
      id: id,
      overview: const OverviewModel(),
      parentId: null,
      playlistId: null,
      images: null,
      childCount: null,
      primaryRatio: null,
      userData: const UserData(),
    );

void main() {
  group('ItemBaseModelsBooleans.groupedItems', () {
    test('groups items by their FladderItemType', () {
      final items = [_item('a'), _movie('m'), _series('s'), _item('b')];
      final grouped = items.groupedItems;

      expect(grouped[FladderItemType.baseType]?.map((e) => e.id).toList(), ['a', 'b']);
      expect(grouped[FladderItemType.movie]?.map((e) => e.id).toList(), ['m']);
      expect(grouped[FladderItemType.series]?.map((e) => e.id).toList(), ['s']);
    });

    test('is empty for an empty list', () {
      expect(<ItemBaseModel>[].groupedItems, isEmpty);
    });
  });

  group('ItemBaseModelsBooleans.getMostCommonType', () {
    test('returns movie for an empty list (documented default)', () {
      expect(<ItemBaseModel>[].getMostCommonType, FladderItemType.movie);
    });

    test('returns the type with the most occurrences', () {
      final items = [_movie('m1'), _movie('m2'), _series('s1')];
      expect(items.getMostCommonType, FladderItemType.movie);
    });

    test('ties break toward whichever type is reduced-first (documented behavior)', () {
      final items = [_movie('m1'), _series('s1')];
      // reduce() keeps `a` on a tie (a.value >= b.value), i.e. the first-seen type.
      expect(items.getMostCommonType, FladderItemType.movie);
    });
  });

  group('ItemBaseModelsBooleans.getMostCommonAspectRatio', () {
    test('returns null when no item has an aspect ratio', () {
      final items = [_item('a'), _item('b')];
      expect(items.getMostCommonAspectRatio(), isNull);
    });

    test('averages ratios that fall within the same tolerance bucket', () {
      final items = [
        _item('a', primaryRatio: 1.500),
        _item('b', primaryRatio: 1.501),
        _item('c', primaryRatio: 0.667), // a distinct, less common bucket
      ];
      final result = items.getMostCommonAspectRatio(tolerance: 0.01);
      expect(result, closeTo(1.5005, 0.001));
    });

    test('items with a null ratio are ignored', () {
      final items = [_item('a', primaryRatio: 2.0), _item('b')];
      expect(items.getMostCommonAspectRatio(), 2.0);
    });
  });

  group('tmdbId / tvdbId', () {
    test('parses the Tmdb provider id for a movie', () {
      final movie = _movie('m', providerIds: {'Tmdb': '12345'});
      expect(movie.tmdbId, 12345);
    });

    test('parses the Tvdb provider id for a series', () {
      final series = _series('s', providerIds: {'Tvdb': '999'});
      expect(series.tvdbId, 999);
    });

    test('is null when providerIds is missing or empty', () {
      expect(_movie('m').tmdbId, isNull);
      expect(_movie('m', providerIds: const {}).tmdbId, isNull);
    });

    test('is null when the id cannot be parsed as an int', () {
      final movie = _movie('m', providerIds: {'Tmdb': 'not-a-number'});
      expect(movie.tmdbId, isNull);
    });

    test('is null for item types without provider ids (e.g. plain episodes)', () {
      final episode = _episode('e');
      expect(episode.tmdbId, isNull);
      expect(episode.tvdbId, isNull);
    });
  });
}
