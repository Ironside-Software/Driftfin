import 'package:driftfin/models/items/media_streams_model.dart';
import 'package:driftfin/models/playback/playback_model.dart';
import 'package:driftfin/models/playback/transcode_playback_model.dart';

/// mpv's secondary subtitle renderer supports text, but not bitmap formats.
bool supportsMpvSecondarySubtitle(SubStreamModel subtitle) => !const {
  'pgs',
  'pgssub',
  'hdmv_pgs_subtitle',
  'dvdsub',
  'dvd_subtitle',
  'vobsub',
  'dvbsub',
  'dvb_subtitle',
}.contains(subtitle.codec.toLowerCase());

/// Transcoding can deliver originally embedded streams as external subtitles.
bool mpvSubtitleUsesExternalStream(SubStreamModel subtitle, PlaybackModel? playbackModel) =>
    subtitle.isExternal || playbackModel is TranscodePlaybackModel && subtitle.supportsExternalStream;

/// Set both slots even with secondary subtitles off, so a later selection stays in sync.
Future<void> setMpvSubtitleDelay(
  Duration delay,
  Future<void> Function(String, String) setProperty, {
  required Future<String> Function(String) getProperty,
}) async {
  final seconds = '${delay.inMilliseconds / 1000.0}';
  await setProperty('sub-delay', seconds);
  // Before mpv 0.38 sub-delay applies to both slots; newer versions have separate delays.
  if ((await getProperty('secondary-sub-delay')).isNotEmpty) {
    await setProperty('secondary-sub-delay', seconds);
  }
}

/// Selects a secondary track without changing mpv's primary subtitle selection.
Future<int> selectMpvSecondarySubtitle({
  required SubStreamModel? subtitle,
  required List<SubStreamModel> streams,
  PlaybackModel? playbackModel,
  required List<String> embeddedTrackIds,
  required Future<String> Function(String) getProperty,
  required Future<void> Function(String, String) setProperty,
  required Future<void> Function(List<String>) command,
}) async {
  if (subtitle == null || subtitle.index == -1) {
    await setProperty('secondary-sid', 'no');
    return -1;
  }

  if (!supportsMpvSecondarySubtitle(subtitle)) throw StateError('Secondary bitmap subtitles are unsupported');

  String? trackId;
  if (mpvSubtitleUsesExternalStream(subtitle, playbackModel)) {
    final url = subtitle.url;
    if (url == null || url.isEmpty) throw StateError('Secondary subtitle has no URL');
    Future<String?> findExternalTrack() async {
      final count = int.tryParse(await getProperty('track-list/count')) ?? 0;
      for (var i = 0; i < count; i++) {
        if (await getProperty('track-list/$i/type') == 'sub' &&
            await getProperty('track-list/$i/external-filename') == url) {
          return getProperty('track-list/$i/id');
        }
      }
      return null;
    }

    trackId = await findExternalTrack();
    if (trackId == null) {
      await command(['sub-add', url, 'auto']);
      trackId = await findExternalTrack();
    }
  } else {
    final index = streams
        .where((stream) => stream.index != -1 && !mpvSubtitleUsesExternalStream(stream, playbackModel))
        .toList()
        .indexWhere((stream) => stream.id == subtitle.id);
    if (index >= 0 && index < embeddedTrackIds.length) trackId = embeddedTrackIds[index];
  }
  if (trackId == null || trackId.isEmpty) throw StateError('Secondary subtitle track is unavailable');
  await setProperty('secondary-sid', trackId);
  return subtitle.index;
}
