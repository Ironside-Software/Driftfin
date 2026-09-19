import 'dart:async';

import 'package:cast_plus/cast.dart';
import 'package:collection/collection.dart';
import 'package:dlna_dart/dlna.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:logging/logging.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.enums.swagger.dart' as enums;
import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart' show SessionInfoDto;
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/image_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/providers/video_player_provider.dart';
import 'package:driftfin/util/duration_extensions.dart';

/// Which target protocol a "Play on…" destination speaks. `jellyfinSession`
/// is another logged-in Jellyfin client, driven via the Sessions API instead
/// of a casting protocol.
enum CastBackend { chromecast, dlna, jellyfinSession }

/// Connection lifecycle for a cast session.
enum CastStatus { disconnected, discovering, connecting, connected, error }

/// A discovered "Play on…" destination — a Chromecast, a DLNA renderer, or
/// another active Jellyfin session (Beam & Handoff).
class CastTarget {
  final String id;
  final String name;
  final CastBackend backend;
  final CastDevice? chromecast;
  final DLNADevice? dlna;
  final SessionInfoDto? session;

  const CastTarget({
    required this.id,
    required this.name,
    required this.backend,
    this.chromecast,
    this.dlna,
    this.session,
  });
}

/// Builds "Play on…" targets from the sessions the current user may remote
/// control, excluding the caller's own session. Pure — unit-tested.
List<CastTarget> sessionCastTargets(List<SessionInfoDto> sessions, {String? myDeviceId}) {
  return sessions
      .where((s) => s.id != null)
      .where((s) => myDeviceId == null || s.deviceId != myDeviceId)
      .where((s) => s.supportsRemoteControl == true)
      .map((s) {
        final label = [s.deviceName, s.userName].nonNulls.where((e) => e.isNotEmpty).join(' · ');
        return CastTarget(
          id: 'session:${s.id}',
          name: label.isNotEmpty ? label : s.id!,
          backend: CastBackend.jellyfinSession,
          session: s,
        );
      })
      .toList();
}

/// The `/Sessions/{id}/Playing` handoff request built from the currently
/// playing item — the exact position + track selection to hand to [sessionId].
/// Pure — unit-tested.
typedef SessionPlayRequest = ({
  String sessionId,
  List<String> itemIds,
  int startPositionTicks,
  String? mediaSourceId,
  int? audioStreamIndex,
  int? subtitleStreamIndex,
});

SessionPlayRequest buildSessionPlayRequest({
  required String sessionId,
  required String itemId,
  required Duration startAt,
  String? mediaSourceId,
  int? audioStreamIndex,
  int? subtitleStreamIndex,
}) {
  return (
    sessionId: sessionId,
    itemIds: [itemId],
    startPositionTicks: startAt.toRuntimeTicks,
    mediaSourceId: mediaSourceId,
    audioStreamIndex: audioStreamIndex,
    subtitleStreamIndex: subtitleStreamIndex,
  );
}

/// Immutable view of the current cast state for the UI.
class CastState {
  final CastStatus status;
  final List<CastTarget> devices;
  final CastTarget? device;
  final Duration position;
  final Duration duration;
  final bool playing;
  final String? error;

  const CastState({
    this.status = CastStatus.disconnected,
    this.devices = const [],
    this.device,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playing = false,
    this.error,
  });

  bool get isCasting => status == CastStatus.connected;

  CastState copyWith({
    CastStatus? status,
    List<CastTarget>? devices,
    CastTarget? device,
    bool clearDevice = false,
    Duration? position,
    Duration? duration,
    bool? playing,
    String? error,
    bool clearError = false,
  }) {
    return CastState(
      status: status ?? this.status,
      devices: devices ?? this.devices,
      device: clearDevice ? null : (device ?? this.device),
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playing: playing ?? this.playing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Builds the Chromecast `LOAD` payload for the default media receiver.
/// Pure function — unit-tested.
Map<String, dynamic> buildLoadMessage({
  required String url,
  required String title,
  String? imageUrl,
  String contentType = 'video/mp4',
  Duration startAt = Duration.zero,
}) {
  return {
    'type': 'LOAD',
    'autoPlay': true,
    'currentTime': startAt.inSeconds,
    'media': {
      'contentId': url,
      'contentType': contentType,
      'streamType': 'BUFFERED',
      'metadata': {
        'type': 0,
        'metadataType': 0,
        'title': title,
        if (imageUrl != null)
          'images': [
            {'url': imageUrl},
          ],
      },
    },
  };
}

/// Parsed view of a Chromecast `MEDIA_STATUS` message. Null when the message
/// carries no status entry. Pure — unit-tested.
typedef MediaStatus = ({int? mediaSessionId, bool? playing, Duration? position, Duration? duration});

MediaStatus? parseMediaStatus(Map<String, dynamic> message) {
  if (message['type'] != 'MEDIA_STATUS') return null;
  final statuses = (message['status'] as List?) ?? const [];
  if (statuses.isEmpty) return null;
  final s = statuses.first as Map<String, dynamic>;
  final current = (s['currentTime'] as num?)?.toDouble();
  final dur = ((s['media'] as Map?)?['duration'] as num?)?.toDouble();
  return (
    mediaSessionId: (s['mediaSessionId'] as num?)?.toInt(),
    playing: s['playerState'] == null ? null : s['playerState'] == 'PLAYING',
    position: current != null ? Duration(milliseconds: (current * 1000).round()) : null,
    duration: dur != null ? Duration(milliseconds: (dur * 1000).round()) : null,
  );
}

/// Builds a Chromecast media-namespace command payload. Pure — unit-tested.
Map<String, dynamic> mediaCommand(String type, int mediaSessionId, [Map<String, dynamic> extra = const {}]) {
  return {'type': type, 'mediaSessionId': mediaSessionId, ...extra};
}

/// Formats a [Duration] as the `H:MM:SS` clock string DLNA AVTransport SEEK
/// expects (REL_TIME target). Pure — unit-tested.
String formatClockTime(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  final h = clamped.inHours;
  final m = clamped.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

final castProvider = StateNotifierProvider<CastController, CastState>((ref) {
  return CastController(ref);
});

/// Runtime cast controller for Chromecast (pure-Dart CASTV2) and DLNA/UPnP
/// MediaRenderers. Independent of the local [BasePlayer] backend — casting is a
/// runtime hand-off, not a settings-time player choice. Reuses the already-built
/// Jellyfin direct-play URL in `PlaybackModel.media.url`.
class CastController extends StateNotifier<CastState> {
  CastController(this.ref) : super(const CastState());

  final Ref ref;
  final _log = Logger('Cast');

  // Default Media Receiver application id.
  static const _defaultReceiverAppId = 'CC1AD845';

  CastBackend? _connected;

  // Chromecast.
  CastSession? _session;
  StreamSubscription? _stateSub;
  StreamSubscription? _messageSub;
  Timer? _statusTimer;
  int? _mediaSessionId;

  // DLNA.
  DLNAManager? _dlna;
  StreamSubscription? _dlnaDevicesSub;
  StreamSubscription? _dlnaPosSub;
  DLNADevice? _dlnaDevice;

  List<CastTarget> _chromecastTargets = const [];
  List<CastTarget> _dlnaTargets = const [];
  List<CastTarget> _sessionTargets = const [];
  Timer? _discoveryTimer;

  // Jellyfin session handoff.
  String? _sessionId;
  Timer? _sessionPollTimer;

  void _publishDevices() {
    if (state.isCasting) return; // don't disturb the controls view while casting
    state = state.copyWith(devices: [..._chromecastTargets, ..._dlnaTargets, ..._sessionTargets]);
  }

  /// Discover "Play on…" targets: Chromecast + DLNA on the local network, and
  /// other Jellyfin sessions the user may remote-control, in parallel.
  Future<void> discover() async {
    if (state.status == CastStatus.discovering) return; // already searching
    state = state.copyWith(status: CastStatus.discovering, clearError: true);
    // End the "searching…" state after a window so the empty-state message can
    // show when nothing is found (DLNA discovery runs continuously and would
    // otherwise leave the spinner up forever).
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer(const Duration(seconds: 6), () {
      if (state.status == CastStatus.discovering) {
        state = state.copyWith(status: CastStatus.disconnected);
      }
    });
    _discoverDlna();
    unawaited(_discoverSessions());
    await _discoverChromecast();
  }

  Future<void> _discoverSessions() async {
    try {
      final myDeviceId = ref.read(userProvider)?.credentials.deviceId;
      final response = await ref.read(jellyApiProvider).getControllableSessions();
      _sessionTargets = sessionCastTargets(response.body ?? const [], myDeviceId: myDeviceId);
      _publishDevices();
    } catch (e, s) {
      _log.warning('Jellyfin session discovery failed', e, s);
    }
  }

  Future<void> _discoverChromecast() async {
    try {
      final devices = await CastDiscoveryService().search();
      _chromecastTargets = devices
          .map(
            (d) =>
                CastTarget(id: 'cc:${d.name}:${d.host}', name: d.name, backend: CastBackend.chromecast, chromecast: d),
          )
          .toList();
      _publishDevices();
    } catch (e, s) {
      _log.warning('Chromecast discovery failed', e, s);
    }
  }

  void _discoverDlna() {
    try {
      _dlnaDevicesSub?.cancel();
      _dlna?.stop(); // close the prior manager's UDP socket before starting a new one
      _dlna = DLNAManager();
      _dlna!.start().then((manager) {
        _dlnaDevicesSub = manager.devices.stream.listen((deviceMap) {
          _dlnaTargets = deviceMap.entries
              .map(
                (e) => CastTarget(
                  id: 'dlna:${e.key}',
                  name: e.value.info.friendlyName,
                  backend: CastBackend.dlna,
                  dlna: e.value,
                ),
              )
              .toList();
          _publishDevices();
        });
      });
    } catch (e, s) {
      _log.warning('DLNA discovery failed', e, s);
    }
  }

  /// Connect to [target] and start casting the current item.
  Future<void> connect(CastTarget target) async {
    if (_currentMedia() == null) {
      state = state.copyWith(status: CastStatus.error, error: 'No media to cast', clearDevice: true);
      return;
    }
    await _teardown();
    state = state.copyWith(status: CastStatus.connecting, device: target, clearError: true);
    switch (target.backend) {
      case CastBackend.chromecast:
        await _connectChromecast(target);
      case CastBackend.dlna:
        await _connectDlna(target);
      case CastBackend.jellyfinSession:
        await _connectSession(target);
    }
  }

  ({
    String url,
    String title,
    String? image,
    Duration startAt,
    Duration duration,
    String itemId,
    String? mediaSourceId,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  })?
  _currentMedia() {
    final model = ref.read(playBackModel);
    final url = model?.media?.url;
    if (model == null || url == null) return null;
    final image = ref.read(imageUtilityProvider).getItemsImageUrl(model.item.id);
    final lastState = ref.read(videoPlayerProvider).lastState;
    return (
      url: url,
      title: model.item.name,
      image: image.isNotEmpty ? image : null,
      startAt: lastState?.position ?? Duration.zero,
      duration: lastState?.duration ?? Duration.zero,
      itemId: model.item.id,
      mediaSourceId: model.mediaStreams?.currentVersionStream?.id,
      audioStreamIndex: model.mediaStreams?.defaultAudioStreamIndex,
      subtitleStreamIndex: model.mediaStreams?.defaultSubStreamIndex,
    );
  }

  // --- Chromecast ---------------------------------------------------------

  Future<void> _connectChromecast(CastTarget target) async {
    final device = target.chromecast;
    if (device == null) return;
    try {
      final session = await CastSessionManager().startSession(device);
      _session = session;
      _connected = CastBackend.chromecast;

      // The package emits `connected` only after a receiver app launches (it
      // needs the app's transportId). So: launch now, load on connected.
      _stateSub = session.stateStream.listen((s) {
        if (s == CastSessionState.connected) {
          _loadChromecast();
        } else if (s == CastSessionState.closed) {
          _onClosed();
        }
      });
      _messageSub = session.messageStream.listen(_onChromecastMessage);

      ref.read(videoPlayerProvider).pause();
      session.sendMessage(CastSession.kNamespaceReceiver, {'type': 'LAUNCH', 'appId': _defaultReceiverAppId});
    } catch (e, s) {
      _log.warning('Chromecast connect failed', e, s);
      state = state.copyWith(status: CastStatus.error, error: e.toString(), clearDevice: true);
      await _teardown();
    }
  }

  void _onChromecastMessage(Map<String, dynamic> message) {
    final status = parseMediaStatus(message);
    if (status == null) return;
    _mediaSessionId = status.mediaSessionId ?? _mediaSessionId;
    state = state.copyWith(
      status: CastStatus.connected,
      playing: status.playing,
      position: status.position,
      duration: status.duration,
    );
    _statusTimer ??= Timer.periodic(const Duration(seconds: 2), (_) => _chromecastMedia('GET_STATUS'));
  }

  void _loadChromecast() {
    final session = _session;
    final media = _currentMedia();
    if (session == null || media == null) return;
    session.sendMessage(
      CastSession.kNamespaceMedia,
      buildLoadMessage(url: media.url, title: media.title, imageUrl: media.image, startAt: media.startAt),
    );
    state = state.copyWith(status: CastStatus.connected);
  }

  void _chromecastMedia(String type, [Map<String, dynamic> extra = const {}]) {
    final session = _session;
    final id = _mediaSessionId;
    if (session == null || id == null) return;
    session.sendMessage(CastSession.kNamespaceMedia, mediaCommand(type, id, extra));
  }

  // --- DLNA ---------------------------------------------------------------

  Future<void> _connectDlna(CastTarget target) async {
    final device = target.dlna;
    final media = _currentMedia();
    if (device == null || media == null) {
      state = state.copyWith(status: CastStatus.error, error: 'No media to cast', clearDevice: true);
      return;
    }
    try {
      _dlnaDevice = device;
      _connected = CastBackend.dlna;
      ref.read(videoPlayerProvider).pause();
      await device.setUrl(media.url, title: media.title);
      await device.play();
      device.positionPoller.start();
      _dlnaPosSub = device.currPosition.stream.listen((p) {
        state = state.copyWith(
          status: CastStatus.connected,
          position: Duration(seconds: p.RelTimeInt),
          duration: Duration(seconds: p.TrackDurationInt),
        );
      });
      state = state.copyWith(status: CastStatus.connected, playing: true);
    } catch (e, s) {
      _log.warning('DLNA connect failed', e, s);
      state = state.copyWith(status: CastStatus.error, error: e.toString(), clearDevice: true);
      await _teardown();
    }
  }

  // --- Jellyfin session (Beam & Handoff) ----------------------------------

  Future<void> _connectSession(CastTarget target) async {
    final sessionId = target.session?.id;
    final media = _currentMedia();
    if (sessionId == null || media == null) {
      state = state.copyWith(status: CastStatus.error, error: 'No media to cast', clearDevice: true);
      return;
    }
    try {
      _connected = CastBackend.jellyfinSession;
      _sessionId = sessionId;
      ref.read(videoPlayerProvider).pause();
      final request = buildSessionPlayRequest(
        sessionId: sessionId,
        itemId: media.itemId,
        startAt: media.startAt,
        mediaSourceId: media.mediaSourceId,
        audioStreamIndex: media.audioStreamIndex,
        subtitleStreamIndex: media.subtitleStreamIndex,
      );
      await ref
          .read(jellyApiProvider)
          .sessionsSessionIdPlayingPost(
            sessionId: request.sessionId,
            itemIds: request.itemIds,
            startPositionTicks: request.startPositionTicks,
            mediaSourceId: request.mediaSourceId,
            audioStreamIndex: request.audioStreamIndex,
            subtitleStreamIndex: request.subtitleStreamIndex,
          );
      state = state.copyWith(status: CastStatus.connected, playing: true, duration: media.duration);
      _sessionPollTimer?.cancel();
      _sessionPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollSession());
    } catch (e, s) {
      _log.warning('Session handoff failed', e, s);
      state = state.copyWith(status: CastStatus.error, error: e.toString(), clearDevice: true);
      await _teardown();
    }
  }

  /// Polls the handed-off session's reported play state, since Jellyfin
  /// sessions push updates over WebSocket rather than back to us directly.
  Future<void> _pollSession() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    try {
      final response = await ref.read(jellyApiProvider).getControllableSessions();
      final session = (response.body ?? const []).firstWhereOrNull((s) => s.id == sessionId);
      if (session == null) {
        await disconnect(); // remote ended playback / logged out
        return;
      }
      final playState = session.playState;
      state = state.copyWith(
        status: CastStatus.connected,
        playing: playState?.isPaused == false,
        position: playState?.positionTicks?.fromRuntimeTicks ?? state.position,
      );
    } catch (e, s) {
      _log.warning('Session poll failed', e, s);
    }
  }

  void _sessionCommand(enums.SessionsSessionIdPlayingCommandPostCommand command, {int? seekPositionTicks}) {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    ref
        .read(jellyApiProvider)
        .sessionsSessionIdPlayingCommandPost(
          sessionId: sessionId,
          command: command,
          seekPositionTicks: seekPositionTicks,
        )
        .ignore();
  }

  // --- Unified controls ---------------------------------------------------

  // DLNA control calls are SOAP POSTs that can throw if the renderer drops;
  // they're fire-and-forget here, so swallow errors to avoid unhandled async
  // exceptions (state is corrected by the position poller / next command).
  void _dlnaFireForget(Future<String>? f) {
    f?.then((_) {}, onError: (Object e, StackTrace s) => _log.warning('DLNA command failed', e, s));
  }

  void play() {
    switch (_connected) {
      case CastBackend.chromecast:
        _chromecastMedia('PLAY');
      case CastBackend.dlna:
        _dlnaFireForget(_dlnaDevice?.play());
        state = state.copyWith(playing: true);
      case CastBackend.jellyfinSession:
        _sessionCommand(enums.SessionsSessionIdPlayingCommandPostCommand.unpause);
        state = state.copyWith(playing: true);
      case null:
        break;
    }
  }

  void pause() {
    switch (_connected) {
      case CastBackend.chromecast:
        _chromecastMedia('PAUSE');
      case CastBackend.dlna:
        _dlnaFireForget(_dlnaDevice?.pause());
        state = state.copyWith(playing: false);
      case CastBackend.jellyfinSession:
        _sessionCommand(enums.SessionsSessionIdPlayingCommandPostCommand.pause);
        state = state.copyWith(playing: false);
      case null:
        break;
    }
  }

  void seek(Duration to) {
    switch (_connected) {
      case CastBackend.chromecast:
        _chromecastMedia('SEEK', {'currentTime': to.inSeconds});
      case CastBackend.dlna:
        _dlnaFireForget(_dlnaDevice?.seek(formatClockTime(to)));
      case CastBackend.jellyfinSession:
        _sessionCommand(enums.SessionsSessionIdPlayingCommandPostCommand.seek, seekPositionTicks: to.toRuntimeTicks);
        state = state.copyWith(position: to);
      case null:
        break;
    }
  }

  void _onClosed() {
    _teardown();
    state = const CastState();
  }

  /// Stop casting and tear down the session.
  Future<void> disconnect() async {
    switch (_connected) {
      case CastBackend.chromecast:
        _chromecastMedia('STOP');
      case CastBackend.dlna:
        try {
          await _dlnaDevice?.stop();
        } catch (_) {}
      case CastBackend.jellyfinSession:
        _sessionCommand(enums.SessionsSessionIdPlayingCommandPostCommand.stop);
      case null:
        break;
    }
    await _teardown();
    state = const CastState();
  }

  Future<void> _teardown() async {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    await _dlnaDevicesSub?.cancel();
    _dlnaDevicesSub = null;
    _dlna?.stop(); // stop SSDP discovery; the connected DLNADevice has its own socket
    _dlna = null;
    _statusTimer?.cancel();
    _statusTimer = null;
    await _stateSub?.cancel();
    await _messageSub?.cancel();
    _stateSub = null;
    _messageSub = null;
    _mediaSessionId = null;
    try {
      await _session?.close();
    } catch (_) {}
    _session = null;

    await _dlnaPosSub?.cancel();
    _dlnaPosSub = null;
    _dlnaDevice?.positionPoller.stop();
    _dlnaDevice = null;

    _sessionPollTimer?.cancel();
    _sessionPollTimer = null;
    _sessionId = null;

    _connected = null;
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }
}
