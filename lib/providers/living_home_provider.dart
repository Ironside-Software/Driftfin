import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.enums.swagger.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/living_home_model.dart';
import 'package:driftfin/models/recommended_model.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/service_provider.dart';
import 'package:driftfin/util/taste_signals.dart';

/// Living Home rails - Netflix-style personalized rows computed locally
/// from the user's own favourited/played items (`ItemBaseModel.userData`),
/// with a daily seed rotation so the "Because you watched" rail doesn't
/// hammer the same endpoint - or show the same row - on every 120s
/// dashboard refresh.
final livingHomeProvider = StateNotifierProvider<LivingHomeNotifier, LivingHomeModel>((ref) {
  return LivingHomeNotifier(ref);
});

class LivingHomeNotifier extends StateNotifier<LivingHomeModel> {
  LivingHomeNotifier(this.ref) : super(const LivingHomeModel());

  final Ref ref;

  late final JellyService api = ref.read(jellyApiProvider);

  static const _staleAfter = Duration(minutes: 30);
  static const _seedTypes = [BaseItemKind.movie, BaseItemKind.series];

  /// Only refetches once the previous result is older than [_staleAfter],
  /// so the rails survive many dashboard refresh ticks unchanged.
  Future<void> refreshIfStale({bool force = false}) async {
    final lastFetched = state.lastFetched;
    if (!force && lastFetched != null && DateTime.now().difference(lastFetched) < _staleAfter) {
      return;
    }
    await fetchRails();
  }

  Future<void> fetchRails() async {
    if (state.loading) return;
    state = state.copyWith(loading: true);

    var seedPool = await _fetchTasteSample(isFavorite: true);
    if (seedPool.isEmpty) {
      seedPool = await _fetchTasteSample(isFavorite: null, filters: [ItemFilter.isplayed]);
    }

    final rails = <RecommendedModel>[];

    if (seedPool.isNotEmpty) {
      final dayIndex = DateTime.now().difference(DateTime(2020)).inDays;
      final seed = seedPool[dayIndex % seedPool.length];
      final similar = await api.itemsItemIdSimilarGet(itemId: seed.id, limit: 12);
      final posters = (similar.body?.items ?? []).map((e) => ItemBaseModel.fromBaseDto(e, ref)).toList();
      if (posters.isNotEmpty) {
        rails.add(RecommendedModel(name: BecauseYouWatched(seed.name), posters: posters));
      }
    }

    for (final entry in TasteSignals.topDirectors(seedPool, limit: 3)) {
      final director = entry.key;
      final response = await api.itemsGet(
        recursive: true,
        personIds: [director.id],
        isPlayed: false,
        limit: 12,
        includeItemTypes: _seedTypes,
      );
      final posters = response.body?.items ?? [];
      if (posters.isNotEmpty) {
        rails.add(RecommendedModel(name: MoreFromDirector(director.name), posters: posters));
      }
    }

    final gemsCandidates = await api.itemsGet(
      recursive: true,
      isPlayed: false,
      minCommunityRating: 7,
      sortBy: [ItemSortBy.random],
      limit: 24,
      includeItemTypes: _seedTypes,
    );
    final gems = TasteSignals.hiddenGems(gemsCandidates.body?.items ?? []).take(12).toList();
    if (gems.isNotEmpty) {
      rails.add(RecommendedModel(name: const HiddenGems(), posters: gems));
    }

    state = state.copyWith(loading: false, rails: rails, lastFetched: () => DateTime.now());
  }

  Future<List<ItemBaseModel>> _fetchTasteSample({bool? isFavorite, List<ItemFilter>? filters}) async {
    final response = await api.itemsGet(
      recursive: true,
      isFavorite: isFavorite,
      filters: filters,
      enableUserData: true,
      limit: 40,
      fields: [ItemFields.genres, ItemFields.people],
      includeItemTypes: _seedTypes,
    );
    return response.body?.items ?? [];
  }

  void clear() => state = const LivingHomeModel();
}
