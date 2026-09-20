import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;

import 'package:driftfin/models/server_integration_config.dart';
import 'package:driftfin/models/plugin_capabilities.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/seerr_credentials_model.dart';
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
enum ServerIntegrationConfigStatus {
  ok,
  legacy,
  loading,
  notLoggedIn,
  noPlugin,
  expiredLogin,
  forbidden,
  incompatible,
  httpError,
  invalidResponse,
  requestFailed,
}

/// Same fetch as [fetchServerIntegrationConfig], but reports *why* there's no
/// config instead of collapsing every failure mode into `null`.
Future<({ServerIntegrationConfig? config, ServerIntegrationConfigStatus status, String? detail})>
fetchServerIntegrationConfigDiagnostic(String url, Map<String, String> headers, http.Client client) async {
  try {
    final response = await client.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 8));
    if (response.statusCode == 426) {
      return (
        config: ServerIntegrationConfig.managed(null),
        status: ServerIntegrationConfigStatus.incompatible,
        detail: 'upgrade_required',
      );
    }
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
    return (config: null, status: ServerIntegrationConfigStatus.requestFailed, detail: e.runtimeType.toString());
  }
}

/// Read-only capability negotiation. A missing route is the only condition that
/// permits trying the old plugin contract on an account that has never migrated.
Future<({ServerIntegrationConfig? config, ServerIntegrationConfigStatus status, String? detail})>
fetchPluginCapabilities(String url, Map<String, String> headers, http.Client client) async {
  try {
    final response = await client.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 20));
    final status = switch (response.statusCode) {
      200 => ServerIntegrationConfigStatus.ok,
      404 => ServerIntegrationConfigStatus.noPlugin,
      401 => ServerIntegrationConfigStatus.expiredLogin,
      403 => ServerIntegrationConfigStatus.forbidden,
      _ => ServerIntegrationConfigStatus.httpError,
    };
    if (status != ServerIntegrationConfigStatus.ok) {
      return (config: null, status: status, detail: response.statusCode.toString());
    }
    if (response.bodyBytes.length > 262144) throw const FormatException('Oversized capabilities');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Invalid capabilities');
    final capabilities = PluginCapabilities.fromJson(decoded);
    return (
      config: ServerIntegrationConfig.managed(capabilities),
      status: capabilities.compatible ? ServerIntegrationConfigStatus.ok : ServerIntegrationConfigStatus.incompatible,
      detail: null,
    );
  } on FormatException {
    return (config: null, status: ServerIntegrationConfigStatus.invalidResponse, detail: null);
  } on TypeError {
    return (config: null, status: ServerIntegrationConfigStatus.invalidResponse, detail: null);
  } catch (_) {
    return (config: null, status: ServerIntegrationConfigStatus.requestFailed, detail: null);
  }
}

final serverIntegrationConnectionProvider = StateProvider<ServerIntegrationConfigStatus>(
  (ref) => ServerIntegrationConfigStatus.notLoggedIn,
);

final serverIntegrationConfigProvider =
    StateNotifierProvider<ServerIntegrationConfigNotifier, ServerIntegrationConfig?>(
      (ref) => ServerIntegrationConfigNotifier(ref),
    );

final managedIntegrationsProvider = Provider<bool>((ref) {
  final account = ref.watch(userProvider);
  final config = ref.watch(serverIntegrationConfigProvider);
  return account?.manualIntegrations != true &&
      (account?.managedIntegrations == true || config?.managedProtocol == true);
});

final seerrAvailableProvider = Provider<bool>((ref) {
  if (ref.watch(managedIntegrationsProvider)) {
    return ref.watch(serverIntegrationConfigProvider)?.capabilities?.feature('discovery').allowed == true;
  }
  return ref.watch(
    userProvider.select(
      (user) => user?.seerrCredentials?.origin == CredentialOrigin.manual && user!.seerrCredentials!.isConfigured,
    ),
  );
});

class ServerIntegrationConfigNotifier extends StateNotifier<ServerIntegrationConfig?> {
  ServerIntegrationConfigNotifier(this.ref, {http.Client? client})
    : _client = client ?? http.Client(),
      super(ref.read(userProvider)?.usesManagedIntegrations == true ? ServerIntegrationConfig.managed(null) : null) {
    ref.listen(
      userProvider.select(
        (user) => (user?.id, user?.credentials.serverId, user?.credentials.url, user?.credentials.token),
      ),
      (_, next) => clear(),
    );
  }

  final Ref ref;
  final http.Client _client;
  int _generation = 0;
  bool _disposed = false;

  Future<void> load() async => await loadWithDiagnostics();

  Future<({ServerIntegrationConfigStatus status, String? detail})> loadWithDiagnostics() async {
    final generation = ++_generation;
    final account = ref.read(userProvider);
    final url = buildServerUrl(ref, pathSegments: ['Driftfin', 'v1', 'capabilities']);
    final legacyUrl = buildServerUrl(ref, pathSegments: ['Driftfin', 'Config']);
    if (url.isEmpty || account == null) {
      clear();
      return (status: ServerIntegrationConfigStatus.notLoggedIn, detail: null);
    }
    final managed = account.managedIntegrations || state?.managedProtocol == true;
    ref.read(serverIntegrationConnectionProvider.notifier).state = ServerIntegrationConfigStatus.loading;
    final headers = account.credentials.header(ref);
    var result = await fetchPluginCapabilities(url, headers, _client);
    if (!_isCurrent(account, generation)) return (status: ServerIntegrationConfigStatus.notLoggedIn, detail: null);
    if (result.status == ServerIntegrationConfigStatus.noPlugin && !managed) {
      result = await fetchServerIntegrationConfigDiagnostic(legacyUrl, headers, _client);
      if (result.status == ServerIntegrationConfigStatus.ok) {
        result = (config: result.config, status: ServerIntegrationConfigStatus.legacy, detail: null);
      }
    }
    if (!_isCurrent(account, generation)) return (status: ServerIntegrationConfigStatus.notLoggedIn, detail: null);
    state = result.config ?? (account.usesManagedIntegrations ? ServerIntegrationConfig.managed(null) : null);
    ref.read(serverIntegrationConnectionProvider.notifier).state = result.status;
    if (result.config?.managedProtocol == true) {
      final current = ref.read(userProvider)!;
      final credentials = current.seerrCredentials;
      ref.read(userProvider.notifier).userState = current.copyWith(
        managedIntegrations: true,
        manualIntegrations: false,
        seerrCredentials: credentials?.origin == CredentialOrigin.plugin ? null : credentials,
      );
    }
    return (status: result.status, detail: result.detail);
  }

  /// Explicit recovery after removal; keep the migration marker so legacy
  /// credential sharing is never negotiated again, including after restart.
  void useManualIntegrations() {
    final account = ref.read(userProvider);
    if (account?.managedIntegrations != true ||
        ref.read(serverIntegrationConnectionProvider) != ServerIntegrationConfigStatus.noPlugin) {
      return;
    }
    ++_generation;
    state = null;
    ref.read(userProvider.notifier).userState = account!.copyWith(manualIntegrations: true);
  }

  bool _isCurrent(AccountModel account, int generation) {
    if (_disposed || !ref.mounted || generation != _generation) return false;
    final current = ref.read(userProvider);
    return current != null && current.sameIdentity(account) && current.credentials.token == account.credentials.token;
  }

  Future<({bool healthy, String? reason, String? correlationId, DateTime? checkedAt})> check(String service) async {
    if (!const ['seerr', 'sonarr', 'radarr'].contains(service)) {
      throw ArgumentError.value(service);
    }
    final account = ref.read(userProvider);
    final generation = _generation;
    if (account == null || state?.capabilities?.feature('diagnostics').allowed != true) {
      return (healthy: false, reason: 'permission_denied', correlationId: null, checkedAt: null);
    }
    final url = buildServerUrl(ref, pathSegments: ['Driftfin', 'v1', 'integrations', service, 'check']);
    try {
      final response = await _client
          .post(Uri.parse(url), headers: account.credentials.header(ref))
          .timeout(const Duration(seconds: 15));
      if (!_isCurrent(account, generation)) {
        return (healthy: false, reason: 'expired_login', correlationId: null, checkedAt: null);
      }
      if (response.statusCode != 200) {
        return (
          healthy: false,
          reason: response.statusCode == 401
              ? 'expired_login'
              : response.statusCode == 403
              ? 'permission_denied'
              : 'unreachable',
          correlationId: null,
          checkedAt: null,
        );
      }
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      return (
        healthy: result['healthy'] == true,
        reason: result['reason'] as String?,
        correlationId: result['correlationId'] as String?,
        checkedAt: DateTime.tryParse(result['checkedAt'] as String? ?? ''),
      );
    } catch (_) {
      return (healthy: false, reason: 'unreachable', correlationId: null, checkedAt: null);
    }
  }

  void clear() {
    ++_generation;
    state = ref.read(userProvider)?.usesManagedIntegrations == true ? ServerIntegrationConfig.managed(null) : null;
    ref.read(serverIntegrationConnectionProvider.notifier).state = ServerIntegrationConfigStatus.notLoggedIn;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _client.close();
    super.dispose();
  }
}
