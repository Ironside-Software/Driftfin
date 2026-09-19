import 'dart:convert';
import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:driftfin/models/seerr/seerr_dashboard_model.dart';
import 'package:driftfin/providers/seerr_service_provider.dart';
import 'package:driftfin/providers/connectivity_provider.dart';
import 'package:driftfin/seerr/seerr_chopper_service.dart';
import 'package:driftfin/seerr/seerr_json_converter.dart';
import 'package:driftfin/seerr/seerr_models.dart';

/// Exposes a real [Ref] bound to a [ProviderContainer], since [SeerrService]
/// needs a [Ref] rather than the container itself.
final _refProvider = Provider<Ref>((ref) => ref);

/// Builds a [SeerrService] backed by a [MockClient] so the chopper transport
/// layer is faked but the real request/response pipeline (including
/// [SeerrJsonConverter]) still runs.
///
/// Some call sites build the service once per `group()` (shared across that
/// group's tests) rather than per `test()`, so the container can't be torn
/// down with `addTearDown` (which requires an active test context). These
/// containers are small and short-lived with no listeners/timers attached,
/// so leaving disposal to the garbage collector is safe here.
SeerrService buildService(http.Client client) {
  final chopper = ChopperClient(
    baseUrl: Uri.parse('https://seerr.test'),
    client: client,
    converter: const SeerrJsonConverter(),
  );
  final container = ProviderContainer(overrides: [offlineStateProvider.overrideWithValue(false)]);
  final ref = container.read(_refProvider);
  return SeerrService(ref, SeerrChopperService.create(chopper));
}

void main() {
  group('posterFromPersonCredit', () {
    // `addTearDown` (used inside `buildService` to dispose the
    // `ProviderContainer`) only works inside an active test zone, so the
    // service must be (re)built in `setUp` rather than directly in the
    // group body.
    late SeerrService service;
    setUp(() {
      service = buildService(MockClient((req) async => http.Response('{}', 200)));
    });

    test('returns null when tmdbId is missing', () {
      final credit = SeerrPersonCredit(title: 'No Id');
      expect(service.posterFromPersonCredit(credit), isNull);
    });

    test('returns null when title is missing on both title/name', () {
      final credit = SeerrPersonCredit(id: 5);
      expect(service.posterFromPersonCredit(credit), isNull);
    });

    test('movie credit uses title fallback chain and releaseDate year', () {
      final credit = SeerrPersonCredit(
        id: 603,
        title: 'The Matrix',
        overview: 'A hacker discovers reality.',
        releaseDate: '1999-03-31',
      );
      final poster = service.posterFromPersonCredit(credit);
      expect(poster, isNotNull);
      expect(poster!.type, SeerrMediaType.movie);
      expect(poster.tmdbId, 603);
      expect(poster.title, 'The Matrix');
      expect(poster.releaseYear, '1999');
      expect(poster.id, 'tmdb:movie:603');
    });

    test('movie credit falls back to name when title missing', () {
      final credit = SeerrPersonCredit(id: 1, name: 'Fallback Name');
      final poster = service.posterFromPersonCredit(credit);
      expect(poster!.title, 'Fallback Name');
      expect(poster.type, SeerrMediaType.movie);
    });

    test('tv credit (explicit mediaType) uses name fallback chain and firstAirDate year', () {
      final credit = SeerrPersonCredit(
        id: 1399,
        mediaType: SeerrMediaType.tvshow,
        name: 'Game of Thrones',
        firstAirDate: '2011-04-17',
      );
      final poster = service.posterFromPersonCredit(credit);
      expect(poster!.type, SeerrMediaType.tvshow);
      expect(poster.releaseYear, '2011');
      expect(poster.id, 'tmdb:tv:1399');
    });

    test('infers tvshow type from presence of firstAirDate when mediaType is null', () {
      final credit = SeerrPersonCredit(id: 42, name: 'Inferred Show', firstAirDate: '2020-01-01');
      final poster = service.posterFromPersonCredit(credit);
      expect(poster!.type, SeerrMediaType.tvshow);
    });

    test('tv credit falls back to title when name missing', () {
      final credit = SeerrPersonCredit(id: 7, mediaType: SeerrMediaType.tvshow, title: 'Title Fallback');
      final poster = service.posterFromPersonCredit(credit);
      expect(poster!.title, 'Title Fallback');
    });

    test('uses mediaInfo.tmdbId when top-level id is missing', () {
      final credit = SeerrPersonCredit(
        title: 'Via MediaInfo',
        mediaInfo: SeerrMediaInfo(tmdbId: 999),
      );
      final poster = service.posterFromPersonCredit(credit);
      expect(poster!.tmdbId, 999);
      expect(poster.jellyfinItemId, isNull);
    });

    test('populates jellyfinItemId from mediaInfo primary id', () {
      final credit = SeerrPersonCredit(
        id: 10,
        title: 'Has Jellyfin Id',
        mediaInfo: SeerrMediaInfo(jellyfinMediaId: 'jf-1'),
      );
      final poster = service.posterFromPersonCredit(credit);
      expect(poster!.jellyfinItemId, 'jf-1');
    });

    test('leaves releaseYear null when date string is empty', () {
      final credit = SeerrPersonCredit(id: 11, title: 'Empty Date', releaseDate: '');
      final poster = service.posterFromPersonCredit(credit);
      expect(poster!.releaseYear, isNull);
    });

    test('images are null when poster/backdrop paths are absent', () {
      final credit = SeerrPersonCredit(id: 12, title: 'No Images');
      final poster = service.posterFromPersonCredit(credit);
      expect(poster!.images.primary, isNull);
      expect(poster.images.backDrop, isNull);
    });

    test('images are populated when poster/backdrop paths are present', () {
      final credit = SeerrPersonCredit(
        id: 13,
        title: 'With Images',
        internalPosterPath: '/poster.jpg',
        internalBackdropPath: '/backdrop.jpg',
      );
      final poster = service.posterFromPersonCredit(credit);
      expect(poster!.images.primary, isNotNull);
      expect(poster.images.primary!.path, contains('/poster.jpg'));
      expect(poster.images.backDrop, isNotNull);
      expect(poster.images.backDrop!.single.path, contains('/backdrop.jpg'));
    });

    test('mediaStatus defaults to unknown when mediaInfo has no status', () {
      final credit = SeerrPersonCredit(id: 14, title: 'No Status');
      final poster = service.posterFromPersonCredit(credit);
      expect(poster!.mediaStatus, SeerrMediaStatus.unknown);
    });
  });

  group('posterFromDiscoverItem / _resolveMediaType', () {
    late SeerrService service;
    setUp(() {
      service = buildService(MockClient((req) async => http.Response('{}', 200)));
    });

    test('returns null for person media type', () {
      final item = SeerrDiscoverItem(id: 1, mediaType: SeerrMediaType.person, name: 'Some Person');
      expect(service.posterFromDiscoverItem(item), isNull);
    });

    test('returns null when mediaType is null and no tvdbId/tmdbId can be inferred', () {
      final item = SeerrDiscoverItem(id: 1, title: 'Unresolvable');
      expect(service.posterFromDiscoverItem(item), isNull);
    });

    test('explicit movie mediaType resolves to movie poster', () {
      final item = SeerrDiscoverItem(
        id: 550,
        mediaType: SeerrMediaType.movie,
        title: 'Fight Club',
        releaseDate: '1999-10-15',
      );
      final poster = service.posterFromDiscoverItem(item);
      expect(poster, isNotNull);
      expect(poster!.type, SeerrMediaType.movie);
      expect(poster.releaseYear, '1999');
      expect(poster.title, 'Fight Club');
    });

    test('explicit tv mediaType resolves to tvshow poster using name', () {
      final item = SeerrDiscoverItem(
        id: 1399,
        mediaType: SeerrMediaType.tvshow,
        name: 'Game of Thrones',
        firstAirDate: '2011-04-17',
      );
      final poster = service.posterFromDiscoverItem(item);
      expect(poster!.type, SeerrMediaType.tvshow);
      expect(poster.releaseYear, '2011');
      expect(poster.title, 'Game of Thrones');
    });

    test('tv title falls back through originalName -> title when name missing', () {
      final item = SeerrDiscoverItem(
        id: 2,
        mediaType: SeerrMediaType.tvshow,
        originalName: 'Original Name',
      );
      final poster = service.posterFromDiscoverItem(item);
      expect(poster!.title, 'Original Name');
    });

    test('movie title falls back through originalTitle -> name when title missing', () {
      final item = SeerrDiscoverItem(
        id: 3,
        mediaType: SeerrMediaType.movie,
        originalTitle: 'Original Title',
      );
      final poster = service.posterFromDiscoverItem(item);
      expect(poster!.title, 'Original Title');
    });

    test('infers tvshow when mediaType null but mediaInfo.tvdbId present', () {
      final item = SeerrDiscoverItem(
        id: 4,
        name: 'Inferred TV',
        mediaInfo: SeerrMediaInfo(tvdbId: 12345),
      );
      final poster = service.posterFromDiscoverItem(item);
      expect(poster!.type, SeerrMediaType.tvshow);
    });

    test('infers movie when mediaType null but mediaInfo.tmdbId present (no tvdbId)', () {
      final item = SeerrDiscoverItem(
        id: 5,
        title: 'Inferred Movie',
        mediaInfo: SeerrMediaInfo(tmdbId: 999),
      );
      final poster = service.posterFromDiscoverItem(item);
      expect(poster!.type, SeerrMediaType.movie);
    });

    test('tvdbId takes priority over tmdbId when both present and mediaType null', () {
      final item = SeerrDiscoverItem(
        id: 6,
        name: 'Both Ids',
        mediaInfo: SeerrMediaInfo(tvdbId: 1, tmdbId: 2),
      );
      final poster = service.posterFromDiscoverItem(item);
      expect(poster!.type, SeerrMediaType.tvshow);
    });

    test('falls back to tmdbId 0 when id and mediaInfo.tmdbId are both missing', () {
      final item = SeerrDiscoverItem(mediaType: SeerrMediaType.movie, title: 'No Ids At All');
      final poster = service.posterFromDiscoverItem(item);
      expect(poster!.tmdbId, 0);
    });

    test('derives mediaStatus from mediaInfo.status via fromRaw', () {
      final item = SeerrDiscoverItem(
        id: 7,
        mediaType: SeerrMediaType.movie,
        title: 'Available Movie',
        mediaInfo: SeerrMediaInfo(status: 5),
      );
      final poster = service.posterFromDiscoverItem(item);
      expect(poster!.mediaStatus, SeerrMediaStatus.available);
    });

    test('mediaStatus is null (defaults to unknown) when mediaInfo.status is absent', () {
      final item = SeerrDiscoverItem(id: 8, mediaType: SeerrMediaType.movie, title: 'No Status');
      final poster = service.posterFromDiscoverItem(item);
      expect(poster!.mediaStatus, SeerrMediaStatus.unknown);
    });
  });

  group('_shouldRetryWithHostname (via authenticateJellyfin failure path)', () {
    test('retries with hostname when error mentions hostname + not configured', () async {
      var callCount = 0;
      final client = MockClient((req) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(jsonEncode({'message': 'Hostname not configured for this server'}), 400);
        }
        return http.Response('{}', 400, headers: const {});
      });
      final service = buildService(client);

      await expectLater(
        () => service.authenticateJellyfin(username: 'u', password: 'p'),
        throwsA(isA<HttpException>()),
      );
      expect(callCount, 2, reason: 'should have retried once with hostname supplied');
    });

    test('does not retry when error is unrelated to hostname', () async {
      var callCount = 0;
      final client = MockClient((req) async {
        callCount++;
        return http.Response(jsonEncode({'message': 'Invalid credentials'}), 401);
      });
      final service = buildService(client);

      await expectLater(
        () => service.authenticateJellyfin(username: 'u', password: 'p'),
        throwsA(isA<HttpException>()),
      );
      expect(callCount, 1, reason: 'unrelated failures should not trigger a retry');
    });

    test('does not retry when hostname is mentioned without a matching keyword', () async {
      var callCount = 0;
      final client = MockClient((req) async {
        callCount++;
        return http.Response(jsonEncode({'message': 'hostname looks weird'}), 400);
      });
      final service = buildService(client);

      await expectLater(
        () => service.authenticateJellyfin(username: 'u', password: 'p'),
        throwsA(isA<HttpException>()),
      );
      expect(callCount, 1);
    });
  });

  group('authenticateLocal / authenticateJellyfin (cookie extraction end-to-end)', () {
    test('authenticateLocal returns the session cookie on success', () async {
      final client = MockClient((req) async {
        return http.Response(
          jsonEncode({'id': 1, 'email': 'a@b.com'}),
          200,
          headers: {'set-cookie': 'connect.sid=abc123; Path=/; HttpOnly'},
        );
      });
      final service = buildService(client);
      final cookie = await service.authenticateLocal(email: 'a@b.com', password: 'pw');
      expect(cookie, 'connect.sid=abc123');
    });

    test('authenticateLocal throws when the request is unsuccessful', () async {
      final client = MockClient((req) async => http.Response('{}', 401));
      final service = buildService(client);
      await expectLater(
        () => service.authenticateLocal(email: 'a@b.com', password: 'wrong'),
        throwsA(isA<HttpException>()),
      );
    });

    test('authenticateLocal throws when no session cookie is returned', () async {
      final client = MockClient((req) async => http.Response(jsonEncode({'id': 1}), 200));
      final service = buildService(client);
      await expectLater(
        () => service.authenticateLocal(email: 'a@b.com', password: 'pw'),
        throwsA(isA<HttpException>()),
      );
    });

    test('authenticateJellyfin succeeds on first try and returns cookie', () async {
      var callCount = 0;
      final client = MockClient((req) async {
        callCount++;
        return http.Response(
          jsonEncode({'id': 2}),
          200,
          headers: {'set-cookie': 'connect.sid=jf-cookie; Path=/'},
        );
      });
      final service = buildService(client);
      final cookie = await service.authenticateJellyfin(username: 'u', password: 'p');
      expect(cookie, 'connect.sid=jf-cookie');
      expect(callCount, 1);
    });

    test('authenticateJellyfin retries with hostname then succeeds', () async {
      var callCount = 0;
      final client = MockClient((req) async {
        callCount++;
        if (callCount == 1) {
          return http.Response(jsonEncode({'message': 'hostname is required'}), 400);
        }
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['hostname'], isNotEmpty, reason: 'retry should include the local hostname');
        return http.Response(
          jsonEncode({'id': 3}),
          200,
          headers: {'set-cookie': 'connect.sid=retry-cookie; Path=/'},
        );
      });
      final service = buildService(client);
      final cookie = await service.authenticateJellyfin(username: 'u', password: 'p');
      expect(cookie, 'connect.sid=retry-cookie');
      expect(callCount, 2);
    });
  });

  group('movieRatings / tvRatings short-circuit on failure', () {
    test('movieRatings returns null when the API call is unsuccessful', () async {
      final client = MockClient((req) async => http.Response('{}', 404));
      final service = buildService(client);
      final result = await service.movieRatings(603);
      expect(result, isNull);
    });

    test('tvRatings returns null when the API call is unsuccessful', () async {
      final client = MockClient((req) async => http.Response('{}', 500));
      final service = buildService(client);
      final result = await service.tvRatings(1399);
      expect(result, isNull);
    });

    test('movieRatings returns parsed body when successful', () async {
      final client = MockClient((req) async => http.Response(
            jsonEncode({
              'rt': {'title': 'Fight Club', 'criticsScore': 79},
            }),
            200,
          ));
      final service = buildService(client);
      final result = await service.movieRatings(603);
      expect(result, isNotNull);
      expect(result!.rt?.title, 'Fight Club');
      expect(result.rt?.criticsScore, 79);
    });
  });

  group('fetchDashboardPosterFromIds (_seasonStatusMap via tv details)', () {
    test('returns null when neither tmdbId nor tvdbId provided', () async {
      final service = buildService(MockClient((req) async => http.Response('{}', 200)));
      final result = await service.fetchDashboardPosterFromIds();
      expect(result, isNull);
    });

    test('returns null for tvdbId lookup when tmdbId is also missing', () async {
      final service = buildService(MockClient((req) async => http.Response('{}', 200)));
      final result = await service.fetchDashboardPosterFromIds(tvdbId: 12345);
      expect(result, isNull);
    });

    test('builds seasonStatuses map from tv details, skipping null season numbers', () async {
      final client = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'id': 1399,
            'name': 'Game of Thrones',
            'overview': 'Noble families vie for control.',
            'firstAirDate': '2011-04-17',
            'mediaInfo': {
              'seasons': [
                {'seasonNumber': 1, 'status': 5},
                {'seasonNumber': null, 'status': 5},
                {'seasonNumber': 2, 'status': 2},
              ],
            },
          }),
          200,
        );
      });
      final service = buildService(client);
      final poster = await service.fetchDashboardPosterFromIds(tmdbId: 1399, mediaType: SeerrMediaType.tvshow);
      expect(poster, isNotNull);
      expect(poster!.type, SeerrMediaType.tvshow);
      expect(poster.seasonStatuses, {1: SeerrMediaStatus.available, 2: SeerrMediaStatus.pending});
      expect(poster.releaseYear, '2011');
    });

    test('seasonStatuses is null when the seasons list has no usable entries', () async {
      final client = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'id': 42,
            'name': 'No Seasons Show',
            'mediaInfo': {
              'seasons': [
                {'seasonNumber': null, 'status': 5},
              ],
            },
          }),
          200,
        );
      });
      final service = buildService(client);
      final poster = await service.fetchDashboardPosterFromIds(tmdbId: 42, mediaType: SeerrMediaType.tvshow);
      expect(poster!.seasonStatuses, isNull);
    });

    test('resolves movie details when mediaType is not tvshow', () async {
      final client = MockClient((req) async {
        return http.Response(
          jsonEncode({
            'id': 550,
            'title': 'Fight Club',
            'overview': 'A depressed man.',
            'releaseDate': '1999-10-15',
          }),
          200,
        );
      });
      final service = buildService(client);
      final poster = await service.fetchDashboardPosterFromIds(tmdbId: 550, mediaType: SeerrMediaType.movie);
      expect(poster!.type, SeerrMediaType.movie);
      expect(poster.releaseYear, '1999');
      expect(poster.title, 'Fight Club');
    });

    test('returns null when the underlying details call is unsuccessful', () async {
      final client = MockClient((req) async => http.Response('{}', 404));
      final service = buildService(client);
      final poster = await service.fetchDashboardPosterFromIds(tmdbId: 999, mediaType: SeerrMediaType.movie);
      expect(poster, isNull);
    });
  });
}
