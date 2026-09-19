import 'package:chopper/chopper.dart';
import 'package:driftfin/models/search_model.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/service_provider.dart';
import 'package:driftfin/util/item_base_model/item_base_model_extensions.dart';
import 'package:driftfin/util/natural_language_query_parser.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

final searchProvider = StateNotifierProvider<SearchNotifier, SearchModel>((ref) {
  return SearchNotifier(ref);
});

class SearchNotifier extends StateNotifier<SearchModel> {
  SearchNotifier(this.ref) : super(SearchModel());

  final Ref ref;

  late final JellyService api = ref.read(jellyApiProvider);

  /// "Ask Driftfin" - translates the free-text query (moods, runtime
  /// budgets, "haven't seen" phrasing, ...) into a real, structured
  /// Jellyfin query before falling back to a plain title search.
  Future<Response?> searchQuery() async {
    if (state.searchQuery.isEmpty) return null;
    state = state.copyWith(loading: true);

    final parsed = NaturalLanguageQueryParser.parse(state.searchQuery);
    final searchTerm = parsed.hasStructuredSignal ? parsed.searchTerm : state.searchQuery;

    final response = await api.itemsGet(
      recursive: true,
      searchTerm: searchTerm,
      genres: parsed.genres.isNotEmpty ? parsed.genres : null,
      filters: parsed.filters.isNotEmpty ? parsed.filters : null,
      isFavorite: parsed.favoritesOnly ? true : null,
    );

    final maxRuntime = parsed.maxRuntime;
    final items = (response.body?.items ?? [])
        .where((item) => maxRuntime == null || item.overview.runTime == null || item.overview.runTime! <= maxRuntime)
        .toList();

    state = state.copyWith(
      resultCount: maxRuntime != null ? items.length : (response.body?.totalRecordCount ?? 0),
      results: items.groupedItems,
    );
    state = state.copyWith(loading: false);
    return response;
  }

  void setQuery(String searchQuery) {
    state = state.copyWith(searchQuery: searchQuery);
  }

  void clear() {
    state = SearchModel();
  }
}
