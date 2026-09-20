import 'dart:developer';
import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:driftfin/providers/seerr_service_provider.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/models/seerr_credentials_model.dart';
import 'package:driftfin/util/managed_seerr_request.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/seerr/seerr_chopper_service.dart';
import 'package:driftfin/seerr/seerr_json_converter.dart';
import 'package:driftfin/util/driftfin_config.dart';
import 'package:driftfin/util/seerr_http_client.dart'
    if (dart.library.html) 'package:driftfin/util/seerr_http_client_web.dart';

part 'seerr_api_provider.g.dart';

// Callers cache this service. Read credentials per request so account changes
// don't invalidate the Ref held by its interceptors and pending requests.
@Riverpod(keepAlive: true)
class SeerrApi extends _$SeerrApi {
  @override
  SeerrService build() {
    final chopperClient = ChopperClient(
      client: createSeerrHttpClient(),
      converter: const SeerrJsonConverter(),
      interceptors: [
        SeerrRequest(ref),
        SeerrResponse(ref),
        HttpLoggingInterceptor(level: Level.basic),
      ],
    );
    ref.onDispose(chopperClient.dispose);

    return SeerrService(ref, SeerrChopperService.create(chopperClient));
  }
}

class SeerrRequest implements Interceptor {
  SeerrRequest(this.ref);

  final Ref ref;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) async {
    final account = ref.read(userProvider);
    final creds = account?.seerrCredentials;
    if (ref.read(managedIntegrationsProvider)) {
      if (account == null) throw const HttpException('Jellyfin login required');
      final request = managedSeerrRequest(chain.request, buildServerUrl(ref), account.credentials.header(ref));
      final response = await chain.proceed(request);
      if (!ref.mounted ||
          ref.read(userProvider)?.sameIdentity(account) != true ||
          ref.read(userProvider)?.credentials.token != account.credentials.token) {
        throw const HttpException('Account changed during request');
      }
      return response;
    }
    final trusted = creds?.origin == CredentialOrigin.manual;
    final path = chain.request.uri.path;
    final publicOperation =
        (chain.request.method == 'POST' && const ['/api/v1/auth/local', '/api/v1/auth/jellyfin'].contains(path)) ||
        (chain.request.method == 'GET' && path == '/api/v1/status');
    if (!trusted && !publicOperation) {
      throw const HttpException('Reconnect Seerr to confirm saved credentials');
    }
    final serverUrl = (DriftfinConfig.seerrBaseUrl ?? creds?.serverUrl)?.trim();

    if (serverUrl == null || serverUrl.isEmpty) {
      throw const HttpException('Seerr server not configured');
    }

    final apiKey = trusted ? creds?.apiKey.trim() ?? '' : '';
    final cookie = trusted ? creds?.sessionCookie.trim() ?? '' : '';

    final authHeaders = _authHeaders(apiKey: apiKey, cookie: cookie);
    final customHeaders = trusted ? {...?creds?.customHeaders} : <String, String>{};
    final headers = {...authHeaders, ...customHeaders};
    final apiBaseUri = Uri.parse(serverUrl);

    final directRequest = chain.request.copyWith(
      baseUri: apiBaseUri,
      headers: trusted ? chain.request.headers : const {'Content-Type': 'application/json'},
    )..followRedirects = false;
    final requestWithHeaders = applyHeaders(directRequest, headers);

    try {
      final response = await chain.proceed(requestWithHeaders);
      return response;
    } catch (_) {
      throw const HttpException('Seerr request failed');
    }
  }
}

Map<String, String> _authHeaders({required String apiKey, required String cookie}) {
  if (apiKey.isNotEmpty) return {'X-Api-Key': apiKey};
  if (cookie.isNotEmpty && cookie != kBrowserManagedCookie) return {'Cookie': cookie};
  if (cookie == kBrowserManagedCookie) return const {};
  return const {};
}

class SeerrResponse implements Interceptor {
  SeerrResponse(this.ref);

  final Ref ref;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) async {
    final Response<BodyType> response = await chain.proceed(chain.request);

    if (!response.isSuccessful) {
      final status = response.base.statusCode;
      log('Seerr request returned HTTP $status', name: 'Seerr');
    }

    return response;
  }
}
