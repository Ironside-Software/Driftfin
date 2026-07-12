import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/library_search/library_search_options.dart';
import 'package:driftfin/routes/auto_router.gr.dart';
import 'package:driftfin/util/map_bool_helper.dart';

part 'library_filter_model.freezed.dart';
part 'library_filter_model.g.dart';

@Freezed(copyWith: true)
abstract class LibraryFilterModel with _$LibraryFilterModel {
  const LibraryFilterModel._();

  const factory LibraryFilterModel({
    @Default({}) Map<String, bool> genres,
    @Default({
      ItemFilter.isplayed: false,
      ItemFilter.isunplayed: false,
      ItemFilter.isresumable: false,
    })
    Map<ItemFilter, bool> itemFilters,
    @StudioEncoder() @Default({}) Map<Studio, bool> studios,
    @Default({}) Map<String, bool> tags,
    @Default({}) Map<int, bool> years,
    @Default({}) Map<String, bool> officialRatings,
    @Default({
      FladderItemType.audio: false,
      FladderItemType.boxset: false,
      FladderItemType.book: false,
      FladderItemType.collectionFolder: false,
      FladderItemType.episode: false,
      FladderItemType.folder: false,
      FladderItemType.movie: false,
      FladderItemType.musicAlbum: false,
      FladderItemType.musicVideo: false,
      FladderItemType.photo: false,
      FladderItemType.person: false,
      FladderItemType.photoAlbum: false,
      FladderItemType.series: false,
      FladderItemType.video: false,
    })
    Map<FladderItemType, bool> types,
    @Default(SortingOptions.sortName) SortingOptions sortingOption,
    @Default(SortingOrder.ascending) SortingOrder sortOrder,
    @Default(false) bool? favourites,
    @Default(true) bool hideEmptyShows,
    @Default(true) bool? recursive,
    @Default(GroupBy.none) GroupBy groupBy,
  }) = _LibraryFilterModel;

  bool get hasActiveFilters {
    return genres.hasEnabled ||
        studios.hasEnabled ||
        tags.hasEnabled ||
        years.hasEnabled ||
        officialRatings.hasEnabled ||
        hideEmptyShows ||
        itemFilters.hasEnabled ||
        recursive == false ||
        favourites == true;
  }

  LibraryFilterModel loadModel(LibraryFilterModel model) {
    return copyWith(
      genres: genres.replaceMap(model.genres),
      itemFilters: itemFilters.replaceMap(model.itemFilters),
      studios: studios.replaceMap(model.studios),
      tags: tags.replaceMap(model.tags),
      years: years.replaceMap(model.years),
      officialRatings: officialRatings.replaceMap(model.officialRatings),
      types: types.replaceMap(model.types),
      sortingOption: model.sortingOption,
      sortOrder: model.sortOrder,
      favourites: model.favourites,
      hideEmptyShows: model.hideEmptyShows,
      recursive: model.recursive,
      groupBy: model.groupBy,
    );
  }

  factory LibraryFilterModel.fromJson(Map<String, dynamic> json) => _$LibraryFilterModelFromJson(json);

  @override
  bool operator ==(covariant LibraryFilterModel other) {
    if (identical(this, other)) return true;
    return mapEquals(other.genres, genres) &&
        mapEquals(other.studios, studios) &&
        mapEquals(other.tags, tags) &&
        mapEquals(other.years, years) &&
        mapEquals(other.officialRatings, officialRatings) &&
        mapEquals(other.types, types) &&
        mapEquals(other.itemFilters, itemFilters) &&
        other.sortingOption == sortingOption &&
        other.sortOrder == sortOrder &&
        other.favourites == favourites &&
        other.recursive == recursive;
  }

  @override
  int get hashCode {
    return itemFilters.hashCode ^
        genres.hashCode ^
        studios.hashCode ^
        tags.hashCode ^
        years.hashCode ^
        officialRatings.hashCode ^
        types.hashCode ^
        sortingOption.hashCode ^
        itemFilters.hashCode ^
        sortOrder.hashCode ^
        favourites.hashCode ^
        recursive.hashCode;
  }

  LibraryFilterModel clear() {
    return copyWith(
      genres: genres.setAll(false),
      tags: tags.setAll(false),
      officialRatings: officialRatings.setAll(false),
      years: years.setAll(false),
      favourites: false,
      recursive: true,
      studios: studios.setAll(false),
      itemFilters: itemFilters.setAll(false),
      hideEmptyShows: false,
    );
  }
}

class StudioEncoder implements JsonConverter<Map<Studio, bool>, String> {
  const StudioEncoder();

  @override
  Map<Studio, bool> fromJson(String json) {
    final decodedMap = jsonDecode(json) as Map<dynamic, dynamic>;
    final studios = decodedMap.map((key, value) => MapEntry(Studio.fromJson(key), value as bool));
    return studios;
  }

  @override
  String toJson(Map<Studio, bool> studios) => jsonEncode(studios.map((key, value) => MapEntry(key.toJson(), value)));
}

extension LibraryFilterModelMerge on LibraryFilterModel {
  /// Applies the *enabled* entries of an incoming filter (e.g. one carried by
  /// a route/deep link) onto this filter, leaving everything this filter
  /// already knows about (the full genre/studio/tag/year universe) intact.
  LibraryFilterModel mergeEnabledFrom(LibraryFilterModel incoming) {
    return copyWith(
      types: types.replaceMap(incoming.types, enabledOnly: true),
      genres: genres.replaceMap(incoming.genres, enabledOnly: true),
      studios: studios.replaceMap(incoming.studios, enabledOnly: true),
      tags: tags.replaceMap(incoming.tags, enabledOnly: true),
      years: years.replaceMap(incoming.years, enabledOnly: true),
      officialRatings: officialRatings.replaceMap(incoming.officialRatings, enabledOnly: true),
      recursive: incoming.recursive ?? true,
      favourites: incoming.favourites ?? false,
    );
  }
}

extension LibrarySearchRouteExtension on LibrarySearchRoute {
  LibrarySearchRoute withFilter(LibraryFilterModel model) {
    return LibrarySearchRoute(
      viewModelId: args?.viewModelId,
      folderId: args?.folderId,
      favourites: model.favourites,
      sortOrder: model.sortOrder,
      sortingOptions: model.sortingOption,
      types: model.types,
      genres: model.genres,
      studios: model.studios,
      tags: model.tags,
      years: model.years,
      officialRatings: model.officialRatings,
      recursive: model.recursive,
    );
  }
}
