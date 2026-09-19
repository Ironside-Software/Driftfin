import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/tonight_model.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/dashboard_provider.dart';
import 'package:driftfin/providers/service_provider.dart';
import 'package:driftfin/providers/views_provider.dart';
import 'package:driftfin/util/list_extensions.dart';
import 'package:driftfin/util/tonight_picker.dart';

/// "Tonight" - a one-tap "what to watch" answer engine. Fans out to a
/// handful of Jellyfin recommendation endpoints and collapses the result
/// down to a handful of decision-ready picks via [TonightPicker].
final tonightProvider = StateNotifierProvider<TonightNotifier, TonightModel>((ref) {
  return TonightNotifier(ref);
});

class TonightNotifier extends StateNotifier<TonightModel> {
  TonightNotifier(this.ref) : super(const TonightModel());

  final Ref ref;

  late final JellyService api = ref.read(jellyApiProvider);

  static const _fieldsToFetch = [ItemFields.overview, ItemFields.primaryimageaspectratio, ItemFields.parentid];

  Future<void> fetchTonightPicks({Duration? timeAvailable, TonightMood? mood}) async {
    if (state.loading) return;
    state = state.copyWith(
      loading: true,
      timeAvailable: timeAvailable != null ? () => timeAvailable : null,
      mood: mood,
    );

    final viewTypes = ref
        .read(viewsProvider.select((value) => value.dashboardViews))
        .map((e) => e.collectionType)
        .toSet()
        .toList();

    final candidates = <ItemBaseModel>[];

    if (viewTypes.containsAny([CollectionType.movies])) {
      final recommendations = await api.moviesRecommendationsGet(
        categoryLimit: 4,
        itemLimit: 6,
        fields: _fieldsToFetch,
      );
      for (final category in recommendations.body ?? const <RecommendationDto>[]) {
        candidates.addAll((category.items ?? []).map((e) => ItemBaseModel.fromBaseDto(e, ref)));
      }
    }

    if (viewTypes.containsAny([CollectionType.movies, CollectionType.tvshows])) {
      final nextUp = await api.showsNextUpGet(limit: 12, fields: _fieldsToFetch);
      candidates.addAll((nextUp.body?.items ?? []).map((e) => ItemBaseModel.fromBaseDto(e, ref)));
    }

    final resumeVideo = ref.read(dashboardProvider.select((value) => value.resumeVideo));
    for (final seed in resumeVideo.take(3)) {
      final similar = await api.itemsItemIdSimilarGet(itemId: seed.id, limit: 6);
      candidates.addAll((similar.body?.items ?? []).map((e) => ItemBaseModel.fromBaseDto(e, ref)));
    }

    final picks = TonightPicker.pick(
      candidates,
      timeAvailable: timeAvailable ?? state.timeAvailable,
      mood: mood ?? state.mood,
    );

    state = state.copyWith(loading: false, picks: picks, generatedAt: () => DateTime.now());
  }

  void setTimeAvailable(Duration? timeAvailable) {
    state = state.copyWith(timeAvailable: () => timeAvailable);
  }

  void setMood(TonightMood mood) {
    state = state.copyWith(mood: mood);
  }

  void clear() => state = const TonightModel();
}
