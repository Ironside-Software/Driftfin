import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/user_provider.dart';

// Include media type: TMDB movie and TV identifiers can overlap.
typedef SeerrWatchedKey = ({String mediaType, int tmdbId, String? jellyfinItemId});

final seerrWatchedProvider = AsyncNotifierProvider.autoDispose.family<SeerrWatched, bool, SeerrWatchedKey>(
  SeerrWatched.new,
);

class SeerrWatched extends AutoDisposeFamilyAsyncNotifier<bool, SeerrWatchedKey> {
  String? _storageKey;

  @override
  Future<bool> build(SeerrWatchedKey arg) async {
    final identity = ref.watch(userProvider.select((user) => (user?.credentials.serverId, user?.id)));
    _storageKey = identity.$2 == null
        ? null
        : 'discoverWatched:${jsonEncode([identity.$1, identity.$2, arg.mediaType, arg.tmdbId])}';
    if (arg.jellyfinItemId?.isNotEmpty == true) {
      final response = await ref
          .read(jellyApiProvider)
          .userItemsItemIdUserDataGet(itemId: arg.jellyfinItemId)
          .timeout(const Duration(seconds: 20));
      if (!response.isSuccessful || response.body == null) throw StateError('Could not load watched status');
      return response.body!.played;
    }
    return _storageKey == null ? false : ref.read(sharedPreferencesProvider).getBool(_storageKey!) ?? false;
  }

  Future<void> setWatched(bool watched) async {
    if (state.isLoading) return;
    final previous = state;
    final storageKey = _storageKey;
    final link = ref.keepAlive();
    state = const AsyncLoading();
    try {
      if (arg.jellyfinItemId?.isNotEmpty == true) {
        final response = await ref
            .read(userProvider.notifier)
            .markAsPlayed(watched, arg.jellyfinItemId!)
            .timeout(const Duration(seconds: 20));
        if (response == null || !response.isSuccessful) throw StateError('Could not save watched status');
      } else {
        if (storageKey == null || !await ref.read(sharedPreferencesProvider).setBool(storageKey, watched)) {
          throw StateError('Could not save watched status');
        }
      }
      if (storageKey == _storageKey) state = AsyncData(watched);
    } catch (_) {
      if (storageKey == _storageKey) state = previous;
      rethrow;
    } finally {
      link.close();
    }
  }
}
