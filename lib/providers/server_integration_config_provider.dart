import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;

import 'package:driftfin/models/server_integration_config.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/user_provider.dart';

/// Fetches the Driftfin plugin config from [url]. The endpoint is provided only
/// by the Driftfin plugin, so a 404/empty/non-JSON/timeout/exception simply
/// means the plugin isn't installed — returns null and the app keeps working
/// off local settings. Never throws. [client] is injectable for testing.
Future<ServerIntegrationConfig?> fetchServerIntegrationConfig(
  String url,
  Map<String, String> headers,
  http.Client client,
) async {
  final result = await fetchServerIntegrationConfigDiagnostic(url, headers, client);
  if (result.status != ServerIntegrationConfigStatus.ok) {
    log('Driftfin plugin config unavailable (using local settings): ${result.status}');
  }
  return result.config;
}

/// Why a [fetchServerIntegrationConfig]/[fetchServerIntegrationConfigDiagnostic]
/// call ended up with no config — surfaced by the manual "Refresh" action in
/// Settings > Integrations so a failure is visible instead of only ever
/// silently logged.
enum ServerIntegrationConfigStatus { ok, notLoggedIn, noPlugin, httpError, invalidResponse, requestFailed }

/// Same fetch as [fetchServerIntegrationConfig], but reports *why* there's no
/// config instead of collapsing every failure mode into `null`.
Future<({ServerIntegrationConfig? config, ServerIntegrationConfigStatus status, String? detail})>
fetchServerIntegrationConfigDiagnostic(String url, Map<String, String> headers, http.Client client) async {
  try {
    final response = await client.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 8));
    if (response.statusCode == 404) {
      return (config: null, status: ServerIntegrationConfigStatus.noPlugin, detail: null);
    }
    if (response.statusCode != 200 || response.body.isEmpty) {
      return (config: null, status: ServerIntegrationConfigStatus.httpError, detail: response.statusCode.toString());
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return (config: null, status: ServerIntegrationConfigStatus.invalidResponse, detail: null);
    }
    return (config: ServerIntegrationConfig.fromJson(decoded), status: ServerIntegrationConfigStatus.ok, detail: null);
  } catch (e) {
    return (config: null, status: ServerIntegrationConfigStatus.requestFailed, detail: e.toString());
  }
}

/// Holds the server-wide integration config served by the optional Driftfin
/// Jellyfin plugin. `null` means "no plugin / not loaded" — the app then uses
/// its local per-device settings exactly as before. This is refreshed on login
/// (see [User.updateInformation]) and cleared on logout.
final serverIntegrationConfigProvider =
    StateNotifierProvider<ServerIntegrationConfigNotifier, ServerIntegrationConfig?>(
      (ref) => ServerIntegrationConfigNotifier(ref),
    );

class ServerIntegrationConfigNotifier extends StateNotifier<ServerIntegrationConfig?> {
  ServerIntegrationConfigNotifier(this.ref, {http.Client? client}) : _client = client ?? http.Client(), super(null);

  final Ref ref;
  final http.Client _client;

  /// Fetches `GET {server}/Driftfin/Config` and stores the result (or null when
  /// the plugin is absent / unreachable).
  Future<void> load() async {
    final url = buildServerUrl(ref, pathSegments: ['Driftfin', 'Config']);
    final credentials = ref.read(userProvider)?.credentials;
    if (url.isEmpty || credentials == null) {
      state = null;
      return;
    }
    state = await fetchServerIntegrationConfig(url, credentials.header(ref), _client);
  }

  /// Same as [load], but returns *why* there's no config (with an optional
  /// [detail] such as the HTTP status code or error text) instead of only ever
  /// logging it — used by the manual "Refresh" action in Settings >
  /// Integrations so the specific failure is visible to the user.
  Future<({ServerIntegrationConfigStatus status, String? detail})> loadWithDiagnostics() async {
    final url = buildServerUrl(ref, pathSegments: ['Driftfin', 'Config']);
    final credentials = ref.read(userProvider)?.credentials;
    if (url.isEmpty || credentials == null) {
      state = null;
      return (status: ServerIntegrationConfigStatus.notLoggedIn, detail: null);
    }
    final result = await fetchServerIntegrationConfigDiagnostic(url, credentials.header(ref), _client);
    state = result.config;
    return (status: result.status, detail: result.detail);
  }

  void clear() => state = null;
}
