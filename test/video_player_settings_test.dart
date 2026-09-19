import 'package:driftfin/models/items/media_segments_model.dart';
import 'package:driftfin/models/settings/arguments_model.dart';
import 'package:driftfin/models/settings/key_combinations.dart';
import 'package:driftfin/models/settings/video_player_settings.dart';
import 'package:driftfin/util/audio_filter_chain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoPlayerSettingsModel.wantedPlayer', () {
    setUp(() {
      leanBackMode = false;
    });

    tearDown(() {
      leanBackMode = false;
    });

    test('leanBackMode forces the native player regardless of playerOptions', () {
      leanBackMode = true;
      final model = VideoPlayerSettingsModel(playerOptions: PlayerOptions.libMPV);
      expect(model.wantedPlayer, PlayerOptions.nativePlayer);
    });

    test('uses the explicit playerOptions when set and not in leanBackMode', () {
      final model = VideoPlayerSettingsModel(playerOptions: PlayerOptions.libMDK);
      expect(model.wantedPlayer, PlayerOptions.libMDK);
    });

    test('falls back to platformDefaults when playerOptions is null', () {
      final model = VideoPlayerSettingsModel();
      expect(model.wantedPlayer, PlayerOptions.platformDefaults);
    });
  });

  group('VideoPlayerSettingsModel Night-Mode Audio defaults', () {
    test('smart downmix and dialogue boost default to off', () {
      final model = VideoPlayerSettingsModel();
      expect(model.enableSmartDownmix, isFalse);
      expect(model.dialogueBoost, DialogueBoostLevel.off);
    });

    test('round-trips through JSON', () {
      final model = VideoPlayerSettingsModel(
        enableSmartDownmix: true,
        dialogueBoost: DialogueBoostLevel.high,
      );
      final restored = VideoPlayerSettingsModel.fromJson(model.toJson());
      expect(restored.enableSmartDownmix, isTrue);
      expect(restored.dialogueBoost, DialogueBoostLevel.high);
    });
  });

  group('VideoPlayerSettingsModel.volume', () {
    test('uses system volume on mobile and internal volume on desktop', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final model = VideoPlayerSettingsModel(internalVolume: 42);
      expect(model.volume, 100);
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(model.volume, 42);
    });
  });

  group('VideoPlayerSettingsModel.currentShortcuts / defaultShortCuts', () {
    test('defaultShortCuts contains every VideoHotKeys entry', () {
      final model = VideoPlayerSettingsModel();
      expect(model.defaultShortCuts.keys.toSet(), VideoHotKeys.values.toSet());
    });

    test('currentShortcuts overrides only the configured hot key', () {
      final overridden = KeyCombination(key: LogicalKeyboardKey.keyZ);
      final model = VideoPlayerSettingsModel(hotKeys: {VideoHotKeys.mute: overridden});

      expect(model.currentShortcuts[VideoHotKeys.mute], overridden);
      expect(model.currentShortcuts[VideoHotKeys.playPause], model.defaultShortCuts[VideoHotKeys.playPause]);
      expect(model.currentShortcuts.length, VideoHotKeys.values.length);
    });

    test('currentShortcuts with no overrides equals defaultShortCuts', () {
      final model = VideoPlayerSettingsModel();
      expect(model.currentShortcuts, model.defaultShortCuts);
    });
  });

  group('VideoPlayerSettingsModel.playerSame', () {
    test('true when the player-relevant fields match even if others differ', () {
      final a = VideoPlayerSettingsModel(
        hardwareAccel: true,
        enableTunneling: false,
        useLibass: true,
        bufferSize: 32,
        playerOptions: PlayerOptions.libMPV,
        screenBrightness: 0.2,
      );
      final b = VideoPlayerSettingsModel(
        hardwareAccel: true,
        enableTunneling: false,
        useLibass: true,
        bufferSize: 32,
        playerOptions: PlayerOptions.libMPV,
        screenBrightness: 0.9,
      );
      expect(a.playerSame(b), isTrue);
    });

    test('false when bufferSize differs', () {
      final a = VideoPlayerSettingsModel(bufferSize: 32);
      final b = VideoPlayerSettingsModel(bufferSize: 64);
      expect(a.playerSame(b), isFalse);
    });

    test('false when hardwareAccel differs', () {
      final a = VideoPlayerSettingsModel(hardwareAccel: true);
      final b = VideoPlayerSettingsModel(hardwareAccel: false);
      expect(a.playerSame(b), isFalse);
    });

    test('false when wantedPlayer differs because playerOptions differ', () {
      final a = VideoPlayerSettingsModel(playerOptions: PlayerOptions.libMPV);
      final b = VideoPlayerSettingsModel(playerOptions: PlayerOptions.libMDK);
      expect(a.playerSame(b), isFalse);
    });

    test('leanBackMode forces both models to nativePlayer, making them playerSame', () {
      // wantedPlayer is a live getter over the global leanBackMode flag, so once it is
      // enabled every model (regardless of playerOptions) reports nativePlayer.
      final a = VideoPlayerSettingsModel(playerOptions: PlayerOptions.libMPV);
      leanBackMode = true;
      addTearDown(() => leanBackMode = false);
      final b = VideoPlayerSettingsModel(playerOptions: PlayerOptions.libMDK);
      expect(a.playerSame(b), isTrue);
    });
  });

  group('VideoPlayerSettingsModel equality/hashCode (hand-written operator==)', () {
    test('models with same tracked fields but different segmentSkipSettings are still ==', () {
      final a = VideoPlayerSettingsModel(segmentSkipSettings: const {});
      final b = VideoPlayerSettingsModel(segmentSkipSettings: defaultSegmentSkipValues);
      expect(a == b, isTrue, reason: 'segmentSkipSettings is excluded from the hand-written operator==');
      expect(a.hashCode, b.hashCode);
    });

    test('differing audioDevice makes models unequal', () {
      final a = VideoPlayerSettingsModel(audioDevice: 'a');
      final b = VideoPlayerSettingsModel(audioDevice: 'b');
      expect(a == b, isFalse);
    });

    test('differing bufferSize makes models unequal', () {
      final a = VideoPlayerSettingsModel(bufferSize: 32);
      final b = VideoPlayerSettingsModel(bufferSize: 64);
      expect(a == b, isFalse);
    });
  });

  group('VideoPlayerSettingsModel.canUseCrossfade / crossfadeSupportedOnCurrentPlatform', () {
    test('is true when overridden to a desktop platform', () {
      // flutter_test defaults defaultTargetPlatform to TargetPlatform.android regardless of the
      // host OS, so explicitly override to a crossfade-supported desktop platform here.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(VideoPlayerSettingsModel.crossfadeSupportedOnCurrentPlatform, isTrue);
      expect(VideoPlayerSettingsModel().canUseCrossfade, isTrue);
    });

    test('is false when overridden to android or iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(VideoPlayerSettingsModel.crossfadeSupportedOnCurrentPlatform, isFalse);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(VideoPlayerSettingsModel.crossfadeSupportedOnCurrentPlatform, isFalse);
    });
  });

  group('PlayerOptions.available / platformDefaults', () {
    setUp(() {
      leanBackMode = false;
      debugDefaultTargetPlatformOverride = null;
    });

    tearDown(() {
      leanBackMode = false;
      debugDefaultTargetPlatformOverride = null;
    });

    test('leanBackMode restricts availability to nativePlayer only', () {
      leanBackMode = true;
      expect(PlayerOptions.available, {PlayerOptions.nativePlayer});
      expect(PlayerOptions.platformDefaults, PlayerOptions.nativePlayer);
    });

    test('android (non-leanback) allows every PlayerOptions value', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(PlayerOptions.available, PlayerOptions.values.toSet());
    });

    test('non-android desktop platforms only allow libMDK/libMPV', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(PlayerOptions.available, {PlayerOptions.libMDK, PlayerOptions.libMPV});
      expect(PlayerOptions.platformDefaults, PlayerOptions.libMPV);
    });
  });

  group('clampReplayGainDb', () {
    test('clamps below -60 up to -60', () {
      expect(clampReplayGainDb(-100), -60.0);
    });

    test('caps positive replay gain at zero', () {
      expect(clampReplayGainDb(100), 0.0);
    });

    test('passes through in-range values unchanged', () {
      expect(clampReplayGainDb(-5), -5.0);
    });
  });

  group('ReplayGainVolumeLevel', () {
    test('replayGainOffsetDb matches the documented per-level offsets', () {
      expect(ReplayGainVolumeLevel.quiet.replayGainOffsetDb, 0.0);
      expect(ReplayGainVolumeLevel.normal.replayGainOffsetDb, 6.0);
      expect(ReplayGainVolumeLevel.loud.replayGainOffsetDb, 8.0);
    });

    test('adjustedReplayGainDb adds the offset to the track gain and clamps', () {
      expect(ReplayGainVolumeLevel.normal.adjustedReplayGainDb(2.0), 0.0);
      expect(ReplayGainVolumeLevel.loud.adjustedReplayGainDb(null), 0.0);
      expect(ReplayGainVolumeLevel.loud.adjustedReplayGainDb(1000), 0.0);
      expect(ReplayGainVolumeLevel.quiet.adjustedReplayGainDb(-1000), -60.0);
    });
  });
}
