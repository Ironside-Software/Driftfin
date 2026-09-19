class DriftfinConfig {
  static DriftfinConfig _instance = DriftfinConfig._();
  DriftfinConfig._();

  static String? get baseUrl => _instance._baseUrl;
  static set baseUrl(String? value) => _instance._baseUrl = value;
  String? _baseUrl;

  static String? get seerrBaseUrl => _instance._seerrBaseUrl;
  static set seerrBaseUrl(String? value) => _instance._seerrBaseUrl = value;
  String? _seerrBaseUrl;

  /// Sentry DSN for opt-in crash reporting on Web, set at container runtime
  /// (docker-compose's `SENTRY_DSN` env var) rather than build time, since Web
  /// builds are shared across deployments. Falls back to the compile-time
  /// `--dart-define=SENTRY_DSN` on every other platform — see `sentryDsn` in
  /// `app_bootstrap.dart`.
  static String? get sentryDsn => _instance._sentryDsn;
  static set sentryDsn(String? value) => _instance._sentryDsn = value;
  String? _sentryDsn;

  static void fromJson(Map<String, dynamic> json) => _instance = DriftfinConfig._fromJson(json);

  factory DriftfinConfig._fromJson(Map<String, dynamic> json) {
    final config = DriftfinConfig._();
    final newUrl = json['baseUrl'] as String?;
    final newSeerrUrl = json['seerrBaseUrl'] as String?;
    final newSentryDsn = json['sentryDsn'] as String?;

    config._baseUrl = newUrl?.isEmpty == true ? null : newUrl;
    config._seerrBaseUrl = newSeerrUrl?.isEmpty == true ? null : newSeerrUrl;
    config._sentryDsn = newSentryDsn?.isEmpty == true ? null : newSentryDsn;

    return config;
  }
}
