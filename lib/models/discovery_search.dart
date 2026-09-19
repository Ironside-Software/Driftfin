import 'dart:ui' show Locale;

import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/images_models.dart';
import 'package:driftfin/models/items/movie_model.dart';
import 'package:driftfin/models/items/series_model.dart';
import 'package:driftfin/models/library_search/library_search_model.dart';
import 'package:driftfin/models/library_search/library_search_options.dart';
import 'package:driftfin/models/seerr/seerr_dashboard_model.dart';
import 'package:driftfin/models/seerr/seerr_item_models.dart';
import 'package:driftfin/seerr/seerr_models.dart';

enum SearchScope { all, library, discover }

enum DiscoveryAvailability { available, partial, requested, requestable, unavailable }

String discoveryLanguage(Locale locale) {
  final language = locale.languageCode == 'jp' ? 'ja' : locale.languageCode;
  final country = locale.countryCode ?? (language == 'zh' && locale.scriptCode == 'Hant' ? 'TW' : null);
  return country == null ? language : '$language-$country';
}

bool hasLibraryOnlySearchFilters(LibrarySearchModel search) {
  final filters = search.filters;
  return search.folderOverwrite.isNotEmpty ||
      search.views.values.any((enabled) => enabled) ||
      filters.favourites != null ||
      filters.sortingOption != SortingOptions.sortName ||
      filters.sortOrder != SortingOrder.ascending ||
      filters.groupBy != GroupBy.none ||
      [
        filters.types,
        filters.genres,
        filters.studios,
        filters.tags,
        filters.years,
        filters.officialRatings,
        filters.itemFilters,
      ].any((values) => values.values.any((enabled) => enabled));
}

class DiscoveryResult {
  const DiscoveryResult({
    required this.tmdbId,
    required this.mediaType,
    required this.title,
    required this.availability,
    this.overview = '',
    this.posterPath,
    this.releaseDate,
    this.libraryItemId,
    this.canPlay = false,
    this.canRequest = false,
  });

  final int tmdbId;
  final String mediaType;
  final String title;
  final String overview;
  final String? posterPath;
  final String? releaseDate;
  final String? libraryItemId;
  final DiscoveryAvailability availability;
  final bool canPlay;
  final bool canRequest;
  String get key => '$mediaType:$tmdbId';

  factory DiscoveryResult.fromJson(Map<String, dynamic> json) {
    final id = json['tmdbId'];
    final type = json['mediaType'];
    if (id is! int || id <= 0 || type != 'movie' && type != 'tv') throw const FormatException('Invalid catalog ID');
    final availability = DiscoveryAvailability.values.firstWhere(
      (value) => value.name == json['availability'],
      orElse: () => DiscoveryAvailability.unavailable,
    );
    final libraryId = json['libraryItemId'] as String?;
    return DiscoveryResult(
      tmdbId: id,
      mediaType: type as String,
      title: (json[type == 'movie' ? 'title' : 'name'] as String?) ?? '',
      overview: json['overview'] as String? ?? '',
      posterPath: json['posterPath'] as String?,
      releaseDate: json[type == 'movie' ? 'releaseDate' : 'firstAirDate'] as String?,
      libraryItemId: libraryId?.isNotEmpty == true ? libraryId : null,
      availability: availability,
      canPlay: libraryId?.isNotEmpty == true && json['canPlay'] == true,
      canRequest: json['canRequest'] == true,
    );
  }

  // Catalog metadata never becomes a synthetic Jellyfin item. A matched result
  // opens DetailsRoute with the real, user-visible library ID instead.
  SeerrDashboardPosterModel get poster => SeerrDashboardPosterModel(
    id: key,
    type: mediaType == 'tv' ? SeerrMediaType.tvshow : SeerrMediaType.movie,
    tmdbId: tmdbId,
    jellyfinItemId: null,
    title: title,
    overview: overview,
    images: ImagesData(
      primary: tmdbPrimaryImage(keyPrefix: key, posterPath: posterPath),
    ),
    releaseYear: DateTime.tryParse(releaseDate ?? '')?.year.toString(),
    mediaStatus: switch (availability) {
      DiscoveryAvailability.available => SeerrMediaStatus.available,
      DiscoveryAvailability.partial => SeerrMediaStatus.partiallyAvailable,
      DiscoveryAvailability.requested => SeerrMediaStatus.pending,
      _ => SeerrMediaStatus.unknown,
    },
  );
}

/// Type and stable provider ID take precedence over titles. A library result
/// wins only when it is actually present in the independently loaded page set.
List<DiscoveryResult> distinctDiscoveryResults(List<DiscoveryResult> results, List<ItemBaseModel> library) {
  final libraryIds = library.map((item) => item.id).toSet();
  final keys = <String>{};
  for (final item in library) {
    final (type, ids) = switch (item) {
      MovieModel() => ('movie', item.providerIds),
      SeriesModel() => ('tv', item.providerIds),
      _ => ('', null),
    };
    for (final entry in ids?.entries ?? const Iterable<MapEntry<String, dynamic>>.empty()) {
      final id = int.tryParse('${entry.value}');
      if (entry.key.toLowerCase() == 'tmdb' && id != null && id > 0) {
        keys.add('$type:$id');
      }
    }
  }
  return results.where((item) => !libraryIds.contains(item.libraryItemId) && keys.add(item.key)).toList();
}

class DiscoverySearchState {
  const DiscoverySearchState({
    this.results = const [],
    this.page = 0,
    this.totalPages = 1,
    this.loading = false,
    this.reason,
  });
  final List<DiscoveryResult> results;
  final int page;
  final int totalPages;
  final bool loading;
  final String? reason;
  bool get hasMore => page < totalPages;
}
