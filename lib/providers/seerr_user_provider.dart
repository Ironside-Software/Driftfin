import 'dart:developer';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:driftfin/providers/seerr_api_provider.dart';
import 'package:driftfin/seerr/seerr_models.dart';

part 'seerr_user_provider.g.dart';

@riverpod
class SeerrUser extends _$SeerrUser {
  @override
  SeerrUserModel? build() {
    refreshUser();
    return null;
  }

  Future<SeerrUserModel?> refreshUser() async {
    try {
      final api = ref.read(seerrApiProvider);
      final response = await api.me();
      if (!ref.mounted) return null;
      if (response.isSuccessful && response.body != null) {
        state = response.body;
        return response.body;
      }
    } catch (error) {
      log('Unable to refresh Seerr user (${error.runtimeType})', name: 'SeerrUser');
    }
    return null;
  }

  void clearUser() {
    state = null;
  }
}
