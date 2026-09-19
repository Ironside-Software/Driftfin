import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/user_provider.dart';

/// Whether launching an external player is possible on this platform (desktop
/// only).
bool get externalPlayerSupported => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// Builds the argument list for the external player by substituting placeholders
/// in [template]. Supported placeholders: {url}, {position} (resume seconds).
/// Whitespace-separated; empty tokens are dropped.
List<String> buildExternalPlayerArgs(String template, {required String url, required int positionSeconds}) {
  final effective = template.trim().isEmpty ? '{url}' : template.trim();
  return effective
      .split(RegExp(r'\s+'))
      .map((token) => token.replaceAll('{url}', url).replaceAll('{position}', '$positionSeconds'))
      .where((token) => token.isNotEmpty)
      .toList();
}

/// Lets the user play media in their own desktop player (MPV / VLC / PotPlayer /
/// …) instead of the built-in one. Device-local; never synced. Launch is
/// fire-and-forget: the external player does not report progress back to
/// Jellyfin, so resume-out / watched-state / scrobbling won't track it.
class ExternalPlayerSettings {
  final bool enabled;
  final String path;
  final String argsTemplate;

  const ExternalPlayerSettings({this.enabled = false, this.path = '', this.argsTemplate = '{url}'});

  bool get isConfigured => enabled && path.trim().isNotEmpty;

  ExternalPlayerSettings copyWith({bool? enabled, String? path, String? argsTemplate}) => ExternalPlayerSettings(
    enabled: enabled ?? this.enabled,
    path: path ?? this.path,
    argsTemplate: argsTemplate ?? this.argsTemplate,
  );

  Map<String, dynamic> toJson() => {'enabled': enabled, 'path': path, 'argsTemplate': argsTemplate};

  factory ExternalPlayerSettings.fromJson(Map<String, dynamic> json) => ExternalPlayerSettings(
    enabled: json['enabled'] as bool? ?? false,
    path: json['path'] as String? ?? '',
    argsTemplate: json['argsTemplate'] as String? ?? '{url}',
  );
}

const String _externalPlayerKey = 'externalPlayerSettings';

final externalPlayerProvider = StateNotifierProvider<ExternalPlayerNotifier, ExternalPlayerSettings>((ref) {
  return ExternalPlayerNotifier(ref);
});

class ExternalPlayerNotifier extends StateNotifier<ExternalPlayerSettings> {
  ExternalPlayerNotifier(this.ref) : super(_load(ref));

  final Ref ref;

  static ExternalPlayerSettings _load(Ref ref) {
    try {
      final raw = ref.read(sharedPreferencesProvider).getString(_externalPlayerKey);
      if (raw == null || raw.isEmpty) return const ExternalPlayerSettings();
      return ExternalPlayerSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ExternalPlayerSettings();
    }
  }

  void _persist() => ref.read(sharedPreferencesProvider).setString(_externalPlayerKey, jsonEncode(state.toJson()));

  void setEnabled(bool value) {
    state = state.copyWith(enabled: value);
    _persist();
  }

  void setPath(String value) {
    state = state.copyWith(path: value.trim());
    _persist();
  }

  void setArgsTemplate(String value) {
    state = state.copyWith(argsTemplate: value);
    _persist();
  }

  /// Launches the item's stream in the configured external player, seeking to
  /// the saved resume position if the template uses {position}. Returns false if
  /// unsupported/unconfigured or the launch fails.
  Future<bool> launch(ItemBaseModel item) async {
    if (!externalPlayerSupported || !state.isConfigured) return false;
    final url = ref.read(userProvider.notifier).createDownloadUrl(item);
    if (url == null || url.isEmpty) return false;
    final args = buildExternalPlayerArgs(
      state.argsTemplate,
      url: url,
      positionSeconds: item.userData.playBackPosition.inSeconds,
    );
    try {
      await Process.start(state.path, args, mode: ProcessStartMode.detached);
      return true;
    } catch (_) {
      return false;
    }
  }
}
