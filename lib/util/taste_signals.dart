import 'package:driftfin/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';

/// Pure, on-device signal extraction over a user's own item history
/// (favourites / watched items). No network calls, no external services -
/// used by the Living Home rails.
class TasteSignals {
  const TasteSignals._();

  static List<MapEntry<String, int>> topGenres(List<ItemBaseModel> items, {int limit = 5}) {
    final counts = <String, int>{};
    for (final item in items) {
      for (final genre in item.overview.genres) {
        counts[genre] = (counts[genre] ?? 0) + 1;
      }
    }
    return _topEntries(counts, limit);
  }

  static List<MapEntry<Studio, int>> topStudios(List<ItemBaseModel> items, {int limit = 5}) {
    final counts = <Studio, int>{};
    for (final item in items) {
      for (final studio in item.overview.studios) {
        counts[studio] = (counts[studio] ?? 0) + 1;
      }
    }
    return _topEntries(counts, limit);
  }

  static List<MapEntry<Person, int>> topDirectors(List<ItemBaseModel> items, {int limit = 5}) {
    final counts = <String, MapEntry<Person, int>>{};
    for (final item in items) {
      for (final director in item.overview.directors) {
        if (director.id.isEmpty) continue;
        final existing = counts[director.id];
        counts[director.id] = MapEntry(director, (existing?.value ?? 0) + 1);
      }
    }
    final entries = counts.values.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  static List<MapEntry<Person, int>> topActors(List<ItemBaseModel> items, {int limit = 5}) {
    final counts = <String, MapEntry<Person, int>>{};
    for (final item in items) {
      for (final person in item.overview.people.where((e) => e.type == PersonKind.actor)) {
        if (person.id.isEmpty) continue;
        final existing = counts[person.id];
        counts[person.id] = MapEntry(person, (existing?.value ?? 0) + 1);
      }
    }
    final entries = counts.values.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  /// Unwatched, highly-rated items already sitting in the library.
  static List<ItemBaseModel> hiddenGems(
    List<ItemBaseModel> candidates, {
    double minRating = 7.0,
  }) {
    final gems =
        candidates.where((item) => !item.userData.played && (item.overview.communityRating ?? 0) >= minRating).toList();
    gems.sort((a, b) => (b.overview.communityRating ?? 0).compareTo(a.overview.communityRating ?? 0));
    return gems;
  }

  static List<MapEntry<T, int>> _topEntries<T>(Map<T, int> counts, int limit) {
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }

  /// Total time spent watching, estimated from runtime * play count.
  static Duration totalWatchTime(List<ItemBaseModel> items) {
    var total = Duration.zero;
    for (final item in items) {
      final runTime = item.overview.runTime;
      if (runTime == null) continue;
      total += runTime * item.userData.playCount.clamp(0, 1000);
    }
    return total;
  }

  /// A short, human-readable reason a candidate might have been surfaced,
  /// derived from what the profile knows the user already likes.
  static String? explainSuggestion(
    ItemBaseModel candidate, {
    required List<MapEntry<String, int>> favouriteGenres,
    required List<MapEntry<Person, int>> favouriteDirectors,
  }) {
    final candidateGenres = candidate.overview.genres.toSet();
    final matchedGenre = favouriteGenres.map((e) => e.key).firstWhere(
          (genre) => candidateGenres.contains(genre),
          orElse: () => '',
        );
    if (matchedGenre.isNotEmpty) {
      return 'Because you like $matchedGenre';
    }
    final candidateDirectorIds = candidate.overview.directors.map((e) => e.id).toSet();
    final matchedDirector = favouriteDirectors.map((e) => e.key).firstWhere(
          (director) => candidateDirectorIds.contains(director.id),
          orElse: () => Person(id: ''),
        );
    if (matchedDirector.id.isNotEmpty) {
      return 'From ${matchedDirector.name}, a director you love';
    }
    return null;
  }
}
