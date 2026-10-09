import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/items/media_streams_model.dart';
import 'package:driftfin/models/playback/direct_playback_model.dart';
import 'package:driftfin/models/playback/playback_model.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/video_player_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/video_player/components/video_player_screenshot_indicator.dart';
import 'package:driftfin/screens/video_player/video_player_controls.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';
import 'package:driftfin/wrappers/players/player_capabilities.dart';

import 'mpv_secondary_subtitle_test.dart' show subtitle;
import 'support/video_player_test_support.dart';

class _Player extends FakeBasePlayer {
  _Player() : super(capabilities: const PlayerCapabilities(secondarySubtitles: true, screenshots: true));
  int primary = -1;
  int secondary = -1;
  @override
  Future<int> setSubtitleTrack(model, playbackModel) async => primary = model?.index ?? -1;
  @override
  Future<int> setSecondarySubtitleTrack(model, playbackModel) async => secondary = model?.index ?? -1;
}

class _Notifier extends FakeVideoPlayerNotifier {
  _Notifier(super.ref);
  late _Player player;
  bool failScreenshot = false;
  final captures = <(int, int)>[];
  @override
  Future<bool> takeScreenshot() async {
    captures.add((player.primary, player.secondary));
    if (failScreenshot) throw StateError('capture failed');
    return true;
  }
}

class _Helper extends PlaybackModelHelper {
  _Helper({required super.ref});
  @override
  Future<void> shouldReload(PlaybackModel playbackModel) async {}
}

const _layout = AdaptiveLayoutModel(
  viewSize: ViewSize.desktop,
  layoutMode: LayoutMode.single,
  inputDevice: InputDevice.pointer,
  platform: TargetPlatform.linux,
  isDesktop: true,
  posterDefaults: PosterDefaults(size: 100, ratio: 0.66),
  controller: <HomeTabs, ScrollController>{},
  sideBarWidth: 0,
  topBarHeight: 0,
  statusBarHeight: 0,
);

void main() {
  late ProviderContainer container;
  late _Notifier notifier;
  late DirectPlaybackModel model;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    model = DirectPlaybackModel(
      item: testItem(),
      media: testPlaybackModel().media,
      mediaStreams: MediaStreamsModel(
        defaultSubStreamIndex: 4,
        versionStreams: [
          VersionStreamModel(
            name: 'Video',
            index: 0,
            defaultAudioStreamIndex: -1,
            defaultSubStreamIndex: 4,
            videoStreams: [],
            audioStreams: [],
            subStreams: [subtitle(4), subtitle(7)],
          ),
        ],
      ),
    );
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        videoPlayerProvider.overrideWith((ref) => _Notifier(ref)),
        playBackModel.overrideWith((ref) => model),
        playbackModelHelper.overrideWith((ref) => _Helper(ref: ref)),
      ],
    );
    notifier = container.read(videoPlayerProvider.notifier) as _Notifier;
    notifier.player = _Player();
    await notifier.state.setup(notifier.player);
    await notifier.state.setSubtitleTrack(model.subStreams[1], model);
    await notifier.state.setSecondarySubtitleTrack(model.subStreams.last, model);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('pip'),
      (call) async => null,
    );
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: AdaptiveLayout(
          data: _layout,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final fail in [false, true]) {
    testWidgets('clean screenshot hides both tracks and restores them when capture fails: $fail', (tester) async {
      notifier.failScreenshot = fail;
      final key = GlobalKey<VideoPlayerScreenshotIndicatorState>();
      await pump(tester, VideoPlayerScreenshotIndicator(key: key));
      await key.currentState!.onTakeScreenshot(true);
      expect(notifier.captures, [(-1, -1)]);
      expect(notifier.player.primary, 4);
      expect(notifier.player.secondary, 7);
      expect(container.read(secondarySubtitleProvider), 7);
      expect(container.read(playBackModel)?.mediaStreams?.defaultSubStreamIndex, 4);
      expect(key.currentState!.screenshotTaken, !fail);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final primary in [4, -1]) {
    testWidgets('subtitle hotkey hides and restores both selections with primary $primary', (tester) async {
      if (primary == -1) {
        final off = await model.setSubtitle(SubStreamModel.no(), notifier.state);
        container.read(playBackModel.notifier).state = off;
      }
      await pump(tester, const DesktopControls());
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pumpAndSettle();
      expect(notifier.player.primary, -1);
      expect(notifier.player.secondary, -1);
      expect(container.read(secondarySubtitleProvider), -1);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pumpAndSettle();
      expect(notifier.player.primary, primary);
      expect(notifier.player.secondary, 7);
      expect(container.read(secondarySubtitleProvider), 7);
      expect(container.read(playBackModel)?.mediaStreams?.defaultSubStreamIndex, primary);
    });
  }
}
