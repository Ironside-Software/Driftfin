import 'dart:convert';

import 'package:auto_route/auto_route.dart' show DeepLink;
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/routes/auto_router.gr.dart';
import 'package:driftfin/util/deep_link_helper.dart';

void main() {
  group('AuthLinkData json', () {
    test('toJson omits null/empty optional fields', () {
      final data = AuthLinkData(serverUrl: 'https://s', userName: 'bob');
      final json = data.toJson();
      expect(json, {'server': 'https://s', 'userName': 'bob'});
    });

    test('toJson includes seerr and non-empty password', () {
      final data = AuthLinkData(serverUrl: 's', seerrUrl: 'seerr', userName: 'bob', password: 'pw');
      final json = data.toJson();
      expect(json['seerr'], 'seerr');
      expect(json['password'], 'pw');
    });

    test('toJson omits an empty password', () {
      final data = AuthLinkData(serverUrl: 's', userName: 'bob', password: '');
      expect(data.toJson().containsKey('password'), isFalse);
    });

    test('fromJson round-trips', () {
      final original = AuthLinkData(serverUrl: 's', seerrUrl: 'seerr', userName: 'bob', password: 'pw');
      final restored = AuthLinkData.fromJson(original.toJson());
      expect(restored.serverUrl, 's');
      expect(restored.seerrUrl, 'seerr');
      expect(restored.userName, 'bob');
      expect(restored.password, 'pw');
    });

    test('toString masks the password', () {
      final data = AuthLinkData(serverUrl: 's', userName: 'bob', password: 'secret');
      expect(data.toString(), isNot(contains('secret')));
      expect(data.toString(), contains('****'));
    });

    test('toString shows null when there is no password', () {
      final data = AuthLinkData(serverUrl: 's', userName: 'bob');
      expect(data.toString(), contains('password: null'));
    });
  });

  group('AuthLinkData.parse / encodeAuthLink round trip', () {
    test('encodes and parses back the same data', () {
      final data = AuthLinkData(serverUrl: 'https://jelly', seerrUrl: 'https://seerr', userName: 'alice');
      final encoded = encodeAuthLink(data);
      final parsed = AuthLinkData.parse(encoded);
      expect(parsed, isNotNull);
      expect(parsed!.serverUrl, 'https://jelly');
      expect(parsed.userName, 'alice');
    });

    test('parse strips the driftfin:///login?authLink= prefix', () {
      final data = AuthLinkData(serverUrl: 's', userName: 'bob');
      final encoded = encodeAuthLink(data);
      final parsed = AuthLinkData.parse('driftfin:///login?authLink=$encoded');
      expect(parsed, isNotNull);
      expect(parsed!.userName, 'bob');
    });

    test('parse handles base64url padding regardless of trailing = stripped by encode', () {
      final data = AuthLinkData(serverUrl: 'https://x', userName: 'u');
      final encoded = encodeAuthLink(data);
      expect(encoded.contains('='), isFalse, reason: 'encodeAuthLink strips padding');
      expect(AuthLinkData.parse(encoded), isNotNull);
    });

    test('returns null for garbage input instead of throwing', () {
      expect(AuthLinkData.parse('not-valid-base64!!!'), isNull);
    });

    test('returns null when decoded JSON is missing required fields', () {
      final bytes = utf8.encode(jsonEncode({'server': 'x'})); // missing userName
      final encoded = base64Url.encode(bytes).replaceAll('=', '');
      expect(AuthLinkData.parse(encoded), isNull);
    });
  });

  group('buildAuthUrl', () {
    test('produces a driftfin:///login?authLink= URL containing the encoded payload', () {
      final data = AuthLinkData(serverUrl: 's', userName: 'u');
      final url = buildAuthUrl(data);
      expect(url, startsWith('driftfin:///login?authLink='));
      expect(url, contains(encodeAuthLink(data)));
    });
  });

  group('payloadToRoute', () {
    test('null payload yields null', () {
      expect(payloadToRoute(null), isNull);
    });

    test('login path with authLink param builds a LoginRoute with that link', () {
      final route = payloadToRoute(Uri.parse('driftfin:///login?authLink=abc123'));
      expect(route, isA<LoginRoute>());
      expect((route as LoginRoute).args!.authLink, 'abc123');
    });

    test('login path without authLink param uses the placeholder', () {
      final route = payloadToRoute(Uri.parse('driftfin:///login'));
      expect(route, isA<LoginRoute>());
      expect((route as LoginRoute).args!.authLink, 'sdflkj');
    });

    test('seerr path with mediaType/tmdbId builds a SeerrDetailsRoute', () {
      final route = payloadToRoute(Uri.parse('driftfin:///seerr/movie/42'));
      expect(route, isA<SeerrDetailsRoute>());
      final r = route as SeerrDetailsRoute;
      expect(r.args!.mediaType, 'movie');
      expect(r.args!.tmdbId, 42);
    });

    test('seerr path with a non-numeric id falls back to the seerr list route', () {
      final route = payloadToRoute(Uri.parse('driftfin:///seerr/movie/abc'));
      expect(route, isA<SeerrRoute>());
    });

    test('seerr path with too few segments falls back to the seerr list route', () {
      final route = payloadToRoute(Uri.parse('driftfin:///seerr'));
      expect(route, isA<SeerrRoute>());
    });

    test('details path with id builds a DetailsRoute', () {
      final route = payloadToRoute(Uri.parse('driftfin:///details?id=abc'));
      expect(route, isA<DetailsRoute>());
      expect((route as DetailsRoute).args!.id, 'abc');
    });

    test('unrecognized path returns null', () {
      expect(payloadToRoute(Uri.parse('driftfin:///unknown')), isNull);
    });
  });

  group('pageRouteInfoToPath', () {
    test('DetailsRoute', () {
      expect(pageRouteInfoToPath(DetailsRoute(id: 'xyz')), '/details?id=xyz');
    });

    test('SeerrDetailsRoute', () {
      expect(pageRouteInfoToPath(SeerrDetailsRoute(mediaType: 'tv', tmdbId: 7)), '/seerr?mediaType=tv&tmdbId=7');
    });

    test('LoginRoute', () {
      expect(pageRouteInfoToPath(LoginRoute(authLink: 'zz')), '/login?authLink=zz');
    });

    test('unmapped route falls back to /', () {
      expect(pageRouteInfoToPath(const SeerrRoute()), '/');
    });
  });

  group('deepLinkBuilder', () {
    test('routable payload becomes a valid path-based DeepLink', () async {
      final link = await deepLinkBuilder(Uri.parse('driftfin:///details?id=abc'));
      expect(link.isValid, isTrue);
      expect(link, isNot(same(DeepLink.defaultPath)));
    });

    test('unroutable payload falls back to the identical DeepLink.defaultPath instance', () async {
      final link = await deepLinkBuilder(Uri.parse('driftfin:///unknown'));
      expect(identical(link, DeepLink.defaultPath), isTrue);
    });

    test('null payload falls back to the identical DeepLink.defaultPath instance', () async {
      final link = await deepLinkBuilder(null);
      expect(identical(link, DeepLink.defaultPath), isTrue);
    });
  });
}
