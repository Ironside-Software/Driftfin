import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/items/overview_model.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/service_provider.dart';
import 'package:driftfin/providers/taste_passport_provider.dart';

Response<T> _ok<T>(T body) => Response<T>(http.Response('', 200), body);

ItemBaseModel _item(String id, {List<String> genres = const [], Duration? runTime, int playCount = 1}) {
  return ItemBaseModel(
    name: id,
    id: id,
    overview: OverviewModel(genres: genres, runTime: runTime),
    parentId: null,
    playlistId: null,
    images: null,
    childCount: null,
    primaryRatio: null,
    userData: UserData(played: true, playCount: playCount),
    canDownload: null,
    canDelete: null,
    jellyType: null,
  );
}

ServerQueryResult _queryResult(List<ItemBaseModel> items) =>
    ServerQueryResult(items: items, totalRecordCount: items.length, startIndex: 0);

/// Canned watched-items response for [TastePassportNotifier.fetchProfile].
class _FakeTastePassportJellyService extends JellyService {
  _FakeTastePassportJellyService(Ref ref, {this.watched = const []}) : super(ref, JellyfinOpenApi.create());

  final List<ItemBaseModel> watched;
  int itemsGetCalls = 0;
  List<ItemFilter>? lastFilters;
  List<BaseItemKind>? lastIncludeItemTypes;

  @override
  Future<Response<ServerQueryResult>> itemsGet({
    String? maxOfficialRating,
    bool? hasThemeSong,
    bool? hasThemeVideo,
    bool? hasSubtitles,
    bool? hasSpecialFeature,
    bool? hasTrailer,
    String? adjacentTo,
    int? parentIndexNumber,
    bool? hasParentalRating,
    bool? isHd,
    bool? is4K,
    List<LocationType>? locationTypes,
    List<LocationType>? excludeLocationTypes,
    bool? isMissing,
    bool? isUnaired,
    num? minCommunityRating,
    num? minCriticRating,
    DateTime? minPremiereDate,
    DateTime? minDateLastSaved,
    DateTime? minDateLastSavedForUser,
    DateTime? maxPremiereDate,
    bool? hasOverview,
    bool? hasImdbId,
    bool? hasTmdbId,
    bool? hasTvdbId,
    bool? isMovie,
    bool? isSeries,
    bool? isNews,
    bool? isKids,
    bool? isSports,
    List<String>? excludeItemIds,
    int? startIndex,
    int? limit,
    bool? recursive,
    String? searchTerm,
    List<SortOrder>? sortOrder,
    String? parentId,
    List<ItemFields>? fields,
    List<BaseItemKind>? excludeItemTypes,
    List<BaseItemKind>? includeItemTypes,
    List<ItemFilter>? filters,
    bool? isFavorite,
    List<MediaType>? mediaTypes,
    List<ImageType>? imageTypes,
    List<ItemSortBy>? sortBy,
    bool? isPlayed,
    List<String>? genres,
    List<String>? officialRatings,
    List<String>? tags,
    List<int>? years,
    bool? enableUserData,
    int? imageTypeLimit,
    List<ImageType>? enableImageTypes,
    String? person,
    List<String>? personIds,
    List<String>? personTypes,
    List<String>? studios,
    List<String>? artists,
    List<String>? excludeArtistIds,
    List<String>? artistIds,
    List<String>? albumArtistIds,
    List<String>? contributingArtistIds,
    List<String>? albums,
    List<String>? albumIds,
    List<String>? ids,
    List<VideoType>? videoTypes,
    String? minOfficialRating,
    bool? isLocked,
    bool? isPlaceHolder,
    bool? hasOfficialRating,
    bool? collapseBoxSetItems,
    int? minWidth,
    int? minHeight,
    int? maxWidth,
    int? maxHeight,
    bool? is3D,
    List<SeriesStatus>? seriesStatus,
    String? nameStartsWithOrGreater,
    String? nameStartsWith,
    String? nameLessThan,
    List<String>? studioIds,
    List<String>? genreIds,
    bool? enableTotalRecordCount,
    bool? enableImages,
  }) async {
    itemsGetCalls++;
    lastFilters = filters;
    lastIncludeItemTypes = includeItemTypes;
    return _ok(_queryResult(watched));
  }
}

class _FakeJellyApi extends JellyApi {
  _FakeJellyApi({this.watched = const []});

  final List<ItemBaseModel> watched;
  late final _FakeTastePassportJellyService service;

  @override
  JellyService build() {
    service = _FakeTastePassportJellyService(ref, watched: watched);
    return service;
  }
}

ProviderContainer _containerWith(_FakeJellyApi fakeApi) {
  return ProviderContainer(overrides: [jellyApiProvider.overrideWith(() => fakeApi)]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('aggregates watched items into a taste profile', () async {
    final fakeApi = _FakeJellyApi(watched: [
      _item('1', genres: const ['Comedy'], runTime: const Duration(minutes: 30)),
      _item('2', genres: const ['Comedy', 'Drama'], runTime: const Duration(minutes: 45)),
    ]);
    final container = _containerWith(fakeApi);
    addTearDown(container.dispose);

    await container.read(tastePassportProvider.notifier).fetchProfile();

    final state = container.read(tastePassportProvider);
    expect(state.loading, isFalse);
    expect(state.itemsWatched, 2);
    expect(state.topGenres.first.key, 'Comedy');
    expect(state.totalWatchTime, const Duration(minutes: 75));
    expect(state.generatedAt, isNotNull);
  });

  test('queries only played movies and episodes', () async {
    final fakeApi = _FakeJellyApi();
    final container = _containerWith(fakeApi);
    addTearDown(container.dispose);

    await container.read(tastePassportProvider.notifier).fetchProfile();

    expect(fakeApi.service.lastFilters, contains(ItemFilter.isplayed));
    expect(fakeApi.service.lastIncludeItemTypes, containsAll([BaseItemKind.movie, BaseItemKind.episode]));
  });

  test('an empty watch history yields a zeroed-out profile', () async {
    final fakeApi = _FakeJellyApi();
    final container = _containerWith(fakeApi);
    addTearDown(container.dispose);

    await container.read(tastePassportProvider.notifier).fetchProfile();

    final state = container.read(tastePassportProvider);
    expect(state.hasData, isFalse);
    expect(state.itemsWatched, 0);
    expect(state.totalWatchTime, Duration.zero);
  });

  test('fetchProfile is a no-op re-entrancy guard while already loading', () async {
    final fakeApi = _FakeJellyApi(watched: [_item('1')]);
    final container = _containerWith(fakeApi);
    addTearDown(container.dispose);

    final notifier = container.read(tastePassportProvider.notifier);
    await Future.wait([notifier.fetchProfile(), notifier.fetchProfile()]);

    expect(fakeApi.service.itemsGetCalls, 1);
  });

  test('clear resets to the default model', () async {
    final fakeApi = _FakeJellyApi(watched: [_item('1')]);
    final container = _containerWith(fakeApi);
    addTearDown(container.dispose);
    final notifier = container.read(tastePassportProvider.notifier);

    await notifier.fetchProfile();
    notifier.clear();

    final state = container.read(tastePassportProvider);
    expect(state.hasData, isFalse);
    expect(state.itemsWatched, 0);
  });
}
