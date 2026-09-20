import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:driftfin/providers/seerr_api_provider.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/seerr/seerr_models.dart';

part 'seerr_user_provider.g.dart';

@riverpod
class SeerrUser extends _$SeerrUser {
  int _generation = 0;
  @override
  SeerrUserModel? build() {
    ref.watch(userProvider.select((user) => (user?.id, user?.credentials, user?.seerrCredentials)));
    ref.watch(serverIntegrationConfigProvider);
    ref.watch(serverIntegrationConnectionProvider);
    refreshUser();
    return null;
  }

  Future<SeerrUserModel?> refreshUser() async {
    // Callers await this result without necessarily listening to the provider.
    final keepAlive = ref.keepAlive();
    final generation = ++_generation;
    final account = ref.read(userProvider);
    try {
      final api = ref.read(seerrApiProvider);
      final response = await api.me().timeout(const Duration(seconds: 20));
      if (!ref.mounted || generation != _generation) return null;
      final current = ref.read(userProvider);
      if (account?.id != current?.id ||
          account?.credentials != current?.credentials ||
          account?.seerrCredentials != current?.seerrCredentials) {
        return null;
      }
      if (response.isSuccessful && response.body != null) {
        state = response.body;
        return response.body;
      }
    } catch (error) {
      log('Unable to refresh Seerr user (${error.runtimeType})', name: 'SeerrUser');
    } finally {
      keepAlive.close();
    }
    return null;
  }

  void clearUser() {
    ++_generation;
    state = null;
  }
}
