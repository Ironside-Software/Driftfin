import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driftfin/models/items/episode_model.dart';
import 'package:driftfin/models/syncing/sync_item.dart';
import 'package:driftfin/providers/sync_provider.dart';
import 'package:driftfin/providers/user_provider.dart';

/// Uses the existing user-scoped database, including nested episodes and tracks.
final offlineCatalogProvider = StreamProvider.autoDispose<List<SyncedItem>>((ref) {
  final userId = ref.watch(userProvider.select((user) => user?.id));
  if (kIsWeb || userId == null) return Stream.value(const []);
  ref.watch(activeDownloadTasksProvider);
  return ref.watch(syncProvider.notifier).watchAllItems().map(availableOfflineItems);
});

List<SyncedItem> availableOfflineItems(List<SyncedItem> items) => items.where((item) {
  if (item.syncing || item.markedForDelete || !item.hasVideoFile || item.itemModel == null) return false;
  try {
    return item.videoFile.existsSync() && item.videoFile.lengthSync() > 0;
  } on FileSystemException {
    return false;
  }
}).toList();

/// One next unwatched regular episode per series, ordered by season and episode.
/// Only downloaded episodes participate; gaps cannot be filled without the server.
List<SyncedItem> offlineNextUp(List<SyncedItem> items) {
  final episodes =
      items.where((item) {
        final model = item.itemModel;
        return model is EpisodeModel &&
            model.season > 0 &&
            model.parentId?.isNotEmpty == true &&
            !(item.userData ?? model.userData).played;
      }).toList()..sort((a, b) {
        final left = a.itemModel! as EpisodeModel;
        final right = b.itemModel! as EpisodeModel;
        final series = left.parentId!.compareTo(right.parentId!);
        if (series != 0) return series;
        final season = left.season.compareTo(right.season);
        if (season != 0) return season;
        final episode = left.episode.compareTo(right.episode);
        return episode != 0 ? episode : a.id.compareTo(b.id);
      });
  final seen = <String>{};
  return episodes.where((item) => seen.add(item.itemModel!.parentId!)).toList();
}
