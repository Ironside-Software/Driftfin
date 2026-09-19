// Exercises CastController's Jellyfin-session ("Beam & Handoff") dispatch
// path end to end against a fake JellyService, without touching real
// Chromecast/DLNA discovery (mDNS/SSDP are unavailable in CI and would make
// these tests slow/flaky) or a live Jellyfin server.
import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.enums.swagger.dart' as enums;
import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/cast_provider.dart';
import 'package:driftfin/providers/service_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/providers/video_player_provider.dart';
import 'package:driftfin/util/duration_extensions.dart';

import 'support/video_player_test_support.dart';

/// `MediaControlsWrapper.pause()` calls into the real `wakelock_plus` plugin,
/// which needs a platform channel unavailable in a plain (non-testWidgets)
/// test. Swapping the platform interface avoids that without touching
/// production code.
class _FakeWakelockPlusPlatform extends WakelockPlusPlatformInterface {
  @override
  bool get isMock => true;

  @override
  Future<void> toggle({required bool enable}) async {}

  @override
  Future<bool> get enabled async => false;
}

/// Records every call made through the session-dispatch wrappers instead of
/// hitting a real server. [sessionsById] is mutable so tests can simulate the
/// remote session's play state changing (or disappearing) between polls.
class _FakeCastJellyService extends JellyService {
  _FakeCastJellyService(Ref ref, this.sessionsById) : super(ref, JellyfinOpenApi.create());

  final Map<String, SessionInfoDto> sessionsById;

  final List<Map<String, dynamic>> playingPostCalls = [];
  final List<Map<String, dynamic>> playingCommandCalls = [];

  @override
  Future<Response<List<SessionInfoDto>>> getControllableSessions() async =>
      Response(http.Response('', 200), sessionsById.values.toList());

  @override
  Future<Response> sessionsSessionIdPlayingPost({
    required String sessionId,
    required List<String> itemIds,
    int? startPositionTicks,
    String? mediaSourceId,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
  }) async {
    playingPostCalls.add({
      'sessionId': sessionId,
      'itemIds': itemIds,
      'startPositionTicks': startPositionTicks,
      'mediaSourceId': mediaSourceId,
      'audioStreamIndex': audioStreamIndex,
      'subtitleStreamIndex': subtitleStreamIndex,
    });
    return Response(http.Response('', 200), null);
  }

  @override
  Future<Response> sessionsSessionIdPlayingCommandPost({
    required String sessionId,
    required enums.SessionsSessionIdPlayingCommandPostCommand command,
    int? seekPositionTicks,
  }) async {
    playingCommandCalls.add({'sessionId': sessionId, 'command': command, 'seekPositionTicks': seekPositionTicks});
    return Response(http.Response('', 200), null);
  }
}

class _FakeCastJellyApi extends JellyApi {
  _FakeCastJellyApi(this.sessionsById);

  final Map<String, SessionInfoDto> sessionsById;
  late final _FakeCastJellyService service;

  @override
  JellyService build() {
    // jellyApiProvider is autoDispose; without keepAlive() a second read
    // (e.g. one triggered internally by CastController after this test's own
    // eager read) can dispose and rebuild it, re-assigning the `late final`
    // service field and crashing.
    ref.keepAlive();
    service = _FakeCastJellyService(ref, sessionsById);
    return service;
  }
}

class _FakeUser extends User {
  _FakeUser(this.initial);
  final AccountModel? initial;

  @override
  AccountModel? build() => initial;
}

const _remoteSession = SessionInfoDto(id: 's1', deviceName: 'Living Room TV', supportsRemoteControl: true);

const _sessionTarget = CastTarget(
  id: 'session:s1',
  name: 'Living Room TV',
  backend: CastBackend.jellyfinSession,
  session: _remoteSession,
);

typedef _Harness = ({
  ProviderContainer container,
  _FakeCastJellyService service,
  CastController controller,
  FakeBasePlayer player,
});

/// Sets up a container with the cast target's remote session already
/// registered, a fake video player, and a playback model with media loaded
/// so `CastController._currentMedia()` resolves.
Future<_Harness> _readyHarness({Map<String, SessionInfoDto>? sessionsById}) async {
  final fakeApi = _FakeCastJellyApi(sessionsById ?? {'s1': _remoteSession});
  final container = ProviderContainer(
    overrides: [
      jellyApiProvider.overrideWith(() => fakeApi),
      userProvider.overrideWith(
        () => _FakeUser(
          AccountModel(
            name: 'me',
            id: 'user-1',
            avatar: '',
            lastUsed: DateTime(2024),
            credentials: CredentialsModel(url: 'http://server.local', deviceId: 'my-device'),
          ),
        ),
      ),
      playBackModel.overrideWith((ref) => testPlaybackModel()),
      videoPlayerProvider.overrideWith((ref) => FakeVideoPlayerNotifier(ref)),
    ],
  );

  final notifier = container.read(videoPlayerProvider.notifier) as FakeVideoPlayerNotifier;
  await notifier.setupFake();
  // jellyApiProvider is lazy: force its build() to run now so fakeApi.service
  // (assigned inside build()) is initialized before the harness is used.
  container.read(jellyApiProvider);

  return (
    container: container,
    service: fakeApi.service,
    controller: container.read(castProvider.notifier),
    player: notifier.fakePlayer,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  WakelockPlusPlatformInterface.instance = _FakeWakelockPlusPlatform();

  test(
    'connect() to a Jellyfin session hands off the exact position + track selection, then marks it connected',
    () async {
      final harness = await _readyHarness();
      addTearDown(() async {
        // connect() starts a 2s Timer.periodic poll; CastController.dispose()
        // fires _teardown() (which cancels it) without awaiting it, so an
        // explicit disconnect() first is needed to guarantee the timer is gone
        // before the container disposes - otherwise it can fire against an
        // already-disposed container and hang/crash a later test. Swallow
        // errors here: this is best-effort cleanup, not a test assertion.
        try {
          await harness.controller.disconnect();
        } catch (_) {}
        harness.container.dispose();
      });
      harness.player.lastState.position = const Duration(seconds: 42);
      harness.player.lastState.duration = const Duration(minutes: 10);

      await harness.controller.connect(_sessionTarget);
      // connect() fires ref.read(videoPlayerProvider).pause() without awaiting
      // it (intentional in production: local pause shouldn't block the
      // handoff); let that background chain settle before this test's
      // teardown disposes the container, or it throws in a later test.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(harness.service.playingPostCalls, hasLength(1));
      final call = harness.service.playingPostCalls.single;
      expect(call['sessionId'], 's1');
      expect(call['itemIds'], ['item-1']);
      expect(call['startPositionTicks'], const Duration(seconds: 42).toRuntimeTicks);

      final state = harness.container.read(castProvider);
      expect(state.status, CastStatus.connected);
      expect(state.playing, isTrue);
      expect(state.duration, const Duration(minutes: 10));
    },
  );

  test('connect() reports an error and never dispatches when there is no media to cast', () async {
    final fakeApi = _FakeCastJellyApi({'s1': _remoteSession});
    final container = ProviderContainer(
      overrides: [
        jellyApiProvider.overrideWith(() => fakeApi),
        userProvider.overrideWith(() => _FakeUser(null)),
        // playBackModel left at its default (null) -> no media loaded.
        videoPlayerProvider.overrideWith((ref) => FakeVideoPlayerNotifier(ref)),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(videoPlayerProvider.notifier) as FakeVideoPlayerNotifier;
    await notifier.setupFake();
    container.read(jellyApiProvider); // force build() so fakeApi.service is initialized

    await container.read(castProvider.notifier).connect(_sessionTarget);

    expect(fakeApi.service.playingPostCalls, isEmpty);
    expect(container.read(castProvider).status, CastStatus.error);
  });

  test('play/pause/seek send the matching playstate command to the connected session', () async {
    final harness = await _readyHarness();
    addTearDown(() async {
      try {
        await harness.controller.disconnect();
      } catch (_) {}
      harness.container.dispose();
    });
    await harness.controller.connect(_sessionTarget);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    harness.controller.pause();
    harness.controller.play();
    harness.controller.seek(const Duration(seconds: 30));

    final commands = harness.service.playingCommandCalls.map((c) => c['command']).toList();
    expect(commands, [
      enums.SessionsSessionIdPlayingCommandPostCommand.pause,
      enums.SessionsSessionIdPlayingCommandPostCommand.unpause,
      enums.SessionsSessionIdPlayingCommandPostCommand.seek,
    ]);
    expect(harness.service.playingCommandCalls.last['seekPositionTicks'], const Duration(seconds: 30).toRuntimeTicks);
    expect(harness.container.read(castProvider).playing, isTrue);
    expect(harness.container.read(castProvider).position, const Duration(seconds: 30));
  });

  test('disconnect() sends a stop command and resets to the idle state', () async {
    final harness = await _readyHarness();
    addTearDown(harness.container.dispose);
    await harness.controller.connect(_sessionTarget);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    await harness.controller.disconnect();

    expect(harness.service.playingCommandCalls.last['command'], enums.SessionsSessionIdPlayingCommandPostCommand.stop);
    expect(harness.container.read(castProvider).isCasting, isFalse);
    expect(harness.container.read(castProvider).status, CastStatus.disconnected);
  });
}
