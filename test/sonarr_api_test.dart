import 'package:driftfin/models/seerr_credentials_model.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:driftfin/providers/sonarr_provider.dart';

void main() {
  const base = 'http://sonarr.test:8989';
  const key = 'APIKEY';

  SonarrApi api(http.Client client) => SonarrApi(baseUrl: base, apiKey: key, client: client);

  group('normalizeSonarrUrl', () {
    test('trims and strips trailing slashes', () {
      expect(normalizeSonarrUrl('  http://host:8989/  '), 'http://host:8989');
      expect(normalizeSonarrUrl('http://host:8989///'), 'http://host:8989');
      expect(normalizeSonarrUrl('http://host:8989'), 'http://host:8989');
    });
  });

  group('SonarrSettings', () {
    test('isConfigured requires enabled + url + key', () {
      expect(
        const SonarrSettings(origin: CredentialOrigin.manual, enabled: true, baseUrl: 'x', apiKey: 'k').isConfigured,
        isTrue,
      );
      expect(
        const SonarrSettings(origin: CredentialOrigin.manual, enabled: false, baseUrl: 'x', apiKey: 'k').isConfigured,
        isFalse,
      );
      expect(
        const SonarrSettings(origin: CredentialOrigin.manual, enabled: true, baseUrl: '', apiKey: 'k').isConfigured,
        isFalse,
      );
      expect(
        const SonarrSettings(origin: CredentialOrigin.manual, enabled: true, baseUrl: 'x', apiKey: '').isConfigured,
        isFalse,
      );
    });

    test('json round-trip', () {
      const settings = SonarrSettings(origin: CredentialOrigin.manual, enabled: true, baseUrl: 'http://h', apiKey: 'k');
      final restored = SonarrSettings.fromJson(settings.toJson());
      expect(restored.enabled, isTrue);
      expect(restored.baseUrl, 'http://h');
      expect(restored.apiKey, 'k');
    });
  });

  group('SonarrApi', () {
    test('findSeriesIdByTvdb matches tvdbId and sends api-key header', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode([
            {'id': 1, 'tvdbId': 111},
            {'id': 7, 'tvdbId': 222},
          ]),
          200,
        );
      });
      expect(await api(client).findSeriesIdByTvdb(222), 7);
      expect(captured.url.toString(), '$base/api/v3/series');
      expect(captured.headers['X-Api-Key'], key);
    });

    test('findSeriesIdByTvdb returns null when not found', () async {
      final client = MockClient(
        (req) async => http.Response(
          jsonEncode([
            {'id': 1, 'tvdbId': 111},
          ]),
          200,
        ),
      );
      expect(await api(client).findSeriesIdByTvdb(999), isNull);
    });

    test('findSeriesIdByTvdb returns null on non-200', () async {
      final client = MockClient((req) async => http.Response('nope', 401));
      expect(await api(client).findSeriesIdByTvdb(111), isNull);
    });

    test('findEpisodeId matches season+episode and queries seriesId', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode([
            {'id': 10, 'seasonNumber': 1, 'episodeNumber': 1},
            {'id': 20, 'seasonNumber': 2, 'episodeNumber': 5},
          ]),
          200,
        );
      });
      expect(await api(client).findEpisodeId(7, 2, 5), 20);
      expect(captured.url.path, '/api/v3/episode');
      expect(captured.url.queryParameters['seriesId'], '7');
    });

    test('monitorEpisodes PUTs episode/monitor with monitored=true', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('', 202);
      });
      expect(await api(client).monitorEpisodes([20]), isTrue);
      expect(captured.method, 'PUT');
      expect(captured.url.toString(), '$base/api/v3/episode/monitor');
      expect(jsonDecode(captured.body), {
        'episodeIds': [20],
        'monitored': true,
      });
    });

    test('searchEpisodes POSTs EpisodeSearch command', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('', 201);
      });
      expect(await api(client).searchEpisodes([20]), isTrue);
      expect(captured.method, 'POST');
      expect(captured.url.toString(), '$base/api/v3/command');
      expect(jsonDecode(captured.body), {
        'name': 'EpisodeSearch',
        'episodeIds': [20],
      });
    });

    test('requestEpisodeByTvdb happy path: success + correct call sequence', () async {
      final calls = <String>[];
      final client = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        return switch (req.url.path) {
          '/api/v3/series' => http.Response(
            jsonEncode([
              {'id': 7, 'tvdbId': 222},
            ]),
            200,
          ),
          '/api/v3/episode' => http.Response(
            jsonEncode([
              {'id': 20, 'seasonNumber': 2, 'episodeNumber': 5},
            ]),
            200,
          ),
          '/api/v3/episode/monitor' => http.Response('', 202),
          '/api/v3/command' => http.Response('', 201),
          _ => http.Response('not found', 404),
        };
      });
      expect(await api(client).requestEpisodeByTvdb(tvdbId: 222, season: 2, episode: 5), SonarrRequestResult.success);
      expect(calls, [
        'GET /api/v3/series',
        'GET /api/v3/episode',
        'PUT /api/v3/episode/monitor',
        'POST /api/v3/command',
      ]);
    });

    test('requestEpisodeByTvdb -> seriesNotFound', () async {
      final client = MockClient((req) async => http.Response(jsonEncode([]), 200));
      expect(
        await api(client).requestEpisodeByTvdb(tvdbId: 1, season: 1, episode: 1),
        SonarrRequestResult.seriesNotFound,
      );
    });

    test('requestEpisodeByTvdb -> episodeNotFound', () async {
      final client = MockClient((req) async {
        if (req.url.path == '/api/v3/series') {
          return http.Response(
            jsonEncode([
              {'id': 7, 'tvdbId': 222},
            ]),
            200,
          );
        }
        return http.Response(jsonEncode([]), 200);
      });
      expect(
        await api(client).requestEpisodeByTvdb(tvdbId: 222, season: 9, episode: 9),
        SonarrRequestResult.episodeNotFound,
      );
    });

    test('calendar parses entries and sends date range params', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode([
            {
              'seasonNumber': 1,
              'episodeNumber': 1,
              'title': 'Pilot',
              'airDateUtc': '2008-01-21T02:00:00Z',
              'hasFile': false,
              'series': {'title': 'Breaking Bad', 'tvdbId': 81189},
            },
            {
              'seasonNumber': 2,
              'episodeNumber': 3,
              'title': 'No air date',
              'series': {'title': 'X'},
            },
          ]),
          200,
        );
      });
      final items = await api(client).calendar(start: DateTime.utc(2008, 1, 1), end: DateTime.utc(2008, 2, 1));
      // The entry with no airDateUtc is dropped.
      expect(items.length, 1);
      expect(items.first.seriesTitle, 'Breaking Bad');
      expect(items.first.seriesTvdbId, 81189);
      expect(items.first.seasonNumber, 1);
      expect(items.first.episodeNumber, 1);
      expect(items.first.airDateUtc, isNotNull);
      expect(captured.url.path, '/api/v3/calendar');
      expect(captured.url.queryParameters['includeSeries'], 'true');
      expect(captured.url.queryParameters['unmonitored'], 'true');
      expect(captured.url.queryParameters.containsKey('start'), isTrue);
      expect(captured.url.queryParameters.containsKey('end'), isTrue);
    });

    test('requestEpisodeByTvdb addIfMissing: looks up, adds series, then grabs episode', () async {
      final calls = <String>[];
      Map<String, dynamic>? postedSeries;
      final client = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        switch (req.url.path) {
          case '/api/v3/series':
            if (req.method == 'GET') return http.Response(jsonEncode([]), 200); // not present
            postedSeries = jsonDecode(req.body) as Map<String, dynamic>; // add
            return http.Response(jsonEncode({'id': 5}), 201);
          case '/api/v3/series/lookup':
            return http.Response(
              jsonEncode([
                {'tvdbId': 78874, 'title': 'Firefly', 'titleSlug': 'firefly', 'seasons': []},
              ]),
              200,
            );
          case '/api/v3/rootfolder':
            return http.Response(
              jsonEncode([
                {'path': '/tv', 'accessible': true},
              ]),
              200,
            );
          case '/api/v3/qualityprofile':
            return http.Response(
              jsonEncode([
                {'id': 1, 'name': 'Any'},
              ]),
              200,
            );
          case '/api/v3/episode':
            return http.Response(
              jsonEncode([
                {'id': 50, 'seasonNumber': 1, 'episodeNumber': 1},
              ]),
              200,
            );
          case '/api/v3/episode/monitor':
            return http.Response('', 202);
          case '/api/v3/command':
            return http.Response('', 201);
        }
        return http.Response('not found', 404);
      });

      final result = await api(client).requestEpisodeByTvdb(tvdbId: 78874, season: 1, episode: 1, addIfMissing: true);
      expect(result, SonarrRequestResult.success);
      // The series was added unmonitored without a full-series search.
      expect(postedSeries?['rootFolderPath'], '/tv');
      expect(postedSeries?['qualityProfileId'], 1);
      expect(postedSeries?['addOptions']?['monitor'], 'none');
      expect(postedSeries?['addOptions']?['searchForMissingEpisodes'], false);
      expect(calls.contains('POST /api/v3/series'), isTrue);
    });

    test('requestEpisodeByTvdb addIfMissing -> seriesNotFound when no root folder', () async {
      final client = MockClient((req) async {
        return switch (req.url.path) {
          '/api/v3/series' => http.Response(jsonEncode([]), 200),
          '/api/v3/series/lookup' => http.Response(
            jsonEncode([
              {'tvdbId': 78874, 'title': 'Firefly'},
            ]),
            200,
          ),
          '/api/v3/rootfolder' => http.Response(jsonEncode([]), 200), // none configured
          '/api/v3/qualityprofile' => http.Response(
            jsonEncode([
              {'id': 1},
            ]),
            200,
          ),
          _ => http.Response('not found', 404),
        };
      });
      expect(
        await api(client).requestEpisodeByTvdb(tvdbId: 78874, season: 1, episode: 1, addIfMissing: true),
        SonarrRequestResult.seriesNotFound,
      );
    });

    test('requestEpisodeByTvdb stops if monitoring fails', () async {
      final client = MockClient((request) async {
        expect(request.url.path, isNot('/api/v3/command'));
        return switch (request.url.path) {
          '/api/v3/series' => http.Response('[{"id":7,"tvdbId":222}]', 200),
          '/api/v3/episode' => http.Response('[{"id":20,"seasonNumber":2,"episodeNumber":5}]', 200),
          _ => http.Response('', 403),
        };
      });
      expect(await api(client).requestEpisodeByTvdb(tvdbId: 222, season: 2, episode: 5), SonarrRequestResult.failed);
    });

    test('requestEpisodeByTvdb -> failed when the search command errors', () async {
      final client = MockClient((req) async {
        return switch (req.url.path) {
          '/api/v3/series' => http.Response(
            jsonEncode([
              {'id': 7, 'tvdbId': 222},
            ]),
            200,
          ),
          '/api/v3/episode' => http.Response(
            jsonEncode([
              {'id': 20, 'seasonNumber': 2, 'episodeNumber': 5},
            ]),
            200,
          ),
          '/api/v3/episode/monitor' => http.Response('', 202),
          _ => http.Response('err', 500),
        };
      });
      expect(await api(client).requestEpisodeByTvdb(tvdbId: 222, season: 2, episode: 5), SonarrRequestResult.failed);
    });
  });
}
