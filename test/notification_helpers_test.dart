import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/models/last_seen_notifications_model.dart';
import 'package:driftfin/models/seerr_credentials_model.dart';
import 'package:driftfin/seerr/seerr_chopper_service.dart';
import 'package:driftfin/util/notification_helpers.dart';

void main() {
  group('NotificationHelpers.buildDetailsDeepLink', () {
    test('wraps the id in the driftfin details scheme', () {
      expect(NotificationHelpers.buildDetailsDeepLink('abc123'), 'driftfin:///details?id=abc123');
    });

    test('percent-encodes characters that are unsafe in a URI component', () {
      expect(NotificationHelpers.buildDetailsDeepLink('a b/c?d'), 'driftfin:///details?id=a%20b%2Fc%3Fd');
    });

    test('empty id still produces a valid link', () {
      expect(NotificationHelpers.buildDetailsDeepLink(''), 'driftfin:///details?id=');
    });
  });

  group('NotificationHelpers.buildSeerrDeepLink', () {
    test('builds a seerr deep link with media type and tmdb id', () {
      expect(NotificationHelpers.buildSeerrDeepLink('movie', 42), 'driftfin:///seerr/movie/42');
    });

    test('works for tv media type', () {
      expect(NotificationHelpers.buildSeerrDeepLink('tv', 7), 'driftfin:///seerr/tv/7');
    });
  });

  group('NotificationHelpers.replaceOrAppendLastSeen', () {
    test('appends a new entry when the userId is not already present', () {
      const existing = LastSeenModel(userId: 'user-1');
      const saved = LastSeenModel(userId: 'user-2');
      final result = NotificationHelpers.replaceOrAppendLastSeen([existing], saved);
      expect(result, [existing, saved]);
    });

    test('replaces the existing entry for a matching userId', () {
      const existing = LastSeenModel(userId: 'user-1');
      const updated = LastSeenModel(userId: 'user-1', lastNotifications: []);
      final result = NotificationHelpers.replaceOrAppendLastSeen([existing], updated);
      expect(result, hasLength(1));
      expect(identical(result.first, updated), isTrue);
    });

    test('starting from an empty list appends the saved entry', () {
      const saved = LastSeenModel(userId: 'user-1');
      final result = NotificationHelpers.replaceOrAppendLastSeen([], saved);
      expect(result, [saved]);
    });

    test('only replaces the matching entry, leaving others untouched', () {
      const a = LastSeenModel(userId: 'a');
      const b = LastSeenModel(userId: 'b');
      const updatedB = LastSeenModel(userId: 'b', lastNotifications: []);
      final result = NotificationHelpers.replaceOrAppendLastSeen([a, b], updatedB);
      expect(result, [a, updatedB]);
    });
  });

  group('NotificationHelpers.createSeerrClient', () {
    test('constructs a SeerrChopperService using the provided credentials', () {
      const credentials = SeerrCredentialsModel(
        serverUrl: 'https://seerr.example.com',
        apiKey: ' key-1 ',
        sessionCookie: '',
        customHeaders: {'X-Test': '1'},
      );
      final service = NotificationHelpers.createSeerrClient(credentials);
      expect(service, isA<SeerrChopperService>());
    });
  });

  // fetchSeerrRequests and fetchLatestItems are skipped: both build their own
  // ChopperClient/JellyfinOpenApi internally (createSeerrClient has no seam to
  // inject an http.Client/MockClient, and dto.JellyfinOpenApi.create talks to a
  // real network stack), so they cannot be exercised without either a live
  // server or a mocking framework, which this repo's test conventions disallow.
}
