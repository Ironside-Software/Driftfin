import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

import 'package:driftfin/models/syncplay/sync_play_models.dart';

/// Posts a Driftfin SyncPlay relay message (chat/reaction/typing/buffering) to
/// the optional Driftfin plugin's `POST /Driftfin/SyncPlay/{groupId}/Messages`
/// endpoint, which fans it out to every other group member's session via a
/// privileged, non-permission-gated path server-side — the transport gap
/// tracked by issue #4 (chat over a plain per-session `DisplayMessage` only
/// reaches sessions the sender can remote-control).
///
/// [url] must already include the group id, e.g.
/// `{server}/Driftfin/SyncPlay/{groupId}/Messages`. Returns true on success; a
/// 404 (plugin not installed), any other non-2xx status, timeout, or
/// exception returns false so the caller can fall back. Never throws.
/// [client] is injectable for testing, mirroring
/// `fetchServerIntegrationConfig`.
Future<bool> postSyncPlayRelayMessage(
  String url,
  Map<String, String> headers,
  SyncRelayKind kind, {
  String? text,
  String? emoji,
  required http.Client client,
}) async {
  try {
    final response = await client
        .post(
          Uri.parse(url),
          headers: {...headers, 'content-type': 'application/json'},
          body: jsonEncode({'kind': kind.name, 'text': ?text, 'emoji': ?emoji}),
        )
        .timeout(const Duration(seconds: 5));
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (e) {
    log('SyncPlay relay send failed (falling back): $e');
    return false;
  }
}
