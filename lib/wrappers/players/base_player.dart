import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:driftfin/models/items/media_streams_model.dart';
import 'package:driftfin/models/playback/playback_model.dart';
import 'package:driftfin/models/settings/subtitle_settings_model.dart';
import 'package:driftfin/models/settings/video_player_settings.dart';
import 'package:driftfin/util/audio_filter_chain.dart';
import 'package:driftfin/wrappers/players/player_capabilities.dart';
import 'package:driftfin/wrappers/players/player_states.dart';

const libassFallbackFont = "assets/mp-font.ttf";

abstract class BasePlayer {
  Stream<PlayerState> get stateStream;
  PlayerState lastState = PlayerState();

  /// Which optional features this backend actually supports. UI reads this to
  /// gray out controls instead of them silently no-oping.
  PlayerCapabilities get capabilities;

  Future<void> init(VideoPlayerSettingsModel settings);
  Widget? videoWidget(Key key, BoxFit fit);
  Widget? subtitles(bool showOverlay, {GlobalKey? controlsKey});
  Future<void> dispose();
  Future<void> open(BuildContext context);
  Future<void> loadVideo(String url, bool play, {Duration startPosition = Duration.zero});
  Future<void> seek(Duration position);
  Future<void> play();
  Future<void> setVolume(double volume);
  Future<void> setSpeed(double speed);
  Future<void> pause();
  Future<void> stop();
  Future<void> playOrPause();
  Future<void> loop(bool loop);
  Future<void> skipToNext() async {}
  Future<void> skipToPrevious() async {}
  Future<void> addToPlaylist(String url) async {}
  Future<void> removeFromPlaylist(int index) async {}
  Future<void> playerNext() async {}
  Future<void> playerPrevious() async {}
  Stream<int> get playlistIndexStream => const Stream<int>.empty();
  Future<Uint8List?> takeScreenshot();
  Future<int> setSubtitleTrack(SubStreamModel? model, PlaybackModel playbackModel);
  Future<int> setSecondarySubtitleTrack(SubStreamModel? model, PlaybackModel playbackModel) async => -1;
  Future<int> setAudioTrack(AudioStreamModel? model, PlaybackModel playbackModel);
  void applySubtitleSettings(SubtitleSettingsModel settings) {}

  /// Shifts subtitle timing by [delay]. Positive delays subtitles (shows them
  /// later), negative shows them earlier. No-op for backends that don't
  /// support subtitle sync.
  Future<void> setSubtitleDelay(Duration delay) async {}

  /// Applies Night-Mode Audio (dialogue boost / smart downmix) DSP. This is
  /// libmpv-only today; other backends don't expose a filter-chain API and
  /// no-op here.
  Future<void> setAudioEnhancement({
    required bool enableSmartDownmix,
    required DialogueBoostLevel dialogueBoost,
  }) async {}

  Uri? isValidUrl(String input) {
    try {
      final uri = Uri.tryParse(input);
      if (uri != null && uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return uri;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
