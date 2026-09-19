import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;

import 'package:driftfin/models/server_integration_config.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';

/// Outcome of a direct-Sonarr episode request.
enum SonarrRequestResult { success, notConfigured, seriesNotFound, episodeNotFound, failed }

/// Normalizes a user-entered Sonarr base URL: trims whitespace and strips any
/// trailing slashes so '/api/v3/...' joins cleanly.
String normalizeSonarrUrl(String value) => value.trim().replaceFirst(RegExp(r'/+$'), '');

/// One episode from the Sonarr calendar.
class SonarrCalendarItem {
  final String seriesTitle;
  final int? seriesTvdbId;
  final int seasonNumber;
  final int episodeNumber;
  final String episodeTitle;
  final DateTime? airDateUtc;
  final bool hasFile;

  const SonarrCalendarItem({
    required this.seriesTitle,
    required this.seriesTvdbId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.airDateUtc,
    required this.hasFile,
  });

  factory SonarrCalendarItem.fromJson(Map<String, dynamic> json) {
    final series = json['series'] as Map<String, dynamic>?;
    final rawAir = json['airDateUtc'] as String?;
    return SonarrCalendarItem(
      seriesTitle: series?['title'] as String? ?? '',
      seriesTvdbId: (series?['tvdbId'] as num?)?.toInt(),
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
      episodeTitle: json['title'] as String? ?? '',
      airDateUtc: rawAir == null ? null : DateTime.tryParse(rawAir),
      hasFile: json['hasFile'] as bool? ?? false,
    );
  }
}

/// Thin, dependency-free client for Sonarr's v3 API. Injectable [http.Client]
/// makes it unit-testable. Only the calls needed to monitor + search a single
/// episode are implemented.
class SonarrApi {
  SonarrApi({required this.baseUrl, required this.apiKey, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl/api/v3/$path').replace(queryParameters: query);

  Map<String, String> get _headers => {'X-Api-Key': apiKey, 'Content-Type': 'application/json'};

  Future<int?> findSeriesIdByTvdb(int tvdbId) async {
    final response = await _client.get(_uri('series'), headers: _headers);
    if (response.statusCode != 200) return null;
    final list = jsonDecode(response.body) as List<dynamic>;
    final match = list.firstWhereOrNull((series) => series['tvdbId'] == tvdbId);
    return match?['id'] as int?;
  }

  Future<int?> findEpisodeId(int seriesId, int season, int episode) async {
    final response = await _client.get(_uri('episode', {'seriesId': '$seriesId'}), headers: _headers);
    if (response.statusCode != 200) return null;
    final list = jsonDecode(response.body) as List<dynamic>;
    final match = list.firstWhereOrNull(
      (entry) => entry['seasonNumber'] == season && entry['episodeNumber'] == episode,
    );
    return match?['id'] as int?;
  }

  Future<bool> monitorEpisodes(List<int> episodeIds) async {
    final response = await _client.put(
      _uri('episode/monitor'),
      headers: _headers,
      body: jsonEncode({'episodeIds': episodeIds, 'monitored': true}),
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// Fetches the Sonarr calendar (aired/upcoming episodes) within a date range.
  Future<List<SonarrCalendarItem>> calendar({required DateTime start, required DateTime end}) async {
    final response = await _client.get(
      _uri('calendar', {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'includeSeries': 'true',
        'unmonitored': 'true',
      }),
      headers: _headers,
    );
    if (response.statusCode != 200) return const [];
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((entry) => SonarrCalendarItem.fromJson(entry as Map<String, dynamic>))
        .where((item) => item.airDateUtc != null)
        .toList();
  }

  Future<bool> searchEpisodes(List<int> episodeIds) async {
    final response = await _client.post(
      _uri('command'),
      headers: _headers,
      body: jsonEncode({'name': 'EpisodeSearch', 'episodeIds': episodeIds}),
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// Looks up a show by TVDB id (Sonarr's add payload).
  Future<Map<String, dynamic>?> lookupByTvdb(int tvdbId) async {
    final response = await _client.get(_uri('series/lookup', {'term': 'tvdb:$tvdbId'}), headers: _headers);
    if (response.statusCode != 200) return null;
    final list = jsonDecode(response.body) as List<dynamic>;
    final match = list.firstWhereOrNull((s) => s['tvdbId'] == tvdbId) ?? (list.isEmpty ? null : list.first);
    return match == null ? null : Map<String, dynamic>.from(match as Map);
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

  /// Adds the show to Sonarr (unmonitored, no full-series search) so a single
  /// episode can then be monitored + grabbed. Returns the new series id.
  Future<int?> addSeries(int tvdbId) async {
    final lookup = await lookupByTvdb(tvdbId);
    if (lookup == null) return null;
    final rootFolderPath = await firstRootFolderPath();
    final qualityProfileId = await firstQualityProfileId();
    if (rootFolderPath == null || qualityProfileId == null) return null;

    lookup['rootFolderPath'] = rootFolderPath;
    lookup['qualityProfileId'] = qualityProfileId;
    lookup['monitored'] = true;
    lookup['seasonFolder'] = true;
    lookup['addOptions'] = {
      'monitor': 'none',
      'searchForMissingEpisodes': false,
      'searchForCutoffUnmetEpisodes': false,
    };

    final response = await _client.post(_uri('series'), headers: _headers, body: jsonEncode(lookup));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as int?;
  }

  /// Finds the show by TVDB id (adding it to Sonarr first when [addIfMissing]),
  /// then monitors + searches the single episode.
  Future<SonarrRequestResult> requestEpisodeByTvdb({
    required int tvdbId,
    required int season,
    required int episode,
    bool addIfMissing = false,
  }) async {
    try {
      var seriesId = await findSeriesIdByTvdb(tvdbId);
      var justAdded = false;
      if (seriesId == null) {
        if (!addIfMissing) return SonarrRequestResult.seriesNotFound;
        seriesId = await addSeries(tvdbId);
        if (seriesId == null) return SonarrRequestResult.seriesNotFound;
        justAdded = true;
      }

      var episodeId = await findEpisodeId(seriesId, season, episode);
      // A freshly-added series populates its episodes a moment after the add,
      // so retry briefly before giving up.
      if (episodeId == null && justAdded) {
        for (var attempt = 0; attempt < 6 && episodeId == null; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 800));
          episodeId = await findEpisodeId(seriesId, season, episode);
        }
      }
      if (episodeId == null) return SonarrRequestResult.episodeNotFound;

      await monitorEpisodes([episodeId]);
      final searched = await searchEpisodes([episodeId]);
      return searched ? SonarrRequestResult.success : SonarrRequestResult.failed;
    } catch (_) {
      return SonarrRequestResult.failed;
    }
  }
}

/// Direct Sonarr integration so a single episode can be monitored + searched —
/// something Jellyseerr/Overseerr can't do (its requests are season-level).
/// Only works for shows already added to Sonarr; standard season/episode
/// numbering (anime absolute numbering is not handled).
class SonarrSettings {
  final String baseUrl;
  final String apiKey;
  final bool enabled;

  /// True when these values come from the Driftfin server plugin. Transient —
  /// never persisted — so the user's local config survives plugin removal.
  /// While managed, the in-app fields are read-only.
  final bool managed;

  const SonarrSettings({this.baseUrl = '', this.apiKey = '', this.enabled = false, this.managed = false});

  bool get isConfigured => enabled && baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  SonarrSettings copyWith({String? baseUrl, String? apiKey, bool? enabled, bool? managed}) => SonarrSettings(
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    enabled: enabled ?? this.enabled,
    managed: managed ?? this.managed,
  );

  Map<String, dynamic> toJson() => {'baseUrl': baseUrl, 'apiKey': apiKey, 'enabled': enabled};

  factory SonarrSettings.fromJson(Map<String, dynamic> json) => SonarrSettings(
    baseUrl: json['baseUrl'] as String? ?? '',
    apiKey: json['apiKey'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? false,
  );
}

const String _sonarrSettingsKey = 'sonarrSettings';

final sonarrProvider = StateNotifierProvider<SonarrNotifier, SonarrSettings>((ref) {
  return SonarrNotifier(ref);
});

class SonarrNotifier extends StateNotifier<SonarrSettings> {
  SonarrNotifier(this.ref) : super(_initialState(ref)) {
    _client = http.Client();
    // Re-apply whenever the server plugin config loads/changes (or is cleared).
    ref.listen<ServerIntegrationConfig?>(serverIntegrationConfigProvider, (_, next) => _applyServer(next?.sonarr));
  }

  final Ref ref;
  late final http.Client _client;

  static SonarrSettings _initialState(Ref ref) {
    final server = ref.read(serverIntegrationConfigProvider)?.sonarr;
    if (server != null && server.isManaged) {
      return SonarrSettings(
        baseUrl: normalizeSonarrUrl(server.url),
        apiKey: server.apiKey.trim(),
        enabled: true,
        managed: true,
      );
    }
    return _load(ref);
  }

  static SonarrSettings _load(Ref ref) {
    try {
      final raw = ref.read(sharedPreferencesProvider).getString(_sonarrSettingsKey);
      if (raw == null || raw.isEmpty) return const SonarrSettings();
      return SonarrSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const SonarrSettings();
    }
  }

  /// Overlays server-managed values, or reverts to local prefs when the plugin
  /// no longer manages Sonarr.
  void _applyServer(ArrServerConfig? server) {
    if (server != null && server.isManaged) {
      state = SonarrSettings(
        baseUrl: normalizeSonarrUrl(server.url),
        apiKey: server.apiKey.trim(),
        enabled: true,
        managed: true,
      );
    } else if (state.managed) {
      state = _load(ref);
    }
  }

  void _persist() => ref.read(sharedPreferencesProvider).setString(_sonarrSettingsKey, jsonEncode(state.toJson()));

  void setEnabled(bool value) {
    if (state.managed) return;
    state = state.copyWith(enabled: value);
    _persist();
  }

  void setBaseUrl(String value) {
    if (state.managed) return;
    state = state.copyWith(baseUrl: normalizeSonarrUrl(value));
    _persist();
  }

  void setApiKey(String value) {
    if (state.managed) return;
    state = state.copyWith(apiKey: value.trim());
    _persist();
  }

  /// Fetches the Sonarr calendar for [start]..[end]; empty if not configured.
  Future<List<SonarrCalendarItem>> calendar({required DateTime start, required DateTime end}) async {
    if (!state.isConfigured) return const [];
    return SonarrApi(baseUrl: state.baseUrl, apiKey: state.apiKey, client: _client).calendar(start: start, end: end);
  }

  /// Requests a single episode of a show by its TVDB id (from Seerr discovery),
  /// adding the series to Sonarr first if it isn't there yet.
  Future<SonarrRequestResult> requestEpisodeByTvdb({
    required int tvdbId,
    required int season,
    required int episode,
  }) async {
    if (!state.isConfigured) return SonarrRequestResult.notConfigured;
    return SonarrApi(
      baseUrl: state.baseUrl,
      apiKey: state.apiKey,
      client: _client,
    ).requestEpisodeByTvdb(tvdbId: tvdbId, season: season, episode: episode, addIfMissing: true);
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
