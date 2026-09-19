import 'dart:io';

import 'package:chopper/chopper.dart';

/// Preserve query/body serialization while replacing every direct-service header.
Request managedSeerrRequest(Request request, String jellyfinUrl, Map<String, String> headers) {
  final path = request.uri.path;
  if (!path.startsWith('/api/v1/') || path.contains('..')) {
    throw const HttpException('Unsupported managed operation');
  }
  final operation = path.substring('/api/v1/'.length);
  if (const ['auth/local', 'auth/jellyfin', 'auth/logout'].contains(operation)) {
    throw const HttpException('Managed Seerr uses the Jellyfin session');
  }
  final base = Uri.parse(jellyfinUrl);
  final uri = base.replace(path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/Driftfin/v1/seerr/$operation');
  return request.copyWith(uri: uri, baseUri: base, headers: {'Content-Type': 'application/json', ...headers})
    ..followRedirects = false;
}
