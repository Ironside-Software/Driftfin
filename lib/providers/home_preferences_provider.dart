import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.enums.swagger.dart' as enums;
import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/api_result.dart';
import 'package:driftfin/models/home_preferences_model.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/service_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/providers/views_provider.dart';
import 'package:driftfin/util/debouncer.dart';

final homePreferencesProvider = StateNotifierProvider<HomePreferencesNotifier, HomePreferencesModel>((ref) {
  return HomePreferencesNotifier(ref);
});

class HomePreferencesNotifier extends StateNotifier<HomePreferencesModel> {
  HomePreferencesNotifier(this.ref) : super(const HomePreferencesModel());

  final Ref ref;
  final Debouncer _debouncer = Debouncer(const Duration(seconds: 1));

  // Guards against auto-saving the placeholder/default state before `load()`
  // has populated it, and against re-saving while `load()` itself is running.
  bool _loaded = false;

  late final JellyService api = ref.read(jellyApiProvider);

  Future<void> load() async {
    if (state.loading) return;
    state = state.copyWith(loading: true);

    final user = ref.read(userProvider);
    final userConfig = user?.userConfiguration;
    final views = ref.read(viewsProvider).views;

    final orderedLibraryIds = _buildOrderedLibraryIds(userConfig?.orderedViews ?? [], views.map((v) => v.id).toList());

    final foldersResponse = await api.libraryMediaFolders();
    final allFolders = foldersResponse.body?.items ?? [];
    final availableFolders = allFolders
        .where((f) => _isGroupableFolder(f.collectionType))
        .where((f) => f.id != null && f.id!.isNotEmpty)
        .map((f) => (id: f.id!, name: f.name ?? f.id!))
        .toList();

    state = state.copyWith(
      orderedLibraryIds: orderedLibraryIds,
      latestItemsExcludes: user?.latestItemsExcludes ?? [],
      hidePlayedInLatest: userConfig?.hidePlayedInLatest ?? false,
      groupedFolders: (userConfig?.groupedFolders ?? []).toList(),
      availableFolders: availableFolders,
      loading: false,
    );
    _loaded = true;
  }

  /// Debounced auto-save (Phase 3, issue #50) — every setter below calls this
  /// instead of requiring an explicit Save button.
  void _scheduleAutoSave() {
    if (!_loaded) return;
    _debouncer.run(save);
  }

  List<String> _buildOrderedLibraryIds(List<String> serverOrder, List<String> availableIds) {
    final ordered = <String>[];
    for (final id in serverOrder) {
      if (availableIds.contains(id)) {
        ordered.add(id);
      }
    }
    for (final id in availableIds) {
      if (!ordered.contains(id)) {
        ordered.add(id);
      }
    }
    return ordered;
  }

  void setOrderedLibraryIds(List<String> ids) {
    state = state.copyWith(orderedLibraryIds: ids);
    _scheduleAutoSave();
  }

  void setLatestItemsExcludes(List<String> ids) {
    state = state.copyWith(latestItemsExcludes: ids);
    _scheduleAutoSave();
  }

  void setHidePlayedInLatest(bool value) {
    state = state.copyWith(hidePlayedInLatest: value);
    _scheduleAutoSave();
  }

  void setGroupedFolders(List<String> ids) {
    state = state.copyWith(groupedFolders: ids);
    _scheduleAutoSave();
  }

  Future<ApiResult<dynamic>> save() async {
    try {
      await _saveLibraryPreferences();
      await ref.read(userProvider.notifier).updateInformation();
      await ref.read(viewsProvider.notifier).fetchViews();
      return ApiResult.success(null);
    } catch (e) {
      return ApiResult.failure(ApiError(message: e.toString()));
    }
  }

  bool get hasChanges {
    final user = ref.read(userProvider);
    final currentConfig = user?.userConfiguration;
    if (currentConfig == null) return false;

    const listEquals = DeepCollectionEquality();

    return !listEquals.equals(currentConfig.orderedViews, state.orderedLibraryIds) ||
        !listEquals.equals(currentConfig.latestItemsExcludes, state.latestItemsExcludes) ||
        currentConfig.hidePlayedInLatest != state.hidePlayedInLatest ||
        !listEquals.equals(currentConfig.groupedFolders, state.groupedFolders);
  }

  Future<void> _saveLibraryPreferences() async {
    final user = ref.read(userProvider);
    final currentConfig = user?.userConfiguration;
    if (currentConfig == null) return;

    final updated = currentConfig.copyWith(
      orderedViews: state.orderedLibraryIds,
      latestItemsExcludes: state.latestItemsExcludes,
      hidePlayedInLatest: state.hidePlayedInLatest,
      groupedFolders: state.groupedFolders,
    );
    await api.updateUserConfiguration(updated);
  }

  static const _groupableTypes = {
    enums.CollectionType.movies,
    enums.CollectionType.tvshows,
    enums.CollectionType.music,
    enums.CollectionType.homevideos,
    enums.CollectionType.photos,
  };

  bool _isGroupableFolder(enums.CollectionType? type) {
    if (type == null) return true;
    return _groupableTypes.contains(type);
  }

  void revert() {
    load();
  }
}
