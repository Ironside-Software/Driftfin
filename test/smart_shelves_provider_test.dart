import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/items/overview_model.dart';
import 'package:driftfin/models/library_filters_model.dart';
import 'package:driftfin/models/recommended_model.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/service_provider.dart';
import 'package:driftfin/providers/smart_shelves_provider.dart';
import 'package:driftfin/providers/user_provider.dart';

Response<T> _ok<T>(T body) => Response<T>(http.Response('', 200), body);

ItemBaseModel _poster(String id) {
  return ItemBaseModel(
    name: id,
    id: id,
    overview: const OverviewModel(),
    parentId: null,
    playlistId: null,
    images: null,
    childCount: null,
    primaryRatio: null,
    userData: const UserData(),
    canDownload: null,
    canDelete: null,
    jellyType: null,
  );
}

ServerQueryResult _queryResult(List<ItemBaseModel> items) =>
    ServerQueryResult(items: items, totalRecordCount: items.length, startIndex: 0);

class _FakeUser extends User {
  _FakeUser(this.initial);
  final AccountModel? initial;

  @override
  AccountModel? build() => initial;
}

/// Canned per-shelf item response for [smartShelvesProvider], keyed by
/// `parentId` so different saved filters can return different posters.
class _FakeSmartShelfJellyService extends JellyService {
  _FakeSmartShelfJellyService(Ref ref, {this.itemsByParentId = const {}}) : super(ref, JellyfinOpenApi.create());

  final Map<String?, List<ItemBaseModel>> itemsByParentId;
  final List<String?> parentIdsRequested = [];

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
    parentIdsRequested.add(parentId);
    return _ok(_queryResult(itemsByParentId[parentId] ?? const []));
  }
}

class _FakeJellyApi extends JellyApi {
  _FakeJellyApi({this.itemsByParentId = const {}});

  final Map<String?, List<ItemBaseModel>> itemsByParentId;
  late final _FakeSmartShelfJellyService service;

  @override
  JellyService build() {
    service = _FakeSmartShelfJellyService(ref, itemsByParentId: itemsByParentId);
    return service;
  }
}

AccountModel _accountWithFilters(List<LibraryFiltersModel> filters) {
  return AccountModel(
    name: 'test',
    id: 'user-id',
    avatar: '',
    lastUsed: DateTime(2024),
    credentials: CredentialsModel(url: 'http://server'),
    libraryFilters: filters,
  );
}

ProviderContainer _containerWith({required List<LibraryFiltersModel> filters, required _FakeJellyApi fakeApi}) {
  return ProviderContainer(
    overrides: [
      userProvider.overrideWith(() => _FakeUser(_accountWithFilters(filters))),
      jellyApiProvider.overrideWith(() => fakeApi),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('returns nothing when no saved filter is marked showOnHome', () async {
    final filter = LibraryFiltersModel(id: 'f1', name: 'Sci-Fi', isFavourite: false, showOnHome: false);
    final container = _containerWith(filters: [filter], fakeApi: _FakeJellyApi());
    addTearDown(container.dispose);

    final rails = await container.read(smartShelvesProvider.future);

    expect(rails, isEmpty);
  });

  test('promotes a showOnHome filter to a rail named after it', () async {
    final filter = LibraryFiltersModel(
      id: 'f1',
      name: 'Unwatched Sci-Fi',
      isFavourite: false,
      showOnHome: true,
      ids: const ['view-1'],
    );
    final fakeApi = _FakeJellyApi(
      itemsByParentId: {
        'view-1': [_poster('p1')],
      },
    );
    final container = _containerWith(filters: [filter], fakeApi: fakeApi);
    addTearDown(container.dispose);

    final rails = await container.read(smartShelvesProvider.future);

    expect(rails, hasLength(1));
    expect((rails.single.name as Other).customLabel, 'Unwatched Sci-Fi');
    expect(rails.single.posters.map((e) => e.id), ['p1']);
    expect(fakeApi.service.parentIdsRequested, ['view-1']);
  });

  test('omits shelves that resolve to zero items', () async {
    final filter = LibraryFiltersModel(id: 'f1', name: 'Empty Shelf', isFavourite: false, showOnHome: true);
    final container = _containerWith(filters: [filter], fakeApi: _FakeJellyApi());
    addTearDown(container.dispose);

    final rails = await container.read(smartShelvesProvider.future);

    expect(rails, isEmpty);
  });

  test('does not scope by parentId when a filter spans multiple views', () async {
    final filter = LibraryFiltersModel(
      id: 'f1',
      name: 'Cross-library shelf',
      isFavourite: false,
      showOnHome: true,
      ids: const ['view-1', 'view-2'],
    );
    final fakeApi = _FakeJellyApi(
      itemsByParentId: {
        null: [_poster('p1')],
      },
    );
    final container = _containerWith(filters: [filter], fakeApi: fakeApi);
    addTearDown(container.dispose);

    await container.read(smartShelvesProvider.future);

    expect(fakeApi.service.parentIdsRequested, [null]);
  });

  test('builds one rail per showOnHome filter, skipping ones not marked', () async {
    final shown = LibraryFiltersModel(
      id: 'f1',
      name: 'Shown',
      isFavourite: false,
      showOnHome: true,
      ids: const ['view-1'],
    );
    final hidden = LibraryFiltersModel(id: 'f2', name: 'Hidden', isFavourite: false, showOnHome: false);
    final fakeApi = _FakeJellyApi(
      itemsByParentId: {
        'view-1': [_poster('p1')],
      },
    );
    final container = _containerWith(filters: [shown, hidden], fakeApi: fakeApi);
    addTearDown(container.dispose);

    final rails = await container.read(smartShelvesProvider.future);

    expect(rails, hasLength(1));
    expect(fakeApi.service.parentIdsRequested, ['view-1']);
  });
}
