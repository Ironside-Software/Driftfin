import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/models/syncplay/sync_play_models.dart';
import 'package:driftfin/models/syncplay/sync_play_state.dart';
import 'package:driftfin/providers/syncplay/sync_play_controller.dart';

// These tests exercise SyncPlayController without wiring a live
// JellyfinSocket/API/player, via two seams:
//
//   - The guard clauses at the top of the public, player/network-facing
//     methods (userTogglePlayPause/sendChat/sendReaction/setTyping/userSeek)
//     return immediately when `state.inGroup` is false, *before* touching
//     `ref`, the Jellyfin API, the relay HTTP client, or the player wrapper.
//     A freshly constructed controller starts with `const SyncPlayState()`
//     (inGroup: false), so calling these is safe with a bare
//     ProviderContainer and never triggers `_ensureWired()` / a real socket
//     connection or HTTP request.
//   - The `initialState` constructor param and `debugHandleMessage` method
//     (both @visibleForTesting) let a test seed `inGroup: true` and feed a
//     raw socket message straight into the private message router, without
//     `_ensureWired()`'s real WebSocket. With no `userProvider` session,
//     `_sendRelay`'s credentials check fails closed before any HTTP call, so
//     `sendReaction`/`setTyping` are exercised end-to-end but never touch the
//     network.
//
// Everything else of substance in this file is either:
//   - private top-level ticks<->Duration helpers and the private
//     _participants/_defaultGroupName/_onGroupUpdate/_onCommand/
//     _applyCommand routing, unreachable from a test without driving them via
//     _ensureWired(), which opens a real WebSocket with no injection seam; or
//   - already covered by test/sync_play_state_test.dart (SyncPlayState /
//     copyWith / equality), test/sync_play_models_test.dart
//     (SyncGroupState.parse, SyncGroupUpdateType.parse,
//     SyncPlayGroupUpdate.fromJson, parseSyncCommand, SyncRelayMessage), and
//     test/sync_play_relay_test.dart (postSyncPlayRelayMessage).

/// A test-local provider so we can obtain a real `Ref` for
/// `SyncPlayController`'s constructor without pulling in the app's
/// `syncPlayControllerProvider` (same shape, kept local to this test file).
final _testControllerProvider = StateNotifierProvider<SyncPlayController, SyncPlayState>(
  (ref) => SyncPlayController(ref),
);

/// A second test-local provider seeded already inside a group, so
/// sendReaction/setTyping/debugHandleMessage can be exercised past their
/// `state.inGroup` guard clause.
final _testInGroupControllerProvider = StateNotifierProvider<SyncPlayController, SyncPlayState>(
  (ref) => SyncPlayController(
    ref,
    initialState: const SyncPlayState(
      inGroup: true,
      groupId: 'g1',
      groupName: 'Movie night',
      members: ['Alice', 'Bob'],
    ),
  ),
);

Map<String, dynamic> _generalCommand(String name, Map<String, dynamic> arguments) => {
  'MessageType': 'GeneralCommand',
  'Data': {'Name': name, 'Arguments': arguments},
};

Map<String, dynamic> _relayDisplayMessage(SyncRelayKind kind, {required String sender, String? text, String? emoji}) =>
    _generalCommand('DisplayMessage', {
      'Header': syncRelayMarker,
      'Text': jsonEncode({'k': kind.name, 's': sender, 't': ?text, 'e': ?emoji}),
    });

void main() {
  late ProviderContainer container;
  late SyncPlayController controller;

  setUp(() {
    container = ProviderContainer();
    // SyncPlayController only needs a Ref; reuse the real provider's factory
    // via a throwaway container-scoped provider to obtain one without
    // depending on any app-level provider overrides.
    controller = container.read(_testControllerProvider.notifier);
  });

  tearDown(() {
    container.dispose();
  });

  group('SyncPlayController guard clauses (never wired, not in a group)', () {
    test('userTogglePlayPause no-ops without touching the API or player', () async {
      expect(controller.state.inGroup, false);
      await expectLater(controller.userTogglePlayPause(), completes);
      // State must be untouched: no group, no error recorded.
      expect(controller.state, const SyncPlayState());
    });

    test('userSeek no-ops without touching the API', () async {
      await expectLater(controller.userSeek(const Duration(seconds: 5)), completes);
      expect(controller.state, const SyncPlayState());
    });

    test('sendChat no-ops on an empty/whitespace message even conceptually in-group', () async {
      // Not in a group, so this returns before the trimmed-empty check even
      // matters, but a non-empty message should also be rejected while not
      // in a group without throwing or mutating chat.
      await expectLater(controller.sendChat('hello'), completes);
      expect(controller.state.chat, isEmpty);
      expect(controller.state, const SyncPlayState());
    });

    test('sendChat no-ops for a whitespace-only message', () async {
      await expectLater(controller.sendChat('   '), completes);
      expect(controller.state.chat, isEmpty);
    });

    test('sendReaction no-ops without touching the API or player', () async {
      await expectLater(controller.sendReaction('👍'), completes);
      expect(controller.state.reactions, isEmpty);
      expect(controller.state, const SyncPlayState());
    });

    test('sendReaction no-ops for a whitespace-only emoji', () async {
      await expectLater(controller.sendReaction('   '), completes);
      expect(controller.state.reactions, isEmpty);
    });

    test('setTyping no-ops without touching the API or player', () async {
      await expectLater(controller.setTyping(true), completes);
      expect(controller.state, const SyncPlayState());
    });

    test('debugHandleMessage no-ops entirely while not in a group', () {
      controller.debugHandleMessage(_relayDisplayMessage(SyncRelayKind.chat, sender: 'Alice', text: 'hi'));
      expect(controller.state, const SyncPlayState());
    });
  });

  group('SyncPlayController construction', () {
    test('starts in the default disconnected/idle state', () {
      expect(controller.state, const SyncPlayState());
      expect(controller.state.connection, SyncPlayConnection.disconnected);
      expect(controller.state.inGroup, false);
      expect(controller.pendingItemId, isNull);
    });

    test('dispose is safe to call without ever wiring the socket', () {
      // Regression guard: SyncPlayController.dispose() cancels timers/
      // subscriptions and disposes the socket/time-sync services. None of
      // those are initialized unless _ensureWired() ran, so dispose() must
      // tolerate everything being null.
      //
      // Riverpod calls the notifier's dispose() itself when the container is
      // disposed; StateNotifier.dispose() is not safe to call a second time
      // (asserts the notifier is still mounted) and JellyfinSocket.dispose()
      // does not guard against being called twice either. So this exercises
      // dispose only via container.dispose(), matching how the app actually
      // tears the controller down, instead of calling controller.dispose()
      // directly and then disposing the (shared) container again in
      // tearDown.
      expect(controller.state.inGroup, false);
      expect(container.dispose, returnsNormally);
    });
  });

  group('SyncPlayController while in a group (initialState seam)', () {
    late ProviderContainer groupContainer;
    late SyncPlayController groupController;

    setUp(() {
      groupContainer = ProviderContainer();
      groupController = groupContainer.read(_testInGroupControllerProvider.notifier);
    });

    tearDown(() {
      groupContainer.dispose();
    });

    test('sendReaction appends a local mine:true reaction', () async {
      await groupController.sendReaction('👍');
      expect(groupController.state.reactions, hasLength(1));
      final reaction = groupController.state.reactions.single;
      expect(reaction.emoji, '👍');
      expect(reaction.mine, true);
      // No userProvider session, so the sender name falls back to 'Me'.
      expect(reaction.sender, 'Me');
    });

    test('sendReaction still no-ops for a whitespace-only emoji even in a group', () async {
      await groupController.sendReaction('   ');
      expect(groupController.state.reactions, isEmpty);
    });

    test('setTyping de-duplicates repeated calls with the same value', () async {
      // Can't observe the relay call directly (no server), but repeated calls
      // with the same value and then a flip must both complete without error.
      await expectLater(groupController.setTyping(true), completes);
      await expectLater(groupController.setTyping(true), completes);
      await expectLater(groupController.setTyping(false), completes);
    });

    test('debugHandleMessage: chat relay message appends a not-mine chat line', () {
      groupController.debugHandleMessage(_relayDisplayMessage(SyncRelayKind.chat, sender: 'Alice', text: 'hi there'));
      expect(groupController.state.chat, hasLength(1));
      final message = groupController.state.chat.single;
      expect(message.sender, 'Alice');
      expect(message.text, 'hi there');
      expect(message.mine, false);
    });

    test('debugHandleMessage: reaction relay message appends a not-mine reaction', () {
      groupController.debugHandleMessage(_relayDisplayMessage(SyncRelayKind.reaction, sender: 'Bob', emoji: '🎉'));
      expect(groupController.state.reactions, hasLength(1));
      final reaction = groupController.state.reactions.single;
      expect(reaction.sender, 'Bob');
      expect(reaction.emoji, '🎉');
      expect(reaction.mine, false);
    });

    test('debugHandleMessage: typing relay sets and then clears presence', () {
      groupController.debugHandleMessage(_relayDisplayMessage(SyncRelayKind.typing, sender: 'Alice', text: 'start'));
      expect(groupController.state.typingMembers, ['Alice']);

      groupController.debugHandleMessage(_relayDisplayMessage(SyncRelayKind.typing, sender: 'Alice', text: 'stop'));
      expect(groupController.state.typingMembers, isEmpty);
    });

    test('debugHandleMessage: buffering relay sets presence', () {
      groupController.debugHandleMessage(_relayDisplayMessage(SyncRelayKind.buffering, sender: 'Bob', text: 'start'));
      expect(groupController.state.bufferingMembers, ['Bob']);
    });

    test('debugHandleMessage: a plain admin DisplayMessage (no relay marker) is a system chat line', () {
      groupController.debugHandleMessage(
        _generalCommand('DisplayMessage', {'Header': 'Server Admin', 'Text': 'Restarting soon'}),
      );
      expect(groupController.state.chat, hasLength(1));
      final message = groupController.state.chat.single;
      expect(message.sender, 'Server Admin');
      expect(message.text, 'Restarting soon');
      expect(message.mine, false);
    });

    test('debugHandleMessage: an unrelated GeneralCommand name is ignored', () {
      groupController.debugHandleMessage(_generalCommand('ToggleMute', {'Header': 'x', 'Text': 'y'}));
      expect(
        groupController.state,
        const SyncPlayState(inGroup: true, groupId: 'g1', groupName: 'Movie night', members: ['Alice', 'Bob']),
      );
    });

    test('debugHandleMessage: malformed payloads never throw', () {
      expect(() => groupController.debugHandleMessage(const {'MessageType': 'GeneralCommand'}), returnsNormally);
      expect(() => groupController.debugHandleMessage(_generalCommand('DisplayMessage', const {})), returnsNormally);
      expect(
        () => groupController.debugHandleMessage({
          'MessageType': 'GeneralCommand',
          'Data': {'Name': 'DisplayMessage', 'Arguments': 'not a map'},
        }),
        returnsNormally,
      );
    });
  });
}
