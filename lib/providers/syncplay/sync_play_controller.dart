import 'dart:async';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/playback/playback_model.dart';
import 'package:driftfin/models/syncplay/sync_play_models.dart';
import 'package:driftfin/models/syncplay/sync_play_state.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/syncplay/jellyfin_socket.dart';
import 'package:driftfin/providers/syncplay/sync_play_relay.dart';
import 'package:driftfin/providers/syncplay/time_sync_service.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/providers/video_player_provider.dart';
import 'package:driftfin/wrappers/media_control_wrapper.dart';
import 'package:driftfin/wrappers/players/player_states.dart';

/// Jellyfin time ticks are 100-nanosecond units.
int _ticksFromDuration(Duration d) => d.inMicroseconds * 10;
Duration _durationFromTicks(int ticks) => Duration(microseconds: ticks ~/ 10);

/// Drives a Jellyfin SyncPlay ("Watch Together") session: owns the WebSocket and
/// time-sync services, routes group-update and scheduled-command messages, keeps
/// the local player aligned with the group via drift correction, and reports
/// buffering/ready so the group waits for slow members.
class SyncPlayController extends StateNotifier<SyncPlayState> {
  SyncPlayController(this.ref, {http.Client? httpClient, @visibleForTesting SyncPlayState? initialState})
    : _httpClient = httpClient ?? http.Client(),
      super(initialState ?? const SyncPlayState());

  final Ref ref;
  final http.Client _httpClient;

  final JellyfinSocket _socket = JellyfinSocket();
  TimeSyncService? _timeSync;

  StreamSubscription<Map<String, dynamic>>? _msgSub;
  StreamSubscription<SyncPlayConnection>? _connSub;
  StreamSubscription<PlayerState>? _playerSub;
  Timer? _commandTimer;
  Timer? _driftTimer;
  final Map<String, Timer> _presenceExpiryTimers = {};

  bool _wired = false;
  bool _lastBuffering = false;
  bool _typingSent = false;

  // Drift correction anchor: where the group expects playback to be, and from when.
  Duration _anchorPosition = Duration.zero;
  DateTime _anchorAt = DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true);
  bool _anchorPlaying = false;
  bool _nudging = false; // currently holding a catch-up speed
  double _userSpeed = 1.0; // the user's speed captured before a nudge
  DateTime _driftCooldownUntil = DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true);
  bool _loadingItem = false;

  static const _nudgeThreshold = Duration(milliseconds: 300);
  static const _seekThreshold = Duration(milliseconds: 2000);

  /// PlaylistItemId the group is currently playing (from PlayQueue updates),
  /// reported back in buffering/ready messages.
  String? _currentPlaylistItemId;

  /// Set when the group is playing an item we couldn't auto-load; the UI prompts
  /// the user to open it. Null when in sync.
  String? pendingItemId;

  JellyfinOpenApi get _api => ref.read(jellyApiProvider).api;
  MediaControlsWrapper get _player => ref.read(videoPlayerProvider);

  // ---- Public API ---------------------------------------------------------

  Future<List<GroupInfoDto>> listGroups() async {
    try {
      final resp = await _api.syncPlayListGet();
      return resp.body ?? const [];
    } catch (e) {
      log('SyncPlay listGroups failed: $e');
      return const [];
    }
  }

  Future<void> createGroup({String? name}) async {
    _ensureWired();
    try {
      final groupName = (name == null || name.trim().isEmpty) ? _defaultGroupName() : name.trim();
      final resp = await _api.syncPlayNewPost(body: NewGroupRequestDto(groupName: groupName));
      if (!mounted) return;
      // Apply membership from the REST response so it doesn't depend on the
      // socket push winning the race against this request completing.
      final info = resp.body?.toJson();
      if (info != null) _applyGroupInfo(info);
      await _seedCurrentQueue();
    } catch (e) {
      _setError('Failed to create group: $e');
    }
  }

  Future<void> joinGroup(String groupId) async {
    _ensureWired();
    try {
      await _api.syncPlayJoinPost(body: JoinGroupRequestDto(groupId: groupId));
      if (!mounted) return;
      // Join returns no body; confirm membership over REST as a fallback to the
      // socket GroupJoined push (idempotent if the push already arrived).
      await _confirmMembership(groupId);
    } catch (e) {
      _setError('Failed to join group: $e');
    }
  }

  Future<void> leaveGroup() async {
    try {
      await _api.syncPlayLeavePost();
    } catch (e) {
      log('SyncPlay leave failed: $e');
    }
    _clearGroup();
  }

  /// Routed from the player when the user toggles play/pause in a group: ask the
  /// server, which schedules the action for everyone (including us).
  Future<void> userTogglePlayPause() async {
    if (!state.inGroup) return;
    final playing = _player.lastState?.playing ?? false;
    try {
      if (playing) {
        await _api.syncPlayPausePost();
      } else {
        await _api.syncPlayUnpausePost();
      }
    } catch (e) {
      log('SyncPlay toggle failed: $e');
    }
  }

  /// Send a chat message to the group. SyncPlay has no chat channel, so this is
  /// relayed via the optional Driftfin plugin's group message relay (see
  /// [_sendRelay]) when installed — the fix for issue #4, reaching every
  /// member regardless of permissions. Without the plugin this falls back to
  /// the legacy best-effort relay: a Jellyfin session `DisplayMessage` to each
  /// member's active session(s), which (verified against Jellyfin 10.11.x)
  /// only reliably reaches peers when the sender has the "Allow remote control
  /// of other users" permission; otherwise delivery is limited to the
  /// sender's own sessions (effectively a local echo).
  Future<void> sendChat(String text) async {
    final trimmed = text.trim();
    if (!state.inGroup || trimmed.isEmpty) return;
    final me = ref.read(userProvider)?.name ?? 'Me';
    _appendChat(SyncChatMessage(sender: me, text: trimmed, mine: true));
    final relayed = await _sendRelay(SyncRelayKind.chat, text: trimmed);
    if (!relayed) await _legacyBroadcastChat(trimmed, me);
  }

  Future<void> _legacyBroadcastChat(String text, String sender) async {
    try {
      final myDeviceId = ref.read(userProvider)?.credentials.deviceId;
      final sessions = (await _api.sessionsGet()).body ?? const [];
      final memberNames = state.members.toSet();
      for (final s in sessions) {
        if (s.id == null || s.userName == null) continue;
        if (!memberNames.contains(s.userName)) continue;
        if (myDeviceId != null && s.deviceId == myDeviceId) continue; // skip self
        _api
            .sessionsSessionIdMessagePost(
              sessionId: s.id!,
              body: MessageCommand(header: sender, text: text, timeoutMs: 8000),
            )
            .ignore();
      }
    } catch (e) {
      log('SyncPlay chat send failed: $e');
    }
  }

  /// Send a quick emoji reaction to the group (issue #5). Relay-only: requires
  /// the Driftfin plugin (see [_sendRelay]); without it the reaction is shown
  /// locally only, since there's no admin-permission fallback that makes sense
  /// for a purely decorative feature.
  Future<void> sendReaction(String emoji) async {
    final trimmed = emoji.trim();
    if (!state.inGroup || trimmed.isEmpty) return;
    final me = ref.read(userProvider)?.name ?? 'Me';
    _appendReaction(SyncReactionEvent(sender: me, emoji: trimmed, at: DateTime.now(), mine: true));
    await _sendRelay(SyncRelayKind.reaction, emoji: trimmed);
  }

  /// Report a local typing start/stop to the group (issue #5 presence).
  /// Relay-only; a no-op without the Driftfin plugin. De-duplicates so the UI
  /// can call this on every keystroke without spamming the relay.
  Future<void> setTyping(bool typing) async {
    if (!state.inGroup || typing == _typingSent) return;
    _typingSent = typing;
    await _sendRelay(SyncRelayKind.typing, text: typing ? 'start' : 'stop');
  }

  /// Posts a relay message via the optional Driftfin plugin's
  /// `POST /Driftfin/SyncPlay/{groupId}/Messages` endpoint. Returns false (and
  /// never throws) when not in a group, not signed in, or the plugin isn't
  /// installed/reachable.
  Future<bool> _sendRelay(SyncRelayKind kind, {String? text, String? emoji}) async {
    final groupId = state.groupId;
    final credentials = ref.read(userProvider)?.credentials;
    if (groupId == null || credentials == null) return false;
    final url = buildServerUrl(ref, pathSegments: ['Driftfin', 'SyncPlay', groupId, 'Messages']);
    if (url.isEmpty) return false;
    return postSyncPlayRelayMessage(url, credentials.header(ref), kind, text: text, emoji: emoji, client: _httpClient);
  }

  /// Routed from the player when the user seeks in a group.
  Future<void> userSeek(Duration position) async {
    if (!state.inGroup) return;
    try {
      await _api.syncPlaySeekPost(body: SeekRequestDto(positionTicks: _ticksFromDuration(position)));
    } catch (e) {
      log('SyncPlay seek failed: $e');
    }
  }

  // ---- Wiring -------------------------------------------------------------

  void _ensureWired() {
    if (_wired) return;
    final account = ref.read(userProvider);
    final baseUrl = ref.read(serverUrlProvider);
    final token = account?.credentials.token;
    final deviceId = account?.credentials.deviceId;
    if (baseUrl == null || baseUrl.isEmpty || token == null || token.isEmpty) {
      _setError('Not signed in to a server');
      return;
    }
    _wired = true;

    _timeSync = TimeSyncService(
      fetchUtc: () async {
        final resp = await _api.getUtcTimeGet();
        final b = resp.body;
        if (b?.requestReceptionTime == null || b?.responseTransmissionTime == null) return null;
        return UtcMeasurement(requestReceived: b!.requestReceptionTime!, responseSent: b.responseTransmissionTime!);
      },
      onPing: (ms) => _api.syncPlayPingPost(body: PingRequestDto(ping: ms)).ignore(),
    )..start();

    _connSub = _socket.connectionState.listen((c) {
      final reconnected = c == SyncPlayConnection.connected && state.connection != SyncPlayConnection.connected;
      state = state.copyWith(connection: c);
      // On (re)connect while we believe we're in a group, re-sync from the
      // authoritative server — the drop may have removed us.
      if (reconnected && state.inGroup) _resyncGroup();
    });
    _msgSub = _socket.messages.listen(_onMessage);
    _playerSub = _player.stateStream.listen(_onPlayerState);
    _driftTimer = Timer.periodic(const Duration(seconds: 1), (_) => _driftTick());

    _socket.connect(baseUrl: baseUrl, token: token, deviceId: deviceId ?? '');
  }

  // ---- Inbound message routing -------------------------------------------

  /// Test-only entry point into the socket message router (group updates,
  /// scheduled commands, and chat/reaction/typing/buffering relay parsing) —
  /// lets tests exercise routing without a live WebSocket, which
  /// [_ensureWired] otherwise requires. Never call this from production code.
  @visibleForTesting
  void debugHandleMessage(Map<String, dynamic> message) => _onMessage(message);

  void _onMessage(Map<String, dynamic> msg) {
    try {
      switch (msg['MessageType']?.toString()) {
        case 'SyncPlayGroupUpdate':
          final data = msg['Data'];
          if (data is Map<String, dynamic>) _onGroupUpdate(SyncPlayGroupUpdate.fromJson(data));
          break;
        case 'SyncPlayCommand':
          final data = msg['Data'];
          if (data is Map<String, dynamic>) _onCommand(data);
          break;
        case 'GeneralCommand':
          final data = msg['Data'];
          if (data is Map<String, dynamic>) _onGeneralCommand(data);
          break;
      }
    } catch (e, s) {
      // A malformed message must never kill the message stream.
      log('SyncPlay message handling failed: $e\n$s');
    }
  }

  void _onGroupUpdate(SyncPlayGroupUpdate update) {
    switch (update.type) {
      case SyncGroupUpdateType.groupJoined:
        final info = update.groupInfo;
        if (info != null) {
          _applyGroupInfo(info);
        } else {
          state = state.copyWith(inGroup: true, groupId: update.groupId, clearError: true);
          _timeSync?.start();
          _reportReady();
        }
        break;
      case SyncGroupUpdateType.groupLeft:
      case SyncGroupUpdateType.notInGroup:
      case SyncGroupUpdateType.groupDoesNotExist:
        _clearGroup();
        break;
      case SyncGroupUpdateType.libraryAccessDenied:
        _setError('Library access denied for this group');
        _clearGroup();
        break;
      case SyncGroupUpdateType.userJoined:
      case SyncGroupUpdateType.userLeft:
        _refreshMembers();
        break;
      case SyncGroupUpdateType.stateUpdate:
        final data = update.data;
        if (data is Map<String, dynamic>) {
          state = state.copyWith(groupState: SyncGroupState.parse(data['State']));
        }
        break;
      case SyncGroupUpdateType.playQueue:
        final data = update.data;
        if (data is Map<String, dynamic>) _onPlayQueue(data);
        break;
      case SyncGroupUpdateType.unknown:
        break;
    }
  }

  void _onGeneralCommand(Map<String, dynamic> data) {
    if (!state.inGroup) return;
    if (data['Name']?.toString() != 'DisplayMessage') return;
    final args = data['Arguments'];
    if (args is! Map) return;
    final header = args['Header']?.toString() ?? '';
    final text = args['Text']?.toString() ?? '';
    if (text.isEmpty) return;
    final relay = SyncRelayMessage.tryParse(header: header, text: text);
    if (relay != null) {
      _onRelayMessage(relay);
      return;
    }
    // Not a Driftfin relay payload: a genuine admin-authored DisplayMessage,
    // shown as a plain system chat line (existing pre-plugin behavior).
    _appendChat(SyncChatMessage(sender: header, text: text, mine: false));
  }

  void _onRelayMessage(SyncRelayMessage relay) {
    switch (relay.kind) {
      case SyncRelayKind.chat:
        final text = relay.text;
        if (text == null || text.isEmpty) return;
        _appendChat(SyncChatMessage(sender: relay.sender, text: text, mine: false));
        break;
      case SyncRelayKind.reaction:
        final emoji = relay.emoji;
        if (emoji == null || emoji.isEmpty) return;
        _appendReaction(SyncReactionEvent(sender: relay.sender, emoji: emoji, at: DateTime.now(), mine: false));
        break;
      case SyncRelayKind.typing:
        _setPresence(relay.sender, typing: relay.text == 'start');
        break;
      case SyncRelayKind.buffering:
        _setPresence(relay.sender, buffering: relay.text == 'start');
        break;
      case SyncRelayKind.unknown:
        break;
    }
  }

  void _appendChat(SyncChatMessage message) {
    if (!mounted) return;
    final next = [...state.chat, message];
    if (next.length > 200) next.removeRange(0, next.length - 200);
    state = state.copyWith(chat: next);
  }

  void _appendReaction(SyncReactionEvent event) {
    if (!mounted) return;
    final next = [...state.reactions, event];
    if (next.length > 20) next.removeRange(0, next.length - 20);
    state = state.copyWith(reactions: next);
  }

  /// Updates a member's typing/buffering presence. A typing=true ping
  /// auto-expires after a few seconds in case the peer's "stop" never arrives
  /// (e.g. it disconnects mid-message).
  void _setPresence(String member, {bool? typing, bool? buffering}) {
    if (!mounted || member.isEmpty) return;
    final current = state.presence[member] ?? const SyncPresenceInfo();
    state = state.copyWith(
      presence: {
        ...state.presence,
        member: current.copyWith(typing: typing, buffering: buffering),
      },
    );
    if (typing == true) {
      _presenceExpiryTimers[member]?.cancel();
      _presenceExpiryTimers[member] = Timer(const Duration(seconds: 6), () {
        _presenceExpiryTimers.remove(member);
        _setPresence(member, typing: false);
      });
    } else if (typing == false) {
      _presenceExpiryTimers.remove(member)?.cancel();
    }
  }

  void _applyGroupInfo(Map<String, dynamic> info) {
    state = state.copyWith(
      inGroup: true,
      groupId: info['GroupId']?.toString(),
      groupName: info['GroupName']?.toString(),
      members: _participants(info),
      groupState: SyncGroupState.parse(info['State']),
      clearError: true,
    );
    _timeSync?.start();
    // Report ready at our current position, else an already-playing group waits.
    _reportReady();
  }

  void _onPlayQueue(Map<String, dynamic> q) {
    final playlist = q['Playlist'];
    final index = (q['PlayingItemIndex'] as num?)?.toInt() ?? 0;
    final startTicks = (q['StartPositionTicks'] as num?)?.toInt();
    final isPlaying = q['IsPlaying'] == true;
    final startPos = startTicks != null ? _durationFromTicks(startTicks) : null;
    if (playlist is List && index >= 0 && index < playlist.length) {
      final item = playlist[index];
      if (item is Map<String, dynamic>) {
        _currentPlaylistItemId = item['PlaylistItemId']?.toString();
        final itemId = item['ItemId']?.toString();
        final localItemId = ref.read(playBackModel)?.item.id;
        if (itemId != null && itemId != localItemId) {
          _loadGroupItem(itemId, startPos, isPlaying);
        } else {
          pendingItemId = null;
          if (startPos != null) {
            _player.syncApplySeek(startPos);
            _setAnchor(startPos, isPlaying);
          }
        }
      }
    }
  }

  Future<void> _loadGroupItem(String itemId, Duration? startPos, bool isPlaying) async {
    if (_loadingItem) return;
    _loadingItem = true;
    try {
      final resp = await ref.read(jellyApiProvider).usersUserIdItemsItemIdGet(itemId: itemId);
      if (!mounted) return;
      final item = resp.body;
      if (item != null) {
        await ref.read(playbackModelHelper).loadNewVideo(item);
        if (!mounted) return;
        pendingItemId = null;
        // Anchor at the group's position; drift correction seeks the freshly
        // loaded player into alignment once it starts playing.
        if (startPos != null) _setAnchor(startPos, isPlaying);
      } else {
        pendingItemId = itemId;
      }
    } catch (e) {
      log('SyncPlay auto-load item failed: $e');
      pendingItemId = itemId;
    } finally {
      _loadingItem = false;
    }
  }

  // ---- Scheduled command execution ---------------------------------------

  void _onCommand(Map<String, dynamic> cmd) {
    final command = parseSyncCommand(cmd['Command']);
    final ticks = (cmd['PositionTicks'] as num?)?.toInt();
    final position = ticks != null ? _durationFromTicks(ticks) : null;
    final whenStr = cmd['When']?.toString();
    final when = whenStr != null ? DateTime.tryParse(whenStr) : null;

    final localWhen = (when != null && (_timeSync?.hasSynced ?? false))
        ? _timeSync!.serverToLocal(when)
        : DateTime.now().toUtc();
    var delay = localWhen.difference(DateTime.now().toUtc());
    if (delay.isNegative) delay = Duration.zero;

    _commandTimer?.cancel();
    _commandTimer = Timer(delay, () => _applyCommand(command, position));
  }

  void _applyCommand(SyncCommand command, Duration? position) {
    final player = _player;
    final pos = position ?? player.lastState?.position ?? Duration.zero;
    switch (command) {
      case SyncCommand.unpause:
        if (position != null) player.syncApplySeek(position);
        player.syncApplyPlay();
        _setAnchor(pos, true);
        break;
      case SyncCommand.pause:
        player.syncApplyPause();
        if (position != null) player.syncApplySeek(position);
        _setAnchor(pos, false);
        break;
      case SyncCommand.seek:
        if (position != null) player.syncApplySeek(position);
        _setAnchor(pos, _anchorPlaying);
        break;
      case SyncCommand.stop:
        player.syncApplyPause();
        _setAnchor(pos, false);
        break;
      case SyncCommand.unknown:
        break;
    }
  }

  // ---- Drift correction ---------------------------------------------------

  void _setAnchor(Duration position, bool playing) {
    _anchorPosition = position;
    _anchorAt = DateTime.now().toUtc();
    _anchorPlaying = playing;
  }

  Duration get _expectedPosition {
    if (!_anchorPlaying) return _anchorPosition;
    return _anchorPosition + DateTime.now().toUtc().difference(_anchorAt);
  }

  /// Keep the local player aligned with the group's expected position: small
  /// drift is nudged via a brief proportional speed change (relative to the
  /// user's own speed, then restored), large drift via a hard seek with a short
  /// cooldown so the player can settle. Speed changes stay local (Jellyfin
  /// SyncPlay does not sync playback speed).
  void _driftTick() {
    if (!state.inGroup || !_anchorPlaying) return;
    if (DateTime.now().toUtc().isBefore(_driftCooldownUntil)) return;
    final s = _player.lastState;
    if (s == null || !s.playing || s.buffering) return;

    final drift = s.position - _expectedPosition; // >0 ⇒ ahead
    final abs = drift.abs();

    if (abs > _seekThreshold) {
      _restoreSpeed();
      _player.syncApplySeek(_expectedPosition);
      _driftCooldownUntil = DateTime.now().toUtc().add(const Duration(seconds: 3));
      return;
    }
    if (abs > _nudgeThreshold) {
      if (!_nudging) {
        _userSpeed = (s.rate <= 0 ? 1.0 : s.rate).clamp(0.25, 4.0);
        _nudging = true;
      }
      _player.setSpeed(_userSpeed * (drift.isNegative ? 1.05 : 0.95));
    } else {
      _restoreSpeed();
    }
  }

  void _restoreSpeed() {
    if (_nudging) {
      _player.setSpeed(_userSpeed);
      _nudging = false;
    }
  }

  // ---- Buffering / ready handshake ---------------------------------------

  void _onPlayerState(PlayerState s) {
    if (!state.inGroup) return;
    if (s.buffering == _lastBuffering) return;
    _lastBuffering = s.buffering;
    _reportBuffer(s.buffering, s.position, s.playing);
    // Best-effort presence ping so peers can show "X is buffering" (issue #5);
    // edge-triggered like the report above, so this can't spam the relay.
    _sendRelay(SyncRelayKind.buffering, text: s.buffering ? 'start' : 'stop').ignore();
  }

  void _reportReady() {
    final s = _player.lastState;
    if (s == null) return;
    _lastBuffering = false;
    _reportBuffer(false, s.position, s.playing);
  }

  void _reportBuffer(bool buffering, Duration position, bool playing) {
    final when = _timeSync?.localToServer(DateTime.now()) ?? DateTime.now().toUtc();
    final ticks = _ticksFromDuration(position);
    if (buffering) {
      _api
          .syncPlayBufferingPost(
            body: BufferRequestDto(
              when: when,
              positionTicks: ticks,
              isPlaying: playing,
              playlistItemId: _currentPlaylistItemId,
            ),
          )
          .ignore();
    } else {
      _api
          .syncPlayReadyPost(
            body: ReadyRequestDto(
              when: when,
              positionTicks: ticks,
              isPlaying: playing,
              playlistItemId: _currentPlaylistItemId,
            ),
          )
          .ignore();
    }
  }

  // ---- Helpers ------------------------------------------------------------

  Future<void> _seedCurrentQueue() async {
    final pb = ref.read(playBackModel);
    final itemId = pb?.item.id;
    if (itemId == null) return;
    final position = _player.lastState?.position ?? Duration.zero;
    try {
      await _api.syncPlaySetNewQueuePost(
        body: PlayRequestDto(
          playingQueue: [itemId],
          playingItemPosition: 0,
          startPositionTicks: _ticksFromDuration(position),
        ),
      );
    } catch (e) {
      log('SyncPlay seed queue failed: $e');
    }
  }

  Future<void> _confirmMembership(String groupId) async {
    try {
      final resp = await _api.syncPlayIdGet(id: groupId);
      if (!mounted) return;
      final info = resp.body?.toJson();
      if (info != null) _applyGroupInfo(info);
    } catch (e) {
      log('SyncPlay confirm membership failed: $e');
    }
  }

  Future<void> _refreshMembers() async {
    final id = state.groupId;
    if (id == null) return;
    try {
      final resp = await _api.syncPlayIdGet(id: id);
      if (!mounted) return;
      state = state.copyWith(members: _participants(resp.body?.toJson()));
    } catch (e) {
      log('SyncPlay refresh members failed: $e');
    }
  }

  /// Re-fetch authoritative group state after a reconnect; drop the group if the
  /// server no longer has us.
  Future<void> _resyncGroup() async {
    final id = state.groupId;
    if (id == null) return;
    try {
      final resp = await _api.syncPlayIdGet(id: id);
      if (!mounted) return;
      final info = resp.body?.toJson();
      if (info == null) {
        _clearGroup();
        return;
      }
      state = state.copyWith(members: _participants(info), groupState: SyncGroupState.parse(info['State']));
      _reportReady();
    } catch (e) {
      log('SyncPlay resync failed: $e');
      _clearGroup();
    }
  }

  void _clearGroup() {
    _commandTimer?.cancel();
    _restoreSpeed();
    _timeSync?.stop(); // stop /SyncPlay/Ping traffic while not in a group
    pendingItemId = null;
    _currentPlaylistItemId = null;
    _anchorPlaying = false;
    _typingSent = false;
    for (final t in _presenceExpiryTimers.values) {
      t.cancel();
    }
    _presenceExpiryTimers.clear();
    if (mounted) state = state.copyWith(clearGroup: true);
  }

  List<String> _participants(Map<String, dynamic>? info) {
    final p = info?['Participants'] ?? info?['participants'];
    if (p is List) return p.map((e) => e.toString()).toList();
    return state.members;
  }

  String _defaultGroupName() {
    final title = ref.read(playBackModel)?.item.title;
    return (title == null || title.isEmpty) ? 'Watch Together' : title;
  }

  void _setError(String message) {
    log('SyncPlay: $message');
    if (mounted) state = state.copyWith(lastError: message);
  }

  @override
  void dispose() {
    _commandTimer?.cancel();
    _driftTimer?.cancel();
    for (final t in _presenceExpiryTimers.values) {
      t.cancel();
    }
    _presenceExpiryTimers.clear();
    _msgSub?.cancel();
    _connSub?.cancel();
    _playerSub?.cancel();
    _timeSync?.dispose();
    _socket.dispose();
    _httpClient.close();
    super.dispose();
  }
}

final syncPlayControllerProvider = StateNotifierProvider<SyncPlayController, SyncPlayState>(
  (ref) => SyncPlayController(ref),
);
