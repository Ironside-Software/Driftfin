/// The non-secret, caller-specific contract returned by /Driftfin/v1/capabilities.
class PluginCapabilities {
  final int protocolVersion;
  final String pluginVersion;
  final Map<String, PluginFeature> features;
  final Map<String, PluginIntegration> integrations;
  final bool traktMigrationRequired;

  const PluginCapabilities({
    required this.protocolVersion,
    this.pluginVersion = '',
    this.features = const {},
    this.integrations = const {},
    this.traktMigrationRequired = false,
  });

  bool get compatible => protocolVersion == 1;
  PluginFeature feature(String name) => compatible ? features[name] ?? const PluginFeature() : const PluginFeature();
  PluginIntegration integration(String name) => integrations[name] ?? const PluginIntegration();

  factory PluginCapabilities.fromJson(Map<String, dynamic> json) {
    if (json['protocolVersion'] is! int || json['features'] is! Map || json['integrations'] is! Map) {
      throw const FormatException('Invalid capabilities');
    }
    return PluginCapabilities(
      protocolVersion: json['protocolVersion'] as int,
      pluginVersion: json['pluginVersion'] as String? ?? '',
      features: {
        for (final entry in (json['features'] as Map<String, dynamic>).entries)
          entry.key: PluginFeature.fromJson(entry.value as Map<String, dynamic>),
      },
      integrations: {
        for (final entry in (json['integrations'] as Map<String, dynamic>).entries)
          entry.key: PluginIntegration.fromJson(entry.value as Map<String, dynamic>),
      },
      traktMigrationRequired: (json['migration'] as Map<String, dynamic>?)?['trakt'] == 'manual_setup_required',
    );
  }
}

class PluginFeature {
  final bool supported;
  final bool allowed;
  final String? reason;

  const PluginFeature({this.supported = false, this.allowed = false, this.reason});

  factory PluginFeature.fromJson(Map<String, dynamic> json) => PluginFeature(
    supported: json['supported'] == true,
    allowed: json['supported'] == true && json['allowed'] == true,
    reason: json['reason'] as String?,
  );
}

class PluginIntegration {
  final bool configured;
  final bool? healthy;
  final String? reason;

  const PluginIntegration({this.configured = false, this.healthy, this.reason});

  factory PluginIntegration.fromJson(Map<String, dynamic> json) => PluginIntegration(
    configured: json['configured'] == true,
    healthy: json['healthy'] as bool?,
    reason: json['reason'] as String?,
  );
}
