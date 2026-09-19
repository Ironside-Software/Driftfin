import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/user_provider.dart';

/// A single arr operation stays bound to the account that started it, including
/// follow-up lookups, monitoring and search calls.
class ManagedArrClient extends http.BaseClient {
  ManagedArrClient(this.ref, this.service, this.client)
    : account = ref.read(userProvider),
      baseUrl = buildServerUrl(ref) {
    if (service != 'sonarr' && service != 'radarr') throw ArgumentError.value(service);
    headers = account?.credentials.header(ref) ?? {};
  }

  final Ref ref;
  final String service;
  final http.Client client;
  final AccountModel? account;
  final String baseUrl;
  late final Map<String, String> headers;

  void _checkAccount() {
    if (!ref.mounted ||
        account == null ||
        ref.read(userProvider)?.sameIdentity(account!) != true ||
        ref.read(userProvider)?.credentials.token != account!.credentials.token) {
      throw const HttpException('Account changed during request');
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _checkAccount();
    final base = Uri.parse(baseUrl);
    final prefix = '${base.path.replaceFirst(RegExp(r'/+$'), '')}/api/v3/';
    if (!request.url.path.startsWith(prefix)) throw const HttpException('Unsupported managed operation');
    final operation = request.url.path.substring(prefix.length);
    final url = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/Driftfin/v1/$service/$operation',
      query: request.url.query,
    );
    final managed = http.Request(request.method, url)
      ..headers.addAll({'Content-Type': 'application/json', ...headers})
      ..followRedirects = false
      ..bodyBytes = await request.finalize().toBytes();
    _checkAccount();
    final response = await client.send(managed).timeout(const Duration(seconds: 30));
    // Buffer inside the guard so a late body cannot reach the next mutation.
    final bytes = await response.stream.toBytes().timeout(const Duration(seconds: 30));
    _checkAccount();
    return http.StreamedResponse(Stream.value(bytes), response.statusCode, headers: response.headers);
  }
}
