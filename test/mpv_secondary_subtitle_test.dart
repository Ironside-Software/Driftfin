import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/models/items/media_streams_model.dart';
import 'package:driftfin/models/playback/playback_model.dart';
import 'package:driftfin/models/playback/transcode_playback_model.dart';

import 'package:driftfin/wrappers/players/mpv_secondary_subtitle.dart';

import 'support/video_player_test_support.dart';

SubStreamModel subtitle(int index, {bool external = false, String? url}) => SubStreamModel(
  name: 'Subtitle $index',
  id: '$index',
  title: 'Subtitle $index',
  displayTitle: 'Subtitle $index',
  language: 'en',
  codec: 'srt',
  isDefault: false,
  isExternal: external,
  index: index,
  url: url,
);

void main() {
  late Map<String, String> properties;
  late List<List<String>> commands;
  late List<(String, String)> writes;

  setUp(() {
    properties = {};
    commands = [];
    writes = [];
  });

  Future<int> select(
    SubStreamModel? track, {
    List<SubStreamModel>? streams,
    List<String>? ids,
    PlaybackModel? playbackModel,
  }) => selectMpvSecondarySubtitle(
    subtitle: track,
    playbackModel: playbackModel,
    streams: streams ?? [],
    embeddedTrackIds: ids ?? [],
    getProperty: (name) async => properties[name] ?? '',
    setProperty: (name, value) async {
      properties[name] = value;
      writes.add((name, value));
    },
    command: (args) async {
      commands.add(args);
      properties.addAll({
        'track-list/count': '1',
        'track-list/0/type': 'sub',
        'track-list/0/external-filename': args[1],
        'track-list/0/id': '17',
      });
    },
  );

  test('Off disables the secondary track only', () async {
    expect(await select(null), -1);
    expect(await select(SubStreamModel.no()), -1);
    expect(writes, [('secondary-sid', 'no'), ('secondary-sid', 'no')]);
    expect(commands, isEmpty);
  });

  test('maps embedded subtitle order to mpv IDs, ignoring external streams and Off', () async {
    final first = subtitle(5);
    final second = subtitle(9);
    expect(
      await select(second, streams: [SubStreamModel.no(), subtitle(2, external: true), first, second], ids: ['3', '8']),
      9,
    );
    expect(writes, [('secondary-sid', '8')]);
  });

  test('loads an external subtitle without selecting it as primary, and reuses it', () async {
    final track = subtitle(12, external: true, url: 'https://server/sub.srt?token=example');
    expect(await select(track), 12);
    expect(commands, [
      ['sub-add', track.url, 'auto'],
    ]);
    expect(writes, [('secondary-sid', '17')]);
    expect(await select(track), 12);
    expect(commands, hasLength(1));
  });

  TranscodePlaybackModel transcode(List<SubStreamModel> streams) => TranscodePlaybackModel(
    item: testItem(),
    media: const Media(url: 'https://server/master.m3u8'),
    playbackInfo: null,
    mediaStreams: MediaStreamsModel(
      versionStreams: [
        VersionStreamModel(
          name: 'Video',
          index: 0,
          defaultAudioStreamIndex: null,
          defaultSubStreamIndex: null,
          videoStreams: [],
          audioStreams: [],
          subStreams: streams,
        ),
      ],
    ),
  );

  test('transcoded originally embedded subtitle loads externally without an embedded mpv track', () async {
    final track = subtitle(5, url: 'https://server/stream/5.srt').copyWith(supportsExternalStream: true);
    final playback = transcode([track]);
    expect(track.isExternal, isFalse);
    expect(mpvSubtitleUsesExternalStream(track, playback), isTrue);
    expect(await select(track, streams: playback.subStreams, playbackModel: playback), 5);
    expect(commands, [
      ['sub-add', track.url, 'auto'],
    ]);
    expect(writes, [('secondary-sid', '17')]);
    expect(await select(track, streams: playback.subStreams, playbackModel: playback), 5);
    expect(commands, hasLength(1));
  });

  test('embedded mapping excludes externally delivered transcode streams', () async {
    final delivered = subtitle(3, url: 'https://server/stream/3.srt').copyWith(supportsExternalStream: true);
    final embedded = subtitle(5);
    final playback = transcode([delivered, embedded]);
    expect(await select(embedded, streams: playback.subStreams, playbackModel: playback, ids: ['8']), 5);
    expect(writes, [('secondary-sid', '8')]);
    expect(commands, isEmpty);
  });

  test('external support does not replace an embedded stream during direct playback', () async {
    final track = subtitle(5, url: 'https://server/stream/5.srt').copyWith(supportsExternalStream: true);
    expect(mpvSubtitleUsesExternalStream(track, testPlaybackModel()), isFalse);
    expect(await select(track, streams: [track], ids: ['8']), 5);
    expect(writes, [('secondary-sid', '8')]);
    expect(commands, isEmpty);
  });

  test('transcode delivery without a URL fails without selecting a missing embedded track', () async {
    final track = subtitle(5).copyWith(supportsExternalStream: true);
    final playback = transcode([track]);
    await expectLater(
      select(track, streams: playback.subStreams, playbackModel: playback, ids: ['8']),
      throwsStateError,
    );
    expect(writes, isEmpty);
    expect(commands, isEmpty);
  });

  test('delay applies to both slots and persists when secondary subtitles are selected later', () async {
    Future<void> setProperty(String key, String value) async {
      properties[key] = value;
      writes.add((key, value));
    }

    properties['secondary-sub-delay'] = '0.0';
    Future<String> getProperty(String name) async => properties[name] ?? '';
    await setMpvSubtitleDelay(const Duration(milliseconds: 1250), setProperty, getProperty: getProperty);
    expect(writes, [('sub-delay', '1.25'), ('secondary-sub-delay', '1.25')]);
    final track = subtitle(5);
    await select(track, streams: [track], ids: ['8']);
    expect(properties['sub-delay'], '1.25');
    expect(properties['secondary-sub-delay'], '1.25');
    await setMpvSubtitleDelay(const Duration(milliseconds: -750), setProperty, getProperty: getProperty);
    expect(properties['sub-delay'], '-0.75');
    expect(properties['secondary-sub-delay'], '-0.75');
    await setMpvSubtitleDelay(Duration.zero, setProperty, getProperty: getProperty);
    expect(properties['sub-delay'], '0.0');
    expect(properties['secondary-sub-delay'], '0.0');
  });

  test('older mpv uses shared sub-delay without attempting unsupported secondary property', () async {
    await setMpvSubtitleDelay(const Duration(milliseconds: 750), (name, value) async {
      properties[name] = value;
      writes.add((name, value));
    }, getProperty: (name) async => '');
    expect(writes, [('sub-delay', '0.75')]);
    await select(subtitle(5), streams: [subtitle(5)], ids: ['8']);
    expect(properties['sub-delay'], '0.75');
    expect(properties, isNot(contains('secondary-sub-delay')));
  });

  test('delay property read failures propagate instead of being mistaken for old mpv', () async {
    final failure = StateError('Player disposed');
    await expectLater(
      setMpvSubtitleDelay(
        const Duration(milliseconds: 750),
        (name, value) async => writes.add((name, value)),
        getProperty: (name) async => throw failure,
      ),
      throwsA(same(failure)),
    );
    expect(writes, [('sub-delay', '0.75')]);
  });

  test('bitmap secondary subtitles are rejected without changing either subtitle slot', () async {
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
      final track = subtitle(5).copyWith(codec: codec);
      expect(supportsMpvSecondarySubtitle(track), isFalse);
      await expectLater(select(track, streams: [track], ids: ['8']), throwsStateError);
    }
    for (final codec in ['srt', 'ASS', 'ssa', 'webvtt', 'mov_text']) {
      expect(supportsMpvSecondarySubtitle(subtitle(5).copyWith(codec: codec)), isTrue);
    }
    expect(writes, isEmpty);
    expect(commands, isEmpty);
  });

  test('unavailable tracks fail without changing the selected secondary track', () async {
    await expectLater(select(subtitle(7), streams: [subtitle(7)]), throwsStateError);
    await expectLater(select(subtitle(8, external: true)), throwsStateError);
    expect(writes, isEmpty);
    expect(commands, isEmpty);
  });
}
