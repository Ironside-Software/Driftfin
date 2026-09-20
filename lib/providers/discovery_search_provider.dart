import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:http/http.dart' as http;

import 'package:driftfin/models/discovery_search.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/providers/user_provider.dart';

typedef DiscoveryQuery = ({String query, String language});

final discoverySearchProvider = StateNotifierProvider.autoDispose
    .family<DiscoverySearchNotifier, DiscoverySearchState, DiscoveryQuery>((ref, query) {
      ref.watch(
        userProvider.select(
          (account) =>
              (account?.id, account?.credentials.serverId, account?.credentials.url, account?.credentials.token),
        ),
      );
      ref.watch(serverIntegrationConfigProvider);
      ref.watch(serverIntegrationConnectionProvider);
      return DiscoverySearchNotifier(ref, query);
    });

class DiscoverySearchNotifier extends StateNotifier<DiscoverySearchState> {
  DiscoverySearchNotifier(this.ref, this.query, {http.Client? client})
    : _client = client ?? http.Client(),
      super(const DiscoverySearchState()) {
    _timer = Timer(const Duration(milliseconds: 350), loadMore);
  }
  final Ref ref;
  final DiscoveryQuery query;
  final http.Client _client;
  Timer? _timer;

  Future<void> loadMore() async {
    _timer?.cancel();
    if (!mounted || state.loading || !state.hasMore || query.query.trim().isEmpty) return;
    final config = ref.read(serverIntegrationConfigProvider);
    final feature = config?.capabilities?.feature('discovery');
    if (feature?.allowed != true) {
      final connection = ref.read(serverIntegrationConnectionProvider);
      state = DiscoverySearchState(
        reason:
            feature?.reason ??
            switch (connection) {
              ServerIntegrationConfigStatus.noPlugin => 'no_plugin',
              ServerIntegrationConfigStatus.legacy => 'legacy_plugin',
              ServerIntegrationConfigStatus.expiredLogin => 'expired_login',
              ServerIntegrationConfigStatus.forbidden => 'permission_denied',
              ServerIntegrationConfigStatus.incompatible => 'incompatible_protocol',
              ServerIntegrationConfigStatus.loading || ServerIntegrationConfigStatus.notLoggedIn => 'checking',
              _ => 'unreachable',
            },
      );
      return;
    }
    final account = ref.read(userProvider);
    if (account == null) return;
    final previous = state;
    state = DiscoverySearchState(
      results: previous.results,
      page: previous.page,
      totalPages: previous.totalPages,
      loading: true,
    );
    final url = Uri.parse(buildServerUrl(ref, pathSegments: ['Driftfin', 'v1', 'discovery', 'search'])).replace(
      queryParameters: {'query': query.query.trim(), 'page': '${previous.page + 1}', 'language': query.language},
    );
    String? reason;
    try {
      final request = http.Request('GET', url)
        ..headers.addAll(account.credentials.header(ref))
        ..followRedirects = false;
      final response = await _client.send(request).then(http.Response.fromStream).timeout(const Duration(seconds: 20));
      if (!mounted ||
          !ref.mounted ||
          ref.read(userProvider)?.sameIdentity(account) != true ||
          ref.read(userProvider)?.credentials.token != account.credentials.token) {
        return;
      }
      if (response.statusCode == 200) {
        if (response.bodyBytes.length > 4 * 1024 * 1024) throw const FormatException('Oversized catalog page');
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final page = body['page'] as int;
        final pages = body['totalPages'] as int;
        final results = body['results'] as List;
        if (page != previous.page + 1 || pages < 0 || results.length > 100) {
          throw const FormatException('Invalid pagination');
        }
        final items = results.map((item) => DiscoveryResult.fromJson(item as Map<String, dynamic>)).toList();
        state = DiscoverySearchState(
          results: distinctDiscoveryResults([...previous.results, ...items], []),
          page: page,
          totalPages: pages.clamp(0, 500),
        );
        return;
      }
      reason = switch (response.statusCode) {
        401 => 'expired_login',
        403 => 'permission_denied',
        404 => 'no_plugin',
        _ => 'unreachable',
      };
      // Only known UI reason codes are rendered; never raw upstream text.
      if (response.bodyBytes.length < 4096) {
        final body = jsonDecode(response.body);
        if (body is Map && body['reason'] is String) reason = body['reason'] as String;
      }
    } catch (_) {
      reason ??= 'unreachable';
    }
    if (mounted &&
        ref.mounted &&
        ref.read(userProvider)?.sameIdentity(account) == true &&
        ref.read(userProvider)?.credentials.token == account.credentials.token) {
      state = DiscoverySearchState(
        results: previous.results,
        page: previous.page,
        totalPages: previous.totalPages,
        reason: reason,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.close();
    super.dispose();
  }
}
