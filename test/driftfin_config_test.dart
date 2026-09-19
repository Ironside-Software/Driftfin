import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/util/driftfin_config.dart';

void main() {
  tearDown(() {
    DriftfinConfig.baseUrl = null;
    DriftfinConfig.seerrBaseUrl = null;
    DriftfinConfig.sentryDsn = null;
  });

  group('DriftfinConfig.fromJson', () {
    test('parses all fields from a fully populated config', () {
      DriftfinConfig.fromJson({
        'baseUrl': 'https://jellyfin.example.com',
        'seerrBaseUrl': 'https://seerr.example.com',
        'sentryDsn': 'https://key@o0.ingest.sentry.io/0',
      });

      expect(DriftfinConfig.baseUrl, 'https://jellyfin.example.com');
      expect(DriftfinConfig.seerrBaseUrl, 'https://seerr.example.com');
      expect(DriftfinConfig.sentryDsn, 'https://key@o0.ingest.sentry.io/0');
    });

    test('null values are preserved as null', () {
      DriftfinConfig.fromJson({'baseUrl': null, 'seerrBaseUrl': null, 'sentryDsn': null});

      expect(DriftfinConfig.baseUrl, isNull);
      expect(DriftfinConfig.seerrBaseUrl, isNull);
      expect(DriftfinConfig.sentryDsn, isNull);
    });

    test('empty strings are normalized to null', () {
      DriftfinConfig.fromJson({'baseUrl': '', 'seerrBaseUrl': '', 'sentryDsn': ''});

      expect(DriftfinConfig.baseUrl, isNull);
      expect(DriftfinConfig.seerrBaseUrl, isNull);
      expect(DriftfinConfig.sentryDsn, isNull);
    });

    test('missing keys are treated as null (docker-entrypoint always writes them, but be defensive)', () {
      DriftfinConfig.fromJson({});

      expect(DriftfinConfig.baseUrl, isNull);
      expect(DriftfinConfig.seerrBaseUrl, isNull);
      expect(DriftfinConfig.sentryDsn, isNull);
    });

    test('replaces the previous config wholesale rather than merging', () {
      DriftfinConfig.fromJson({'baseUrl': 'https://first.example.com', 'sentryDsn': 'https://first-dsn'});
      DriftfinConfig.fromJson({'seerrBaseUrl': 'https://second.example.com'});

      expect(DriftfinConfig.baseUrl, isNull);
      expect(DriftfinConfig.sentryDsn, isNull);
      expect(DriftfinConfig.seerrBaseUrl, 'https://second.example.com');
    });
  });

  group('DriftfinConfig static setters', () {
    test('can be set directly without going through fromJson', () {
      DriftfinConfig.sentryDsn = 'https://direct-dsn';
      expect(DriftfinConfig.sentryDsn, 'https://direct-dsn');
    });
  });
}
