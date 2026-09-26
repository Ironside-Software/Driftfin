import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driftfin/models/items/episode_model.dart';
import 'package:driftfin/models/items/audio_model.dart';
import 'package:driftfin/models/playback/playback_model.dart';
import 'package:driftfin/models/syncing/sync_item.dart';
import 'package:driftfin/models/video_stream_model.dart';
import 'package:driftfin/providers/connectivity_provider.dart';
import 'package:driftfin/providers/offline_catalog_provider.dart';
import 'package:driftfin/providers/video_player_provider.dart';
import 'package:driftfin/util/localization_helper.dart';

/// Local browsing deliberately avoids server-backed detail and search routes.
class OfflineCatalogScreen extends ConsumerStatefulWidget {
  const OfflineCatalogScreen({this.home = false, this.favorites = false, super.key});

  final bool home;
  final bool favorites;

  @override
  ConsumerState<OfflineCatalogScreen> createState() => _OfflineCatalogScreenState();
}

class _OfflineCatalogScreenState extends ConsumerState<OfflineCatalogScreen> {
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String query = '';
  bool reconnecting = false;
  bool playing = false;

  Future<void> reconnect() async {
    setState(() => reconnecting = true);
    try {
      final connectivity = ref.read(connectivityStatusProvider.notifier);
      await connectivity.checkConnectivity(immediate: true);
      await connectivity.waitForProbe();
      if (mounted) ref.invalidate(offlineCatalogProvider);
    } finally {
      if (mounted) setState(() => reconnecting = false);
    }
  }

  Future<void> play(SyncedItem item) async {
    if (playing) return;
    setState(() => playing = true);
    try {
      final model = await ref
          .read(playbackModelHelper)
          .createPlaybackModel(context, item.itemModel, forcedPlaybackType: PlaybackType.offline);
      if (!mounted) return;
      if (model == null) throw StateError('Download unavailable');
      final start = await model.startDuration() ?? Duration.zero;
      if (!mounted) return;
      final player = ref.read(videoPlayerProvider.notifier);
      final audio = model.item;
      final bool loaded;
      if (audio is AudioModel) {
        final queue = model.queue.whereType<AudioModel>().toList();
        var index = queue.indexWhere((track) => track.id == audio.id);
        if (index < 0) {
          queue.add(audio);
          index = queue.length - 1;
        }
        loaded = await player.loadAudioPlaybackItem(model, queue, index, start);
      } else {
        loaded = await player.loadPlaybackItem(model, start);
      }
      if (!loaded) throw StateError('Playback unavailable');
      if (mounted && audio is! AudioModel) await player.openPlayer(context);
    } catch (_) {
      if (!mounted) return;
      ref.invalidate(offlineCatalogProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.localized.unableToPlayMedia)));
      }
    } finally {
      if (mounted) setState(() => playing = false);
    }
  }

  Widget entry(SyncedItem item) {
    final model = item.itemModel!;
    final imagePath = item.images?.primary?.path;
    return ListTile(
      leading: SizedBox(
        width: 48,
        height: 64,
        child: imagePath == null
            ? const Icon(Icons.download_done)
            : Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.download_done),
              ),
      ),
      title: Text(model.name),
      subtitle: model is EpisodeModel
          ? Text('${model.seriesName ?? ''} · ${model.seasonEpisodeLabel(context.localized)}')
          : null,
      trailing: const Icon(Icons.play_arrow),
      enabled: !playing,
      onTap: () => play(item),
    );
  }

  List<Widget> section(String title, List<SyncedItem> items) => items.isEmpty
      ? []
      : [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          ...items.map(entry),
        ];

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(offlineStateProvider);
    final catalog = ref.watch(offlineCatalogProvider);
    return SafeArea(
      child: Column(
        children: [
          if (offline)
            ListTile(
              leading: const Icon(Icons.cloud_off),
              title: Text(context.localized.offline),
              subtitle: Text(context.localized.offlineBrowseDescription),
              trailing: TextButton(
                onPressed: reconnecting ? null : reconnect,
                child: Text(context.localized.offlineReconnect),
              ),
            ),
          if (!widget.home)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(labelText: context.localized.search, prefixIcon: const Icon(Icons.search)),
                onChanged: (value) => setState(() => query = value.trim().toLowerCase()),
              ),
            ),
          Expanded(
            child: catalog.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.localized.offlineCatalogError),
                    TextButton(
                      onPressed: () => ref.invalidate(offlineCatalogProvider),
                      child: Text(context.localized.retry),
                    ),
                  ],
                ),
              ),
              data: (items) {
                final filtered = items.where((item) {
                  final model = item.itemModel!;
                  return (!widget.favorites || (item.userData ?? model.userData).isFavourite) &&
                      '${model.name} ${model is EpisodeModel ? model.seriesName ?? '' : ''}'.toLowerCase().contains(
                        query,
                      );
                }).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(items.isEmpty ? context.localized.offlineEmpty : context.localized.noResults),
                          if (!offline && items.isEmpty) Text(context.localized.offlineEmptyHint),
                          if (query.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                searchController.clear();
                                setState(() => query = '');
                              },
                              child: Text(context.localized.clear),
                            ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView(
                  children: widget.home
                      ? [
                          ...section(
                            context.localized.dashboardContinueWatching,
                            filtered.where((item) {
                              final data = item.userData ?? item.itemModel!.userData;
                              return !data.played && data.playBackPosition > Duration.zero;
                            }).toList(),
                          ),
                          ...section(context.localized.nextUp, offlineNextUp(filtered)),
                          ...section(context.localized.availableOffline, filtered),
                        ]
                      : [...section(context.localized.availableOffline, filtered)],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
