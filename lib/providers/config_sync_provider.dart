import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/settings/client_settings_model.dart';
import 'package:driftfin/models/settings/home_settings_model.dart';
import 'package:driftfin/models/settings/settings_entry.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/providers/settings/client_settings_provider.dart';
import 'package:driftfin/providers/settings/home_settings_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/util/custom_color_themes.dart';
import 'package:driftfin/util/debouncer.dart';

/// Single source of truth for the "syncs across your devices" badge (see
/// [SettingsListTile]'s `id` param). Every [SettingId] this set contains
/// corresponds to a field [ConfigSync._buildFrom]/[ConfigSync._apply]
/// actually reads/writes — the two must be kept in lockstep by hand (there's
/// a coverage test in settings_registry_test.dart), because a
/// [UserSettings] field with no matching entry here would sync silently with
/// no badge telling the user it does.
const Set<SettingId> syncedSettingIds = {
  SettingId.homeBanner,
  SettingId.homeBannerInformation,
  SettingId.homeNextUp,
  SettingId.managePinnedCollections,
  SettingId.themeMode,
  SettingId.themeColor,
  SettingId.schemeVariant,
  SettingId.amoledBlack,
  SettingId.deriveColorsFromItem,
  SettingId.backgroundPosters,
  SettingId.blurEffects,
  SettingId.blurredPlaceholders,
  SettingId.posterSize,
  SettingId.displayLanguage,
  SettingId.showAllCollectionTypes,
  SettingId.usePostersForLibraryIcons,
  SettingId.seerrIntegration,
  SettingId.seerrRequestNotifications,
};

/// Wires cross-platform settings sync. Construct once at app start (watched in
/// the root widget). Sync is always on — there is no device-local opt-out. It:
///  - applies the server-stored config to the local providers when it loads
///    on login,
///  - pushes local changes back to the server (debounced).
///
/// Synced config lives in Jellyfin's per-user DisplayPreferences.customPrefs via
/// [UserSettings] (see service_provider get/setCustomConfig). Device-local
/// settings (window size, downloads, shortcuts, biometrics) are never synced.
final configSyncProvider = Provider<ConfigSync>((ref) {
  final sync = ConfigSync(ref);
  sync.init();
  return sync;
});

class ConfigSync {
  ConfigSync(this.ref);
  final Ref ref;

  final Debouncer _debouncer = Debouncer(const Duration(seconds: 2));
  bool _applying = false;

  void init() {
    // Stop the debounced push from firing against a disposed container.
    ref.onDispose(_debouncer.dispose);

    // Server config loaded (login) or changed -> apply locally.
    ref.listen(userProvider.select((account) => account?.userSettings), (previous, next) {
      if (next != null && !_applying) _apply(next);
    });

    // Local changes -> push (debounced).
    ref.listen(clientSettingsProvider, (_, _) => _schedulePush());
    ref.listen(homeSettingsProvider, (_, _) => _schedulePush());
    ref.listen(userProvider.select((account) => account?.seerrCredentials?.serverUrl), (_, _) => _schedulePush());
    ref.listen(userProvider.select((account) => account?.seerrRequestsEnabled), (_, _) => _schedulePush());
  }

  void _schedulePush() {
    if (_applying) return;
    _debouncer.run(_pushNow);
  }

  /// Forces an immediate upload of the current local config, regardless of
  /// whether anything changed. Used by the manual "Sync now".
  Future<void> syncNow() => _pushNow(force: true);

  /// Builds the current local settings as a portable, serializable payload —
  /// the same shape/logic the periodic sync push uses. Used by the manual
  /// "Export settings" feature (issue #50 Phase 5).
  UserSettings buildCurrentSettings() => _buildFrom(ref.read(userProvider)?.userSettings ?? UserSettings());

  /// Applies a settings payload to the local providers — the same logic
  /// incoming sync uses. Used by the manual "Import settings" feature.
  void applySettings(UserSettings settings) => _apply(settings);

  /// When this device last uploaded its config to the server.
  DateTime? get lastSyncedAt {
    final raw = ref.read(userProvider)?.userSettings?.syncedAt;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> _pushNow({bool force = false}) async {
    final account = ref.read(userProvider);
    if (account == null) return;
    final current = account.userSettings ?? UserSettings();
    final built = _buildFrom(current);
    // Nothing actually changed -> skip (also breaks the apply -> push loop).
    if (!force && built == current) return;
    final stamped = built.copyWith(syncedAt: DateTime.now().toIso8601String());
    await ref.read(userProvider.notifier).updateCustomConfig(stamped);
  }

  /// Builds the synced payload from current local state, preserving fields the
  /// sync service does not own (e.g. skip durations). The fields written here
  /// must match [syncedSettingIds] above.
  UserSettings _buildFrom(UserSettings current) {
    final client = ref.read(clientSettingsProvider);
    final home = ref.read(homeSettingsProvider);
    final account = ref.read(userProvider);
    // When Seerr is managed by the Driftfin server plugin, keep the existing
    // synced value rather than overwriting it with the plugin-injected URL.
    final seerrManaged = ref.read(serverIntegrationConfigProvider)?.seerr.isManaged ?? false;
    return current.copyWith(
      seerrServerUrl: seerrManaged ? current.seerrServerUrl : account?.seerrCredentials?.serverUrl,
      seerrRequestsEnabled: account?.seerrRequestsEnabled,
      homeBanner: home.homeBanner.name,
      homeCarousel: home.carouselSettings.name,
      homeNextUp: home.nextUp.name,
      pinnedCollectionIds: home.pinnedCollectionIds,
      themeMode: client.themeMode.name,
      themeColor: client.themeColor?.name,
      schemeVariant: client.schemeVariant.name,
      amoledBlack: client.amoledBlack,
      deriveColorsFromItem: client.deriveColorsFromItem,
      backgroundImage: client.backgroundImage.name,
      enableBlurEffects: client.enableBlurEffects,
      blurPlaceHolders: client.blurPlaceHolders,
      posterSize: client.posterSize,
      locale: const LocaleConvert().toJson(client.selectedLocale),
      showAllCollectionTypes: client.showAllCollectionTypes,
      usePosterForLibrary: client.usePosterForLibrary,
    );
  }

  void _apply(UserSettings s) {
    _applying = true;
    try {
      ref
          .read(clientSettingsProvider.notifier)
          .update(
            (c) => c.copyWith(
              themeMode: _byName(ThemeMode.values, s.themeMode) ?? c.themeMode,
              themeColor: _colorThemeByName(s.themeColor) ?? c.themeColor,
              schemeVariant: _byName(DynamicSchemeVariant.values, s.schemeVariant) ?? c.schemeVariant,
              amoledBlack: s.amoledBlack ?? c.amoledBlack,
              deriveColorsFromItem: s.deriveColorsFromItem ?? c.deriveColorsFromItem,
              backgroundImage: _byName(BackgroundType.values, s.backgroundImage) ?? c.backgroundImage,
              enableBlurEffects: s.enableBlurEffects ?? c.enableBlurEffects,
              blurPlaceHolders: s.blurPlaceHolders ?? c.blurPlaceHolders,
              posterSize: s.posterSize ?? c.posterSize,
              selectedLocale: s.locale != null ? const LocaleConvert().fromJson(s.locale) : c.selectedLocale,
              showAllCollectionTypes: s.showAllCollectionTypes ?? c.showAllCollectionTypes,
              usePosterForLibrary: s.usePosterForLibrary ?? c.usePosterForLibrary,
            ),
          );

      ref
          .read(homeSettingsProvider.notifier)
          .update(
            (h) => h.copyWith(
              homeBanner: _byName(HomeBanner.values, s.homeBanner) ?? h.homeBanner,
              carouselSettings: _byName(HomeCarouselSettings.values, s.homeCarousel) ?? h.carouselSettings,
              nextUp: _byName(HomeNextUp.values, s.homeNextUp) ?? h.nextUp,
              pinnedCollectionIds: s.pinnedCollectionIds ?? h.pinnedCollectionIds,
            ),
          );

      if (s.seerrServerUrl != null && s.seerrServerUrl!.isNotEmpty) {
        ref.read(userProvider.notifier).setSeerrServerUrl(s.seerrServerUrl);
      }
    } finally {
      _applying = false;
    }
  }
}

T? _byName<T extends Enum>(Iterable<T> values, String? name) {
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

/// [ColorThemes] carries its own `name` field (e.g. 'Fladder', 'Deep Orange')
/// that shadows `Enum.name`, and [_buildFrom] persists that custom string.
/// The generic [_byName] above would compare against `Enum.name` (the Dart
/// identifier, 'fladder') instead and never match, silently dropping the
/// synced theme colour — so match on the custom field here. (Guarded by
/// config_sync_round_trip_test.dart.)
ColorThemes? _colorThemeByName(String? name) {
  if (name == null) return null;
  for (final value in ColorThemes.values) {
    if (value.name == name) return value;
  }
  return null;
}
