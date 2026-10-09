import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/items/media_streams_model.dart';
import 'package:driftfin/models/playback/direct_playback_model.dart';
import 'package:driftfin/models/playback/playback_model.dart';
import 'package:driftfin/models/settings/subtitle_settings_model.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/video_player_provider.dart';
import 'package:driftfin/screens/video_player/components/video_player_options_sheet.dart';
import 'package:driftfin/wrappers/players/lib_mpv.dart';
import 'package:driftfin/wrappers/players/player_capabilities.dart';

import 'mpv_secondary_subtitle_test.dart' show subtitle;
import 'support/video_player_test_support.dart';

class _PrimarySubtitlePlayer extends FakeBasePlayer {
  _PrimarySubtitlePlayer() : super(capabilities: const PlayerCapabilities(secondarySubtitles: true));

  @override
  Future<int> setSubtitleTrack(model, playbackModel) async => model?.index ?? -1;
}

class _PickerPlaybackHelper extends PlaybackModelHelper {
  _PickerPlaybackHelper({required super.ref});

  int reloadChecks = 0;

  @override
  Future<void> shouldReload(PlaybackModel playbackModel) async {
    reloadChecks++;
  }
}

void main() {
  late ProviderContainer container;
  late FakeVideoPlayerNotifier notifier;
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
        videoPlayerProvider.overrideWith((ref) => FakeVideoPlayerNotifier(ref)),
        playBackModel.overrideWith((ref) => model),
        playbackModelHelper.overrideWith((ref) => _PickerPlaybackHelper(ref: ref)),
      ],
    );
    notifier = container.read(videoPlayerProvider.notifier) as FakeVideoPlayerNotifier;
    await notifier.setupFake(capabilities: const PlayerCapabilities(secondarySubtitles: true));
  });

  tearDown(() => container.dispose());

  test('selection is independent; duplicate primary is rejected; Off clears it', () async {
    await notifier.state.setSecondarySubtitleTrack(model.subStreams.last, model);
    expect(container.read(secondarySubtitleProvider), 7);
    expect(model.mediaStreams?.defaultSubStreamIndex, 4);
    await notifier.state.setSecondarySubtitleTrack(model.subStreams[1], model);
    expect(container.read(secondarySubtitleProvider), 7);
    await notifier.state.setSecondarySubtitleTrack(SubStreamModel.no(), model);
    expect(container.read(secondarySubtitleProvider), -1);
  });

  test('bitmap subtitle selection is rejected without replacing the secondary track', () async {
    await notifier.state.setSecondarySubtitleTrack(model.subStreams.last, model);
    for (final codec in [
      'pgs',
      'PGSSUB',
      'hdmv_pgs_subtitle',
      'dvdsub',
      'dvd_subtitle',
      'vobsub',
      'dvbsub',
      'dvb_subtitle',
    ]) {
      await notifier.state.setSecondarySubtitleTrack(subtitle(8).copyWith(codec: codec), model);
      expect(container.read(secondarySubtitleProvider), 7, reason: codec);
    }
  });

  test('selecting the secondary track as primary disables the duplicate', () async {
    await notifier.state.setSecondarySubtitleTrack(model.subStreams.last, model);
    await notifier.state.setSubtitleTrack(model.subStreams.last, model);
    expect(container.read(secondarySubtitleProvider), -1);
  });

  test('backend replacement resets selection and unsupported backends cannot select', () async {
    await notifier.state.setSecondarySubtitleTrack(model.subStreams.last, model);
    await notifier.setupFake();
    expect(container.read(secondarySubtitleProvider), -1);
    await notifier.state.setSecondarySubtitleTrack(model.subStreams.last, model);
    expect(container.read(secondarySubtitleProvider), -1);
  });

  test('loading another video resets selection', () async {
    await notifier.state.setSecondarySubtitleTrack(model.subStreams.last, model);
    await notifier.state.loadVideo(model, Duration.zero, true);
    expect(container.read(secondarySubtitleProvider), -1);
  });

  Future<void> pumpPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(onPressed: () => showSubSelection(context), child: const Text('Select subtitles'));
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Select subtitles'));
    await tester.pumpAndSettle();
  }

  testWidgets('picker selects a secondary track and turns it off', (tester) async {
    await pumpPicker(tester);
    await tester.tap(find.text('Secondary subtitle'));
    await tester.pumpAndSettle();
    final primary = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Subtitle 4').last);
    expect(primary.enabled, isFalse);
    await tester.tap(find.text('Subtitle 7').last);
    await tester.pumpAndSettle();
    expect(container.read(secondarySubtitleProvider), 7);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Subtitle 7').last).selected, isTrue);
    await tester.tap(find.text('Off').last);
    await tester.pumpAndSettle();
    expect(container.read(secondarySubtitleProvider), -1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('primary picker promotes secondary track and clears the duplicate', (tester) async {
    await notifier.state.setup(_PrimarySubtitlePlayer());
    await notifier.state.setSecondarySubtitleTrack(model.subStreams.last, model);
    await pumpPicker(tester);
    await tester.tap(find.text('Subtitle 7').last);
    await tester.pumpAndSettle();

    expect(container.read(playBackModel)?.mediaStreams?.defaultSubStreamIndex, 7);
    expect(container.read(secondarySubtitleProvider), -1);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Subtitle 7')).selected, isTrue);
    expect((container.read(playbackModelHelper) as _PickerPlaybackHelper).reloadChecks, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('secondary picker disables bitmap tracks but keeps text tracks and Off selectable', (tester) async {
    final streams = model.mediaStreams!.versionStreams.first.subStreams;
    streams.addAll([
      subtitle(8).copyWith(codec: 'pgssub'),
      subtitle(9).copyWith(codec: 'dvdsub'),
      subtitle(10).copyWith(codec: 'dvbsub'),
    ]);
    await pumpPicker(tester);
    // Primary subtitles still support bitmap formats.
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Subtitle 8')).enabled, isTrue);
    await tester.tap(find.text('Secondary subtitle'));
    await tester.pumpAndSettle();
    for (final index in [8, 9, 10]) {
      expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Subtitle $index').last).enabled, isFalse);
    }
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Subtitle 7').last).enabled, isTrue);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Off').last).enabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsupported backend explains the disabled picker', (tester) async {
    await notifier.setupFake();
    await pumpPicker(tester);
    expect(find.text('Requires the libmpv player'), findsOneWidget);
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, 'Secondary subtitle')).enabled, isFalse);
  });

  testWidgets('overlay keeps primary and secondary text in separate positions', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: DualSubtitleOverlay(
              subtitles: ['Primary\nline two', 'Secondary'],
              settings: SubtitleSettingsModel(),
              padding: EdgeInsets.zero,
              primaryOffset: 0.1,
            ),
          ),
        ),
      ),
    );
    final subtitles = tester.widgetList<SubtitleText>(find.byType(SubtitleText)).toList();
    expect(subtitles.map((widget) => widget.text), ['Primary\nline two', 'Secondary']);
    expect(subtitles.map((widget) => widget.offset), [0.1, 0.9]);
    expect(
      tester.getTopLeft(find.text('Secondary').first).dy,
      lessThan(tester.getTopLeft(find.text('Primary\nline two').first).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
