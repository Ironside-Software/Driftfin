import 'package:driftfin/models/items/media_streams_model.dart';

/// Selects a secondary track without changing mpv's primary subtitle selection.
Future<int> selectMpvSecondarySubtitle({
  required SubStreamModel? subtitle,
  required List<SubStreamModel> streams,
  required List<String> embeddedTrackIds,
  required Future<String> Function(String) getProperty,
  required Future<void> Function(String, String) setProperty,
  required Future<void> Function(List<String>) command,
}) async {
  if (subtitle == null || subtitle.index == -1) {
    await setProperty('secondary-sid', 'no');
    return -1;
  }

  String? trackId;
  if (subtitle.isExternal) {
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
        .where((stream) => stream.index != -1 && !stream.isExternal)
        .toList()
        .indexWhere((stream) => stream.id == subtitle.id);
    if (index >= 0 && index < embeddedTrackIds.length) trackId = embeddedTrackIds[index];
  }
  if (trackId == null || trackId.isEmpty) throw StateError('Secondary subtitle track is unavailable');
  await setProperty('secondary-sid', trackId);
  return subtitle.index;
}
