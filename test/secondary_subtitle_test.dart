import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/items/media_streams_model.dart';
import 'package:driftfin/models/playback/direct_playback_model.dart';
import 'package:driftfin/models/settings/subtitle_settings_model.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/video_player_provider.dart';
import 'package:driftfin/screens/video_player/components/video_player_options_sheet.dart';
import 'package:driftfin/wrappers/players/lib_mpv.dart';
import 'package:driftfin/wrappers/players/player_capabilities.dart';

import 'mpv_secondary_subtitle_test.dart' show subtitle;
import 'support/video_player_test_support.dart';

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
        child: MaterialApp(
          home: Scaffold(
            body: DualSubtitleOverlay(
              subtitles: const ['Primary\nline two', 'Secondary'],
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
