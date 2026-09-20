import 'package:driftfin/models/seerr_credentials_model.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/incognito_mode_provider.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:driftfin/providers/trakt_provider.dart';

void main() {
  const id = 'CLIENT_ID';
  const secret = 'CLIENT_SECRET';

  TraktApi api(http.Client client, {String? token}) =>
      TraktApi(clientId: id, clientSecret: secret, accessToken: token, client: client);

  test('incognito mode suppresses Trakt scrobbles', () async {
    SharedPreferences.setMockInitialValues({
      'traktSettings': jsonEncode(
        const TraktSettings(
          origin: CredentialOrigin.manual,
          clientId: 'test-client',
          clientSecret: 'test-secret',
          enabled: true,
          tokens: TraktTokens(accessToken: 'test-token', refreshToken: '', createdAt: 0, expiresIn: 10000),
        ).toJson(),
      ),
    });
    final prefs = await SharedPreferences.getInstance();
    var requests = 0;
    await http.runWithClient(
      () async {
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs), incognitoProvider.overrideWithValue(true)],
        );
        addTearDown(container.dispose);
        expect(container.read(traktProvider).isActive, isTrue);
        await container
            .read(traktProvider.notifier)
            .scrobbleItem(
              item: ItemBaseModel.fromBaseDto(
                const BaseItemDto(id: 'movie', type: BaseItemKind.movie, providerIds: {'Tmdb': '42'}),
                null,
              ),
              action: TraktScrobbleAction.start,
              progress: 10,
              nowSeconds: 1,
            );
        expect(requests, 0);
      },
      () => MockClient((request) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
  });

  group('TraktApi auth', () {
    test('requestDeviceCode parses the device code + sends api key', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({
            'device_code': 'DEV',
            'user_code': '1234ABCD',
            'verification_url': 'https://trakt.tv/activate',
            'expires_in': 600,
            'interval': 5,
          }),
          200,
        );
      });
      final code = await api(client).requestDeviceCode();
      expect(code?.userCode, '1234ABCD');
      expect(code?.deviceCode, 'DEV');
      expect(captured.url.toString(), 'https://api.trakt.tv/oauth/device/code');
      expect(captured.headers['trakt-api-key'], id);
      expect(jsonDecode(captured.body), {'client_id': id});
    });

    test('pollDeviceToken maps status codes', () async {
      Future<TraktPollStatus> poll(int status, [Map<String, dynamic>? body]) async {
        final client = MockClient((req) async => http.Response(jsonEncode(body ?? {}), status));
        return (await api(client).pollDeviceToken('DEV')).status;
      }

      expect(await poll(400), TraktPollStatus.pending);
      expect(await poll(429), TraktPollStatus.slowDown);
      expect(await poll(404), TraktPollStatus.invalid);
      expect(await poll(409), TraktPollStatus.invalid);
      expect(await poll(410), TraktPollStatus.expired);
      expect(await poll(418), TraktPollStatus.denied);
      expect(await poll(500), TraktPollStatus.error);
    });

    test('pollDeviceToken success returns tokens', () async {
      final client = MockClient(
        (req) async => http.Response(
          jsonEncode({'access_token': 'ACCESS', 'refresh_token': 'REFRESH', 'created_at': 1000, 'expires_in': 7776000}),
          200,
        ),
      );
      final result = await api(client).pollDeviceToken('DEV');
      expect(result.status, TraktPollStatus.success);
      expect(result.tokens?.accessToken, 'ACCESS');
      expect(result.tokens?.refreshToken, 'REFRESH');
    });

    test('token expiry uses a 1h safety window', () {
      const tokens = TraktTokens(accessToken: 'a', refreshToken: 'r', createdAt: 1000, expiresIn: 7200);
      expect(tokens.expiredAt(1000), isFalse); // fresh
      expect(tokens.expiredAt(1000 + 7200 - 3601), isFalse); // just outside window
      expect(tokens.expiredAt(1000 + 7200 - 3599), isTrue); // inside the 1h window
    });
  });

  group('TraktApi scrobble', () {
    test('episode start sends episode ids + progress to the start endpoint', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{}', 201);
      });
      final ok = await api(
        client,
        token: 'ACCESS',
      ).scrobble(TraktScrobbleAction.start, ids: {'tvdb': 81189}, isMovie: false, progress: 12.5);
      expect(ok, isTrue);
      expect(captured.url.toString(), 'https://api.trakt.tv/scrobble/start');
      expect(captured.headers['Authorization'], 'Bearer ACCESS');
      expect(jsonDecode(captured.body), {
        'episode': {
          'ids': {'tvdb': 81189},
        },
        'progress': 12.5,
      });
    });

    test('scrobbleEpisodeByShow sends show ids + season/number', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{}', 201);
      });
      final ok = await api(client, token: 'ACCESS').scrobbleEpisodeByShow(
        TraktScrobbleAction.pause,
        showIds: {'tvdb': 81189},
        season: 2,
        number: 5,
        progress: 40.0,
      );
      expect(ok, isTrue);
      expect(captured.url.toString(), 'https://api.trakt.tv/scrobble/pause');
      expect(jsonDecode(captured.body), {
        'show': {
          'ids': {'tvdb': 81189},
        },
        'episode': {'season': 2, 'number': 5},
        'progress': 40.0,
      });
    });

    test('movie stop sends movie ids to the stop endpoint', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{}', 200);
      });
      final ok = await api(
        client,
        token: 'ACCESS',
      ).scrobble(TraktScrobbleAction.stop, ids: {'tmdb': 603}, isMovie: true, progress: 99.0);
      expect(ok, isTrue);
      expect(captured.url.toString(), 'https://api.trakt.tv/scrobble/stop');
      expect(jsonDecode(captured.body), {
        'movie': {
          'ids': {'tmdb': 603},
        },
        'progress': 99.0,
      });
    });
  });

  group('traktIdsFromProviderIds', () {
    test('maps Jellyfin provider ids to Trakt ids with correct types', () {
      final ids = traktIdsFromProviderIds({'Tmdb': '603', 'Imdb': 'tt0133093', 'Tvdb': '1234', 'Zap2It': 'xyz'});
      expect(ids, {'tmdb': 603, 'imdb': 'tt0133093', 'tvdb': 1234});
    });

    test('ignores empty/null and non-numeric tmdb/tvdb', () {
      expect(traktIdsFromProviderIds(null), isEmpty);
      expect(traktIdsFromProviderIds({'Tmdb': '', 'Imdb': null}), isEmpty);
      expect(traktIdsFromProviderIds({'Tmdb': 'abc'}), isEmpty);
    });
  });

  group('TraktSettings', () {
    test('isActive requires enabled + creds + tokens', () {
      const tokens = TraktTokens(accessToken: 'a', refreshToken: 'r', createdAt: 0, expiresIn: 1);
      expect(
        const TraktSettings(
          origin: CredentialOrigin.manual,
          enabled: true,
          clientId: 'c',
          clientSecret: 's',
          tokens: tokens,
        ).isActive,
        isTrue,
      );
      expect(
        const TraktSettings(
          origin: CredentialOrigin.manual,
          enabled: false,
          clientId: 'c',
          clientSecret: 's',
          tokens: tokens,
        ).isActive,
        isFalse,
      );
      expect(
        const TraktSettings(
          origin: CredentialOrigin.manual,
          enabled: true,
          clientId: '',
          clientSecret: 's',
          tokens: tokens,
        ).isActive,
        isFalse,
      );
      expect(
        const TraktSettings(origin: CredentialOrigin.manual, enabled: true, clientId: 'c', clientSecret: 's').isActive,
        isFalse,
      );
    });

    test('json round-trip preserves tokens', () {
      const settings = TraktSettings(
        origin: CredentialOrigin.manual,
        enabled: true,
        clientId: 'c',
        clientSecret: 's',
        tokens: TraktTokens(accessToken: 'a', refreshToken: 'r', createdAt: 5, expiresIn: 10),
      );
      final restored = TraktSettings.fromJson(settings.toJson());
      expect(restored.isAuthenticated, isTrue);
      expect(restored.tokens?.accessToken, 'a');
      expect(restored.clientId, 'c');
    });
  });
}
