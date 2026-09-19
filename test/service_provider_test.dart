import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:driftfin/jellyfin/jellyfin_open_api.enums.swagger.dart' as enums;
import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/models/library_filters_model.dart';
import 'package:driftfin/models/login_screen_model.dart';
import 'package:driftfin/providers/auth_provider.dart';
import 'package:driftfin/providers/service_provider.dart';
import 'package:driftfin/providers/user_provider.dart';

/// Exposes a real [Ref] bound to a [ProviderContainer], since several APIs
/// under test (e.g. `ServerQueryResult.fromBaseQuery`, `JellyService`) need a
/// [Ref] rather than the container itself.
final _refProvider = Provider<Ref>((ref) => ref);

Ref _refOf(ProviderContainer container) => container.read(_refProvider);

/// Minimal fake for the `User` notifier so we can drive `userProvider`'s
/// state directly without going through the real notifier's network calls.
class _FakeUser extends User {
  _FakeUser(this.initial);
  final AccountModel? initial;

  @override
  AccountModel? build() => initial;
}

ProviderContainer _containerWith({
  AccountModel? user,
  LoginScreenModel? auth,
}) {
  return ProviderContainer(
    overrides: [
      if (user != null) userProvider.overrideWith(() => _FakeUser(user)),
      if (auth != null) authProvider.overrideWith((ref) => AuthNotifier(ref)..state = auth),
    ],
  );
}

AccountModel _accountWithUrl(String url) {
  return AccountModel(
    name: 'test',
    id: 'user-id',
    avatar: '',
    lastUsed: DateTime(2024),
    credentials: CredentialsModel.internal(url: url),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('custom config retains legacy saved filters only when the server key is absent', () async {
    final legacy = LibraryFiltersModel(id: 'legacy', name: 'Home shelf', isFavourite: false, showOnHome: true);
    final container = _containerWith(user: _accountWithUrl('http://server.local').copyWith(libraryFilters: [legacy]));
    addTearDown(container.dispose);
    final rawApi = _FakeRawSessionsApi();
    final service = JellyService(_refOf(container), rawApi);

    final migrated = (await service.getCustomConfig()).body!;
    expect(migrated.libraryFilters.single.id, 'legacy');
    expect(migrated.libraryFilters.single.showOnHome, isTrue);

    rawApi.customPrefs = {'libraryFilters': '[]'};
    expect((await service.getCustomConfig()).body!.libraryFilters, isEmpty);
  });

  group('ServerQueryResult.fromBaseQuery', () {
    test('maps items, totalRecordCount and startIndex from the base query', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dto1 = const BaseItemDto(id: 'a', name: 'Alpha');
      final dto2 = const BaseItemDto(id: 'b', name: 'Beta');
      final baseQuery = BaseItemDtoQueryResult(
        items: [dto1, dto2],
        totalRecordCount: 42,
        startIndex: 5,
      );

      final result = ServerQueryResult.fromBaseQuery(baseQuery, _refOf(container));

      expect(result.items, hasLength(2));
      expect(result.items.map((e) => e.id), ['a', 'b']);
      expect(result.totalRecordCount, 42);
      expect(result.startIndex, 5);
    });

    test('defaults to empty items list when items is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const baseQuery = BaseItemDtoQueryResult(items: null, totalRecordCount: null, startIndex: null);
      final result = ServerQueryResult.fromBaseQuery(baseQuery, _refOf(container));

      expect(result.items, isEmpty);
      expect(result.totalRecordCount, isNull);
      expect(result.startIndex, isNull);
    });
  });

  group('ServerQueryResult.copyWith', () {
    test('overrides only the provided fields', () {
      final original = ServerQueryResult(
        items: const [],
        totalRecordCount: 1,
        startIndex: 0,
      );

      final copy = original.copyWith(totalRecordCount: 99);

      expect(copy.totalRecordCount, 99);
      expect(copy.startIndex, 0);
      expect(copy.items, original.items);
    });

    test('with no arguments returns equivalent values', () {
      final original = ServerQueryResult(
        items: const [],
        totalRecordCount: 3,
        startIndex: 1,
      );

      final copy = original.copyWith();

      expect(copy.items, original.items);
      expect(copy.totalRecordCount, 3);
      expect(copy.startIndex, 1);
    });
  });

  group('ParsedMap.parseValues', () {
    test('parses int-like strings to int', () {
      final result = {'a': '42'}.parseValues();
      expect(result['a'], 42);
      expect(result['a'], isA<int>());
    });

    test('parses double-like strings to double', () {
      final result = {'a': '3.14'}.parseValues();
      expect(result['a'], 3.14);
      expect(result['a'], isA<double>());
    });

    test('parses "true"/"false" case-insensitively to bool', () {
      final result = {
        'a': 'true',
        'b': 'FALSE',
        'c': 'True',
        'd': 'false',
      }.parseValues();
      expect(result['a'], isTrue);
      expect(result['b'], isFalse);
      expect(result['c'], isTrue);
      expect(result['d'], isFalse);
    });

    test('leaves plain non-numeric, non-boolean strings untouched', () {
      final result = {'a': 'hello world'}.parseValues();
      expect(result['a'], 'hello world');
    });

    test('passes through non-string values unchanged', () {
      final result = {
        'a': 1,
        'b': true,
        'c': null,
        'd': [1, 2, 3],
      }.parseValues();
      expect(result['a'], 1);
      expect(result['b'], true);
      expect(result['c'], isNull);
      expect(result['d'], [1, 2, 3]);
    });

    test('empty map returns empty map', () {
      expect(<String, dynamic>{}.parseValues(), isEmpty);
    });

    test('mixed map parses each entry independently', () {
      final result = {
        'count': '10',
        'ratio': '0.5',
        'enabled': 'TRUE',
        'name': 'driftfin',
        'raw': 7,
      }.parseValues();
      expect(result['count'], 10);
      expect(result['ratio'], 0.5);
      expect(result['enabled'], true);
      expect(result['name'], 'driftfin');
      expect(result['raw'], 7);
    });
  });

  group('JellyService.buildVideoStreamUrl', () {
    test('with no optional params set, returns just base path (no query string)', () {
      final container = _containerWith(user: _accountWithUrl('http://server.local:8096'));
      addTearDown(container.dispose);
      final service = JellyService(_refOf(container), fakeJellyfinOpenApiStub());

      final url = service.buildVideoStreamUrl(itemId: 'item1', container: 'mp4');

      expect(url, 'http://server.local:8096/Videos/item1/stream.mp4');
    });

    test('trims a trailing slash from the server URL', () {
      final container = _containerWith(user: _accountWithUrl('http://server.local:8096/'));
      addTearDown(container.dispose);
      final service = JellyService(_refOf(container), fakeJellyfinOpenApiStub());

      final url = service.buildVideoStreamUrl(itemId: 'item1', container: 'mp4');

      expect(url, 'http://server.local:8096/Videos/item1/stream.mp4');
    });

    test('builds a query string with several params set, correctly encoded', () {
      final container = _containerWith(user: _accountWithUrl('http://server.local'));
      addTearDown(container.dispose);
      final service = JellyService(_refOf(container), fakeJellyfinOpenApiStub());

      final url = service.buildVideoStreamUrl(
        itemId: 'item1',
        container: 'mp4',
        $static: true,
        tag: 'tag value/with slash',
        maxHeight: 1080,
        audioCodec: 'aac',
        framerate: 23.976,
      );

      expect(url, startsWith('http://server.local/Videos/item1/stream.mp4?'));
      final query = Uri.parse(url).queryParameters;
      expect(query['static'], 'true');
      expect(query['tag'], 'tag value/with slash');
      expect(query['maxHeight'], '1080');
      expect(query['audioCodec'], 'aac');
      expect(query['framerate'], '23.976');
    });

    test('URL-encodes special characters in query values', () {
      final container = _containerWith(user: _accountWithUrl('http://server.local'));
      addTearDown(container.dispose);
      final service = JellyService(_refOf(container), fakeJellyfinOpenApiStub());

      final url = service.buildVideoStreamUrl(
        itemId: 'item1',
        container: 'mp4',
        deviceId: 'device id&with=chars',
      );

      expect(url, contains(Uri.encodeComponent('device id&with=chars')));
      expect(url, isNot(contains('device id&with=chars')));
    });

    test('serializes enum params using their .value', () {
      final container = _containerWith(user: _accountWithUrl('http://server.local'));
      addTearDown(container.dispose);
      final service = JellyService(_refOf(container), fakeJellyfinOpenApiStub());

      final url = service.buildVideoStreamUrl(
        itemId: 'item1',
        container: 'mp4',
        subtitleMethod: enums.VideosItemIdStreamContainerGetSubtitleMethod.embed,
        context: enums.VideosItemIdStreamContainerGetContext.streaming,
      );

      final query = Uri.parse(url).queryParameters;
      expect(query['subtitleMethod'], 'Embed');
      expect(query['context'], 'Streaming');
    });

    test('prefers the temp auth server URL over the current user URL', () {
      final container = _containerWith(
        user: _accountWithUrl('http://user-server.local'),
        auth: LoginScreenModel(
          serverLoginModel: ServerLoginModel(
            tempCredentials: CredentialsModel.internal(url: 'http://temp-server.local'),
          ),
        ),
      );
      addTearDown(container.dispose);
      final service = JellyService(_refOf(container), fakeJellyfinOpenApiStub());

      final url = service.buildVideoStreamUrl(itemId: 'item1', container: 'mp4');

      expect(url, startsWith('http://temp-server.local'));
    });

    test('falls back to empty base URL when neither provider has a URL', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = JellyService(_refOf(container), fakeJellyfinOpenApiStub());

      final url = service.buildVideoStreamUrl(itemId: 'item1', container: 'mp4');

      expect(url, '/Videos/item1/stream.mp4');
    });

    test('falsy/zero numeric params are still included (only null is excluded)', () {
      final container = _containerWith(user: _accountWithUrl('http://server.local'));
      addTearDown(container.dispose);
      final service = JellyService(_refOf(container), fakeJellyfinOpenApiStub());

      final url = service.buildVideoStreamUrl(
        itemId: 'item1',
        container: 'mp4',
        startTimeTicks: 0,
        audioStreamIndex: 0,
      );

      final query = Uri.parse(url).queryParameters;
      expect(query['startTimeTicks'], '0');
      expect(query['audioStreamIndex'], '0');
    });
  });

  group('JellyService session-handoff wrappers (Beam & Handoff, #46)', () {
    test('getControllableSessions passes the current account id as controllableByUserId', () async {
      final container = _containerWith(user: _accountWithUrl('http://server.local'));
      addTearDown(container.dispose);
      final rawApi = _FakeRawSessionsApi()..sessions = [const SessionInfoDto(id: 's1')];
      final service = JellyService(_refOf(container), rawApi);

      final response = await service.getControllableSessions();

      expect(rawApi.capturedControllableByUserId, 'user-id');
      expect(response.body, hasLength(1));
      expect(response.body!.single.id, 's1');
    });

    test('sessionsSessionIdPlayingPost hands off with a hardcoded PlayNow command', () async {
      final container = _containerWith(user: _accountWithUrl('http://server.local'));
      addTearDown(container.dispose);
      final rawApi = _FakeRawSessionsApi();
      final service = JellyService(_refOf(container), rawApi);

      await service.sessionsSessionIdPlayingPost(
        sessionId: 's1',
        itemIds: const ['item-1'],
        startPositionTicks: 12345,
        mediaSourceId: 'src1',
        audioStreamIndex: 1,
        subtitleStreamIndex: 2,
      );

      expect(rawApi.playingPostCalls, hasLength(1));
      final call = rawApi.playingPostCalls.single;
      expect(call['sessionId'], 's1');
      expect(call['playCommand'], enums.SessionsSessionIdPlayingPostPlayCommand.playnow);
      expect(call['itemIds'], ['item-1']);
      expect(call['startPositionTicks'], 12345);
      expect(call['mediaSourceId'], 'src1');
      expect(call['audioStreamIndex'], 1);
      expect(call['subtitleStreamIndex'], 2);
    });

    test('sessionsSessionIdPlayingCommandPost forwards the command/seek and stamps the controlling user id', () async {
      final container = _containerWith(user: _accountWithUrl('http://server.local'));
      addTearDown(container.dispose);
      final rawApi = _FakeRawSessionsApi();
      final service = JellyService(_refOf(container), rawApi);

      await service.sessionsSessionIdPlayingCommandPost(
        sessionId: 's1',
        command: enums.SessionsSessionIdPlayingCommandPostCommand.seek,
        seekPositionTicks: 999,
      );

      final call = rawApi.playingCommandCalls.single;
      expect(call['sessionId'], 's1');
      expect(call['command'], enums.SessionsSessionIdPlayingCommandPostCommand.seek);
      expect(call['seekPositionTicks'], 999);
      expect(call['controllingUserId'], 'user-id');
    });
  });
}

/// `buildVideoStreamUrl` is a pure function that never touches `api`, so any
/// [JellyfinOpenApi] instance works here; `.create()` just wires up a chopper
/// client without performing any network I/O.
JellyfinOpenApi fakeJellyfinOpenApiStub() => JellyfinOpenApi.create();

/// Fakes the raw Sessions endpoints below `JellyService`'s wrappers, so the
/// wrapper methods themselves (param forwarding, the hardcoded PlayNow
/// command, stamping the controlling user id) can be exercised without any
/// network I/O.
class _FakeRawSessionsApi extends JellyfinOpenApi {
  @override
  Type get definitionType => throw UnimplementedError();

  Map<String, String> customPrefs = {};

  @override
  Future<Response<DisplayPreferencesDto>> displayPreferencesDisplayPreferencesIdGet({
    required String? displayPreferencesId,
    String? userId,
    required String? $client,
  }) async =>
      Response(http.Response('', 200), DisplayPreferencesDto(customPrefs: customPrefs));

  List<SessionInfoDto> sessions = const [];
  String? capturedControllableByUserId;

  final List<Map<String, dynamic>> playingPostCalls = [];
  final List<Map<String, dynamic>> playingCommandCalls = [];

  @override
  Future<Response<List<SessionInfoDto>>> sessionsGet({
    String? controllableByUserId,
    String? deviceId,
    int? activeWithinSeconds,
  }) async {
    capturedControllableByUserId = controllableByUserId;
    return Response(http.Response('', 200), sessions);
  }

  @override
  Future<Response> sessionsSessionIdPlayingPost({
    required String? sessionId,
    required enums.SessionsSessionIdPlayingPostPlayCommand? playCommand,
    required List<String>? itemIds,
    int? startPositionTicks,
    String? mediaSourceId,
    int? audioStreamIndex,
    int? subtitleStreamIndex,
    int? startIndex,
  }) async {
    playingPostCalls.add({
      'sessionId': sessionId,
      'playCommand': playCommand,
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
    required String? sessionId,
    required enums.SessionsSessionIdPlayingCommandPostCommand? command,
    int? seekPositionTicks,
    String? controllingUserId,
  }) async {
    playingCommandCalls.add({
      'sessionId': sessionId,
      'command': command,
      'seekPositionTicks': seekPositionTicks,
      'controllingUserId': controllingUserId,
    });
    return Response(http.Response('', 200), null);
  }
}
