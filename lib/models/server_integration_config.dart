import 'package:driftfin/models/plugin_capabilities.dart';

/// Server-wide integration config served by the optional **Driftfin Jellyfin
/// plugin** (`GET /Driftfin/Config`). When the plugin is installed an admin
/// configures Seerr/Sonarr/Radarr/Trakt once on the server; clients fetch it
/// here and treat any configured integration as *server-managed* (the matching
/// local fields become read-only). When the plugin is absent this is simply
/// never populated and the app falls back to its per-device local settings.
///
/// Plain hand-written model (no codegen) to match the [SonarrSettings] /
/// [RadarrSettings] / [TraktSettings] style and avoid build_runner output.
class ServerIntegrationConfig {
  /// Server-wide local (LAN) URL for reaching this Jellyfin server. Configured
  /// once by an admin in the plugin; every client on the server adopts it. Empty
  /// when unset, in which case the client keeps its own per-device local URL.
  final String localUrl;
  final SeerrServerConfig seerr;
  final ArrServerConfig sonarr;
  final ArrServerConfig radarr;
  final TraktServerConfig trakt;
  final PluginCapabilities? capabilities;
  final bool managedProtocol;

  const ServerIntegrationConfig({
    this.localUrl = '',
    this.seerr = const SeerrServerConfig(),
    this.sonarr = const ArrServerConfig(),
    this.radarr = const ArrServerConfig(),
    this.trakt = const TraktServerConfig(),
    this.capabilities,
    this.managedProtocol = false,
  });

  /// No upstream credentials or URLs are accepted from the managed protocol.
  factory ServerIntegrationConfig.managed(PluginCapabilities? capabilities) => ServerIntegrationConfig(
    managedProtocol: true,
    localUrl: capabilities?.compatible == true ? capabilities!.localUrl : '',
    capabilities: capabilities,
    seerr: SeerrServerConfig(viaPlugin: true, enabled: capabilities?.integration('seerr').configured ?? false),
    sonarr: ArrServerConfig(viaPlugin: true, enabled: capabilities?.integration('sonarr').configured ?? false),
    radarr: ArrServerConfig(viaPlugin: true, enabled: capabilities?.integration('radarr').configured ?? false),
  );

  bool get anyManaged => seerr.isManaged || sonarr.isManaged || radarr.isManaged || trakt.isManaged;

  factory ServerIntegrationConfig.fromJson(Map<String, dynamic> json) => ServerIntegrationConfig(
    localUrl: json['localUrl'] as String? ?? '',
    seerr: SeerrServerConfig.fromJson(_obj(json['seerr'])),
    sonarr: ArrServerConfig.fromJson(_obj(json['sonarr'])),
    radarr: ArrServerConfig.fromJson(_obj(json['radarr'])),
    trakt: TraktServerConfig.fromJson(_obj(json['trakt'])),
  );

  Map<String, dynamic> toJson() => {
    'localUrl': localUrl,
    'seerr': seerr.toJson(),
    'sonarr': sonarr.toJson(),
    'radarr': radarr.toJson(),
    'trakt': trakt.toJson(),
  };

  static Map<String, dynamic> _obj(dynamic value) => value is Map<String, dynamic> ? value : const {};
}

/// Jellyseerr/Overseerr server config (URL + admin API key).
class SeerrServerConfig {
  final bool enabled;
  final String url;
  final String apiKey;
  final bool viaPlugin;

  const SeerrServerConfig({this.enabled = false, this.url = '', this.apiKey = '', this.viaPlugin = false});

  /// Server-managed only when enabled and both URL + key are present.
  bool get isManaged => viaPlugin || enabled && url.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  factory SeerrServerConfig.fromJson(Map<String, dynamic> json) => SeerrServerConfig(
    enabled: json['enabled'] as bool? ?? false,
    url: json['url'] as String? ?? '',
    apiKey: json['apiKey'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'enabled': enabled, 'url': url, 'apiKey': apiKey};
}

/// Shared shape for Sonarr/Radarr (base URL + API key).
class ArrServerConfig {
  final bool enabled;
  final String url;
  final String apiKey;
  final bool viaPlugin;

  const ArrServerConfig({this.enabled = false, this.url = '', this.apiKey = '', this.viaPlugin = false});

  bool get isManaged => viaPlugin || enabled && url.trim().isNotEmpty && apiKey.trim().isNotEmpty;

  factory ArrServerConfig.fromJson(Map<String, dynamic> json) => ArrServerConfig(
    enabled: json['enabled'] as bool? ?? false,
    url: json['url'] as String? ?? '',
    apiKey: json['apiKey'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'enabled': enabled, 'url': url, 'apiKey': apiKey};
}

/// Trakt application credentials (client id + secret). Per-user OAuth tokens
/// are never centralized — the user still authorizes the device flow locally.
class TraktServerConfig {
  final bool enabled;
  final String clientId;
  final String clientSecret;

  const TraktServerConfig({this.enabled = false, this.clientId = '', this.clientSecret = ''});

  bool get isManaged => enabled && clientId.trim().isNotEmpty && clientSecret.trim().isNotEmpty;

  factory TraktServerConfig.fromJson(Map<String, dynamic> json) => TraktServerConfig(
    enabled: json['enabled'] as bool? ?? false,
    clientId: json['clientId'] as String? ?? '',
    clientSecret: json['clientSecret'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'enabled': enabled, 'clientId': clientId, 'clientSecret': clientSecret};
}
