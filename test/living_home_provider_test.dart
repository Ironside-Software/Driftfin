import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/items/overview_model.dart';
import 'package:driftfin/models/living_home_model.dart';
import 'package:driftfin/models/recommended_model.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/living_home_provider.dart';
import 'package:driftfin/providers/service_provider.dart';

Response<T> _ok<T>(T body) => Response<T>(http.Response('', 200), body);

ItemBaseModel _item(
  String id, {
  bool favourite = false,
  bool played = false,
  double? communityRating,
  List<Person> people = const [],
}) {
  return ItemBaseModel(
    name: id,
    id: id,
    overview: OverviewModel(communityRating: communityRating, people: people),
    parentId: null,
    playlistId: null,
    images: null,
    childCount: null,
    primaryRatio: null,
    userData: UserData(isFavourite: favourite, played: played),
    canDownload: null,
    canDelete: null,
    jellyType: null,
  );
}

ServerQueryResult _queryResult(List<ItemBaseModel> items) =>
    ServerQueryResult(items: items, totalRecordCount: items.length, startIndex: 0);

/// Canned Jellyfin responses for [LivingHomeNotifier.fetchRails], keyed by
/// which of the three fan-out calls is being made (favourite taste sample,
/// played-fallback taste sample, per-director lookup, hidden-gems pool).
class _FakeLivingHomeJellyService extends JellyService {
  _FakeLivingHomeJellyService(
    Ref ref, {
    this.favouriteSample = const [],
    this.playedSample = const [],
    this.byDirectorId = const {},
    this.hiddenGemsCandidates = const [],
    this.similarByItemId = const {},
  }) : super(ref, JellyfinOpenApi.create());

  final List<ItemBaseModel> favouriteSample;
  final List<ItemBaseModel> playedSample;
  final Map<String, List<ItemBaseModel>> byDirectorId;
  final List<ItemBaseModel> hiddenGemsCandidates;
  final Map<String, List<BaseItemDto>> similarByItemId;

  int itemsGetCalls = 0;
  int similarCalls = 0;

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
    if (personIds != null && personIds.isNotEmpty) {
      return _ok(_queryResult(byDirectorId[personIds.first] ?? const []));
    }
    if (sortBy?.contains(ItemSortBy.random) == true) {
      return _ok(_queryResult(hiddenGemsCandidates));
    }
    if (isFavorite == true) {
      return _ok(_queryResult(favouriteSample));
    }
    if (filters?.contains(ItemFilter.isplayed) == true) {
      return _ok(_queryResult(playedSample));
    }
    return _ok(_queryResult(const []));
  }

  @override
  Future<Response<BaseItemDtoQueryResult>> itemsItemIdSimilarGet({String? itemId, int? limit}) async {
    similarCalls++;
    final items = similarByItemId[itemId] ?? const <BaseItemDto>[];
    return _ok(BaseItemDtoQueryResult(items: items, totalRecordCount: items.length, startIndex: 0));
  }
}

class _FakeJellyApi extends JellyApi {
  _FakeJellyApi({
    this.favouriteSample = const [],
    this.playedSample = const [],
    this.byDirectorId = const {},
    this.hiddenGemsCandidates = const [],
    this.similarByItemId = const {},
  });

  final List<ItemBaseModel> favouriteSample;
  final List<ItemBaseModel> playedSample;
  final Map<String, List<ItemBaseModel>> byDirectorId;
  final List<ItemBaseModel> hiddenGemsCandidates;
  final Map<String, List<BaseItemDto>> similarByItemId;

  late final _FakeLivingHomeJellyService service;

  @override
  JellyService build() {
    service = _FakeLivingHomeJellyService(
      ref,
      favouriteSample: favouriteSample,
      playedSample: playedSample,
      byDirectorId: byDirectorId,
      hiddenGemsCandidates: hiddenGemsCandidates,
      similarByItemId: similarByItemId,
    );
    return service;
  }
}

ProviderContainer _containerWith(_FakeJellyApi fakeApi) {
  return ProviderContainer(overrides: [jellyApiProvider.overrideWith(() => fakeApi)]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a "because you watched" rail from a favourited seed', () async {
    final fakeApi = _FakeJellyApi(
      favouriteSample: [_item('seed-1', favourite: true)],
      similarByItemId: {
        'seed-1': [const BaseItemDto(id: 'similar-1', name: 'Similar', type: BaseItemKind.movie)],
      },
    );
    final container = _containerWith(fakeApi);
    addTearDown(container.dispose);

    await container.read(livingHomeProvider.notifier).fetchRails();

    final rails = container.read(livingHomeProvider).rails;
    expect(rails.any((r) => r.name is BecauseYouWatched), isTrue);
    expect(rails.firstWhere((r) => r.name is BecauseYouWatched).posters.map((e) => e.id), contains('similar-1'));
  });

  test('falls back to a played-history sample when there are no favourites', () async {
    final fakeApi = _FakeJellyApi(
      favouriteSample: const [],
      playedSample: [_item('seed-2', played: true)],
      similarByItemId: {
        'seed-2': [const BaseItemDto(id: 'similar-2', name: 'Similar', type: BaseItemKind.movie)],
      },
    );
    final container = _containerWith(fakeApi);
    addTearDown(container.dispose);

    await container.read(livingHomeProvider.notifier).fetchRails();

    final rails = container.read(livingHomeProvider).rails;
    expect(rails.firstWhere((r) => r.name is BecauseYouWatched).posters.map((e) => e.id), contains('similar-2'));
  });

  test('builds a "more from director" rail per favourite director', () async {
    final director = Person(id: 'd1', name: 'Denis Villeneuve', type: PersonKind.director);
    final fakeApi = _FakeJellyApi(
      favouriteSample: [
        _item('seed-1', favourite: true, people: [director])
      ],
      byDirectorId: {
        'd1': [_item('director-pick')],
      },
    );
    final container = _containerWith(fakeApi);
    addTearDown(container.dispose);

    await container.read(livingHomeProvider.notifier).fetchRails();

    final rails = container.read(livingHomeProvider).rails;
    final directorRail = rails.firstWhere((r) => r.name is MoreFromDirector);
    expect((directorRail.name as MoreFromDirector).directorName, 'Denis Villeneuve');
    expect(directorRail.posters.map((e) => e.id), contains('director-pick'));
  });

  test('builds a hidden-gems rail from unwatched, highly-rated candidates', () async {
    final fakeApi = _FakeJellyApi(
      hiddenGemsCandidates: [
        _item('gem-1', communityRating: 9, played: false),
        _item('watched-already', communityRating: 9, played: true),
      ],
    );
    final container = _containerWith(fakeApi);
    addTearDown(container.dispose);

    await container.read(livingHomeProvider.notifier).fetchRails();

    final rails = container.read(livingHomeProvider).rails;
    final gemsRail = rails.firstWhere((r) => r.name is HiddenGems);
    expect(gemsRail.posters.map((e) => e.id), ['gem-1']);
  });

  test('omits rails that end up with no posters', () async {
    final fakeApi = _FakeJellyApi();
    final container = _containerWith(fakeApi);
    addTearDown(container.dispose);

    await container.read(livingHomeProvider.notifier).fetchRails();

    expect(container.read(livingHomeProvider).rails, isEmpty);
  });

  test('fetchRails is a no-op re-entrancy guard while already loading', () async {
    final fakeApi = _FakeJellyApi(favouriteSample: [_item('seed-1', favourite: true)]);
    final container = _containerWith(fakeApi);
    addTearDown(container.dispose);

    final notifier = container.read(livingHomeProvider.notifier);
    await Future.wait([notifier.fetchRails(), notifier.fetchRails()]);

    expect(container.read(livingHomeProvider).lastFetched, isNotNull);
  });

  group('refreshIfStale', () {
    test('fetches when nothing has been fetched yet', () async {
      final fakeApi = _FakeJellyApi();
      final container = _containerWith(fakeApi);
      addTearDown(container.dispose);

      await container.read(livingHomeProvider.notifier).refreshIfStale();

      expect(container.read(livingHomeProvider).lastFetched, isNotNull);
    });

    test('skips fetching when the last fetch is still fresh', () async {
      final fakeApi = _FakeJellyApi();
      final container = _containerWith(fakeApi);
      addTearDown(container.dispose);
      final notifier = container.read(livingHomeProvider.notifier);

      await notifier.refreshIfStale();
      final callsAfterFirst = fakeApi.service.itemsGetCalls;
      await notifier.refreshIfStale();

      expect(fakeApi.service.itemsGetCalls, callsAfterFirst);
    });

    test('force always refetches regardless of staleness', () async {
      final fakeApi = _FakeJellyApi();
      final container = _containerWith(fakeApi);
      addTearDown(container.dispose);
      final notifier = container.read(livingHomeProvider.notifier);

      await notifier.refreshIfStale();
      final callsAfterFirst = fakeApi.service.itemsGetCalls;
      await notifier.refreshIfStale(force: true);

      expect(fakeApi.service.itemsGetCalls, greaterThan(callsAfterFirst));
    });
  });

  test('clear resets to the default model', () async {
    final fakeApi = _FakeJellyApi(favouriteSample: [_item('seed-1', favourite: true)]);
    final container = _containerWith(fakeApi);
    addTearDown(container.dispose);
    final notifier = container.read(livingHomeProvider.notifier);

    await notifier.fetchRails();
    notifier.clear();

    expect(container.read(livingHomeProvider), const LivingHomeModel());
  });
}
