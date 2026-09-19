import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;

import 'package:driftfin/util/managed_arr_client.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';

/// Outcome of a direct-Radarr movie request.
enum RadarrRequestResult { success, notConfigured, notFound, failed }

/// Normalizes a user-entered Radarr base URL (trim + strip trailing slashes).
String normalizeRadarrUrl(String value) => value.trim().replaceFirst(RegExp(r'/+$'), '');

/// One movie from the Radarr calendar.
class RadarrCalendarItem {
  final String title;
  final int? tmdbId;
  final DateTime? releaseDate;
  final bool hasFile;

  const RadarrCalendarItem({
    required this.title,
    required this.tmdbId,
    required this.releaseDate,
    required this.hasFile,
  });

  factory RadarrCalendarItem.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String? v) => v == null ? null : DateTime.tryParse(v);
    // Prefer the most "watchable" date in range.
    final release =
        parse(json['digitalRelease'] as String?) ??
        parse(json['physicalRelease'] as String?) ??
        parse(json['inCinemas'] as String?);
    return RadarrCalendarItem(
      title: json['title'] as String? ?? '',
      tmdbId: (json['tmdbId'] as num?)?.toInt(),
      releaseDate: release,
      hasFile: json['hasFile'] as bool? ?? false,
    );
  }
}

/// Thin, dependency-free Radarr v3 client. Injectable [http.Client] for tests.
class RadarrApi {
  RadarrApi({required this.baseUrl, required this.apiKey, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/api/v3/$path').replace(queryParameters: query);

  Map<String, String> get _headers => {'X-Api-Key': apiKey, 'Content-Type': 'application/json'};

  Future<List<RadarrCalendarItem>> calendar({required DateTime start, required DateTime end}) async {
    final response = await _client.get(
      _uri('calendar', {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'unmonitored': 'true',
      }),
      headers: _headers,
    );
    if (response.statusCode != 200) return const [];
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((entry) => RadarrCalendarItem.fromJson(entry as Map<String, dynamic>))
        .where((item) => item.releaseDate != null)
        .toList();
  }

  Future<int?> findMovieIdByTmdb(int tmdbId) async {
    final response = await _client.get(_uri('movie', {'tmdbId': '$tmdbId'}), headers: _headers);
    if (response.statusCode != 200) return null;
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.firstWhereOrNull((m) => m['tmdbId'] == tmdbId)?['id'] as int?;
  }

  Future<Map<String, dynamic>?> lookupByTmdb(int tmdbId) async {
    final response = await _client.get(_uri('movie/lookup/tmdb', {'tmdbId': '$tmdbId'}), headers: _headers);
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    final map = decoded is List ? (decoded.isEmpty ? null : decoded.first) : decoded;
    return map == null ? null : Map<String, dynamic>.from(map as Map);
  }

  Future<String?> firstRootFolderPath() async {
    final response = await _client.get(_uri('rootfolder'), headers: _headers);
    if (response.statusCode != 200) return null;
    final list = jsonDecode(response.body) as List<dynamic>;
    final folder = list.firstWhereOrNull((f) => f['accessible'] == true) ?? (list.isEmpty ? null : list.first);
    return folder?['path'] as String?;
  }

  Future<int?> firstQualityProfileId() async {
    final response = await _client.get(_uri('qualityprofile'), headers: _headers);
    if (response.statusCode != 200) return null;
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.isEmpty ? null : list.first['id'] as int?;
  }

  Future<int?> addMovie(int tmdbId) async {
    final lookup = await lookupByTmdb(tmdbId);
    if (lookup == null) return null;
    final rootFolderPath = await firstRootFolderPath();
    final qualityProfileId = await firstQualityProfileId();
    if (rootFolderPath == null || qualityProfileId == null) return null;
    if (_client is ManagedArrClient) lookup.removeWhere((key, _) => key != 'tmdbId');
    lookup['rootFolderPath'] = rootFolderPath;
    lookup['qualityProfileId'] = qualityProfileId;
    lookup['monitored'] = true;
    lookup['addOptions'] = {'searchForMovie': true};
    final response = await _client.post(_uri('movie'), headers: _headers, body: jsonEncode(lookup));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as int?;
  }

  /// Requests a movie: adds it (with a search) if missing, else triggers a
  /// search for the existing entry.
  Future<RadarrRequestResult> requestMovie(int tmdbId) async {
    try {
      final existing = await findMovieIdByTmdb(tmdbId);
      if (existing != null) {
        final response = await _client.post(
          _uri('command'),
          headers: _headers,
          body: jsonEncode({
            'name': 'MoviesSearch',
            'movieIds': [existing],
          }),
        );
        return (response.statusCode >= 200 && response.statusCode < 300)
            ? RadarrRequestResult.success
            : RadarrRequestResult.failed;
      }
      final added = await addMovie(tmdbId);
      return added == null ? RadarrRequestResult.notFound : RadarrRequestResult.success;
    } catch (_) {
      return RadarrRequestResult.failed;
    }
  }
}

class RadarrSettings {
  final String baseUrl;
  final String apiKey;
  final bool enabled;

  /// True when these values come from the Driftfin server plugin. Transient —
  /// never persisted — so local config survives plugin removal. While managed,
  /// the in-app fields are read-only.
  final bool managed;
  final bool viaPlugin;

  const RadarrSettings({
    this.baseUrl = '',
    this.apiKey = '',
    this.enabled = false,
    this.managed = false,
    this.viaPlugin = false,
  });

  bool get isConfigured => enabled && (viaPlugin || baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty);

  RadarrSettings copyWith({String? baseUrl, String? apiKey, bool? enabled, bool? managed}) => RadarrSettings(
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    enabled: enabled ?? this.enabled,
    managed: managed ?? this.managed,
    viaPlugin: viaPlugin,
  );

  Map<String, dynamic> toJson() => {'baseUrl': baseUrl, 'apiKey': apiKey, 'enabled': enabled};

  factory RadarrSettings.fromJson(Map<String, dynamic> json) => RadarrSettings(
    baseUrl: json['baseUrl'] as String? ?? '',
    apiKey: json['apiKey'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? false,
  );
}

const String _radarrSettingsKey = 'radarrSettings';

final radarrProvider = StateNotifierProvider<RadarrNotifier, RadarrSettings>((ref) {
  return RadarrNotifier(ref);
});

class RadarrNotifier extends StateNotifier<RadarrSettings> {
  RadarrNotifier(this.ref) : super(_initialState(ref)) {
    _client = http.Client();
    ref.listen(serverIntegrationConfigProvider, (_, _) => state = _initialState(ref));
    ref.listen(managedIntegrationsProvider, (_, _) => state = _initialState(ref));
  }

  final Ref ref;
  late final http.Client _client;

  static RadarrSettings _initialState(Ref ref) {
    if (ref.read(managedIntegrationsProvider)) {
      final capabilities = ref.read(serverIntegrationConfigProvider)?.capabilities;
      return RadarrSettings(
        managed: true,
        viaPlugin: true,
        enabled:
            capabilities?.feature('arrManagement').allowed == true &&
            capabilities?.integration('radarr').configured == true,
      );
    }
    final server = ref.read(serverIntegrationConfigProvider)?.radarr;
    if (server != null && server.isManaged) {
      return RadarrSettings(
        baseUrl: normalizeRadarrUrl(server.url),
        apiKey: server.apiKey.trim(),
        enabled: true,
        managed: true,
      );
    }
    return _load(ref);
  }

  static RadarrSettings _load(Ref ref) {
    try {
      final raw = ref.read(sharedPreferencesProvider).getString(_radarrSettingsKey);
      if (raw == null || raw.isEmpty) return const RadarrSettings();
      return RadarrSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const RadarrSettings();
    }
  }

  void _persist() => ref.read(sharedPreferencesProvider).setString(_radarrSettingsKey, jsonEncode(state.toJson()));

  void setEnabled(bool value) {
    if (state.managed) return;
    state = state.copyWith(enabled: value);
    _persist();
  }

  void setBaseUrl(String value) {
    if (state.managed) return;
    state = state.copyWith(baseUrl: normalizeRadarrUrl(value));
    _persist();
  }

  void setApiKey(String value) {
    if (state.managed) return;
    state = state.copyWith(apiKey: value.trim());
    _persist();
  }

  RadarrApi get _api {
    final client = state.viaPlugin ? ManagedArrClient(ref, 'radarr', _client) : null;
    return RadarrApi(baseUrl: client?.baseUrl ?? state.baseUrl, apiKey: state.apiKey, client: client ?? _client);
  }

  Future<List<RadarrCalendarItem>> calendar({required DateTime start, required DateTime end}) async {
    if (!state.isConfigured) return const [];
    return _api.calendar(start: start, end: end);
  }

  Future<RadarrRequestResult> requestMovie(int tmdbId) async {
    if (!state.isConfigured) return RadarrRequestResult.notConfigured;
    return _api.requestMovie(tmdbId);
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
