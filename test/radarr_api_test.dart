import 'package:driftfin/models/seerr_credentials_model.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:driftfin/providers/radarr_provider.dart';

void main() {
  const base = 'http://radarr.test:7878';
  const key = 'APIKEY';
  RadarrApi api(http.Client c) => RadarrApi(baseUrl: base, apiKey: key, client: c);

  test('normalizeRadarrUrl strips trailing slashes', () {
    expect(normalizeRadarrUrl('http://h:7878/'), 'http://h:7878');
  });

  test('calendar parses movies, picks digital>physical>cinema, drops dateless', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return http.Response(
        jsonEncode([
          {
            'title': 'Fight Club',
            'tmdbId': 550,
            'inCinemas': '1999-10-15T00:00:00Z',
            'physicalRelease': '2000-04-25T00:00:00Z',
            'digitalRelease': '2001-05-26T00:00:00Z',
            'hasFile': false,
          },
          {'title': 'Only cinemas', 'tmdbId': 1, 'inCinemas': '2024-01-01T00:00:00Z', 'hasFile': true},
          {'title': 'No dates', 'tmdbId': 2},
        ]),
        200,
      );
    });
    final items = await api(client).calendar(start: DateTime.utc(1999), end: DateTime.utc(2002));
    expect(items.length, 2); // dateless dropped
    expect(items.first.title, 'Fight Club');
    expect(items.first.releaseDate, DateTime.parse('2001-05-26T00:00:00Z')); // digital preferred
    expect(items[1].releaseDate, DateTime.parse('2024-01-01T00:00:00Z')); // falls back to cinemas
    expect(captured.url.path, '/api/v3/calendar');
    expect(captured.headers['X-Api-Key'], key);
  });

  test('requestMovie: existing movie -> MoviesSearch command', () async {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
      if (req.url.path == '/api/v3/movie' && req.method == 'GET') {
        return http.Response(
          jsonEncode([
            {'id': 9, 'tmdbId': 550},
          ]),
          200,
        );
      }
      if (req.url.path == '/api/v3/command') return http.Response('{}', 201);
      return http.Response('x', 404);
    });
    expect(await api(client).requestMovie(550), RadarrRequestResult.success);
    expect(calls.contains('POST /api/v3/command'), isTrue);
  });

  test('requestMovie: missing movie -> add (lookup+rootfolder+profile+post)', () async {
    Map<String, dynamic>? posted;
    final client = MockClient((req) async {
      switch (req.url.path) {
        case '/api/v3/movie':
          if (req.method == 'GET') return http.Response(jsonEncode([]), 200);
          posted = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'id': 12}), 201);
        case '/api/v3/movie/lookup/tmdb':
          return http.Response(jsonEncode({'tmdbId': 550, 'title': 'Fight Club', 'titleSlug': 'fight-club'}), 200);
        case '/api/v3/rootfolder':
          return http.Response(
            jsonEncode([
              {'path': '/movies', 'accessible': true},
            ]),
            200,
          );
        case '/api/v3/qualityprofile':
          return http.Response(
            jsonEncode([
              {'id': 1},
            ]),
            200,
          );
      }
      return http.Response('x', 404);
    });
    expect(await api(client).requestMovie(550), RadarrRequestResult.success);
    expect(posted?['rootFolderPath'], '/movies');
    expect(posted?['addOptions']?['searchForMovie'], true);
  });

  test('RadarrSettings isConfigured + json round-trip', () {
    expect(
      const RadarrSettings(origin: CredentialOrigin.manual, enabled: true, baseUrl: 'x', apiKey: 'k').isConfigured,
      isTrue,
    );
    expect(
      const RadarrSettings(origin: CredentialOrigin.manual, enabled: false, baseUrl: 'x', apiKey: 'k').isConfigured,
      isFalse,
    );
    final r = RadarrSettings.fromJson(
      const RadarrSettings(origin: CredentialOrigin.manual, enabled: true, baseUrl: 'b', apiKey: 'k').toJson(),
    );
    expect(r.baseUrl, 'b');
    expect(r.enabled, isTrue);
  });
}
