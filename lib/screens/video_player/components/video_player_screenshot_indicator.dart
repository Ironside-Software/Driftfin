import 'package:flutter/material.dart';

import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driftfin/models/items/media_streams_model.dart';
import 'package:driftfin/models/playback/playback_model.dart';
import 'package:driftfin/models/settings/video_player_settings.dart';
import 'package:driftfin/providers/settings/video_player_settings_provider.dart';
import 'package:driftfin/providers/video_player_provider.dart';
import 'package:driftfin/util/input_handler.dart';
import 'package:driftfin/util/localization_helper.dart';

class VideoPlayerScreenshotIndicator extends ConsumerStatefulWidget {
  const VideoPlayerScreenshotIndicator({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => VideoPlayerScreenshotIndicatorState();
}

class VideoPlayerScreenshotIndicatorState extends ConsumerState<VideoPlayerScreenshotIndicator> {
  RestartableTimer? timer;

  bool visible = false;
  bool screenshotTaken = false;
  bool isCleanScreenshot = false;

  void onTimerEnd() {
    setState(() {
      visible = false;
    });

    timer?.cancel();
    timer = null;
  }

  Future<void> onTakeScreenshot(bool cleanScreenshot) async {
    var result = false;
    try {
      if (cleanScreenshot) {
        final playbackModel = ref.read(playBackModel);
        final player = ref.read(videoPlayerProvider);
        final primaryIndex = playbackModel?.mediaStreams?.defaultSubStreamIndex ?? -1;
        final selectedSubs = playbackModel?.subStreams?.where((stream) => stream.index == primaryIndex).firstOrNull;
        final secondaryIndex = ref.read(secondarySubtitleProvider);
        final selectedSecondary = playbackModel?.subStreams
            ?.where((stream) => stream.index == secondaryIndex)
            .firstOrNull;
        try {
          if (playbackModel != null) {
            await player.setSecondarySubtitleTrack(null, playbackModel);
            final noSubsModel = await playbackModel.setSubtitle(SubStreamModel.no(), player);
            ref.read(playBackModel.notifier).state = noSubsModel;
            if (noSubsModel != null) {
              await ref.read(playbackModelHelper).shouldReload(noSubsModel);
            }
          }
          result = await ref.read(videoPlayerProvider.notifier).takeScreenshot();
        } finally {
          if (playbackModel != null) {
            try {
              final restoredModel = await playbackModel.setSubtitle(selectedSubs ?? SubStreamModel.no(), player);
              ref.read(playBackModel.notifier).state = restoredModel;
              if (restoredModel != null) {
                await ref.read(playbackModelHelper).shouldReload(restoredModel);
              }
            } finally {
              await player.setSecondarySubtitleTrack(selectedSecondary, ref.read(playBackModel) ?? playbackModel);
            }
          }
        }
      } else {
        result = await ref.read(videoPlayerProvider.notifier).takeScreenshot();
      }
    } catch (_) {
      result = false;
    }

    if (!mounted) return;

    if (timer == null) {
      timer = RestartableTimer(const Duration(milliseconds: 500), () => onTimerEnd());
    } else {
      timer?.reset();
    }

    setState(() {
      visible = true;
      screenshotTaken = result;
      isCleanScreenshot = cleanScreenshot;
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InputHandler<VideoHotKeys>(
      autoFocus: false,
      listenRawKeyboard: true,
      keyMap: ref.watch(videoPlayerSettingsProvider.select((value) => value.currentShortcuts)),
      keyMapResult: (result) => _onKey(result),
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: visible ? 1 : 0,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8.0,
                  children: [
                    const Icon(Icons.image),
                    Text(
                      screenshotTaken
                          ? isCleanScreenshot
                                ? context.localized.screenshotCleanTaken
                                : context.localized.screenshotTaken
                          : context.localized.errorTakingScreenshot,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void takeScreenshot() {
    onTakeScreenshot(false);
  }

  void takeScreenshotClean() {
    onTakeScreenshot(true);
  }

  bool _onKey(VideoHotKeys value) {
    switch (value) {
      case VideoHotKeys.takeScreenshot:
        takeScreenshot();
        return true;
      case VideoHotKeys.takeScreenshotClean:
        takeScreenshotClean();
        return true;
      default:
        return false;
    }
  }
}
