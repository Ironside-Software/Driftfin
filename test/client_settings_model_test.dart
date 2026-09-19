import 'dart:convert';

import 'package:driftfin/models/settings/arguments_model.dart';
import 'package:driftfin/models/settings/client_settings_model.dart';
import 'package:driftfin/models/settings/key_combinations.dart';
import 'package:driftfin/models/syncing/transcode_download_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackgroundType.opacityValues', () {
    test('disabled is fully opaque, enabled/blurred share the dimmed opacity', () {
      expect(BackgroundType.disabled.opacityValues, 1.0);
      expect(BackgroundType.enabled.opacityValues, 0.75);
      expect(BackgroundType.blurred.opacityValues, 0.75);
    });
  });

  group('ClientSettingsModel.defaultModel', () {
    setUp(() => leanBackMode = false);
    tearDown(() => leanBackMode = false);

    test('non-leanback defaults favor blurring/system theme', () {
      leanBackMode = false;
      final model = ClientSettingsModel.defaultModel();
      expect(model.blurPlaceHolders, isTrue);
      expect(model.backgroundImage, BackgroundType.blurred);
      expect(model.themeMode, ThemeMode.system);
      expect(model.enableBlurEffects, isTrue);
      expect(model.useTVExpandedLayout, isFalse);
    });

    test('leanBackMode defaults disable blur/backgrounds and force dark theme', () {
      leanBackMode = true;
      final model = ClientSettingsModel.defaultModel();
      expect(model.blurPlaceHolders, isFalse);
      expect(model.backgroundImage, BackgroundType.disabled);
      expect(model.themeMode, ThemeMode.dark);
      expect(model.enableBlurEffects, isFalse);
    });
  });

  group('ClientSettingsModel.enableCrashReporting', () {
    ClientSettingsModel baseModel() => ClientSettingsModel.internal(
          transcodeDownloadModel: TranscodeDownloadModel.fromDefaults(),
        );

    test('defaults to false (opt-in, off by default)', () {
      expect(baseModel().enableCrashReporting, isFalse);
      expect(ClientSettingsModel.defaultModel().enableCrashReporting, isFalse);
    });

    test('copyWith toggles the flag', () {
      final model = baseModel().copyWith(enableCrashReporting: true);
      expect(model.enableCrashReporting, isTrue);
    });

    test('missing key in stored json falls back to false', () {
      final json = jsonDecode(jsonEncode(baseModel().toJson())) as Map<String, dynamic>;
      json.remove('enableCrashReporting');
      expect(ClientSettingsModel.fromJson(json).enableCrashReporting, isFalse);
    });

    test('round-trips through the persisted json (as stored by SharedUtility.clientSettings)', () {
      final model = baseModel().copyWith(enableCrashReporting: true);
      final decoded = jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>;
      expect(ClientSettingsModel.fromJson(decoded).enableCrashReporting, isTrue);
    });
  });

  group('ClientSettingsModel.smartDownloadBudgetBytes', () {
    ClientSettingsModel baseModel() => ClientSettingsModel.internal(
          transcodeDownloadModel: TranscodeDownloadModel.fromDefaults(),
        );

    test('defaults to null (no budget, unlimited)', () {
      expect(baseModel().smartDownloadBudgetBytes, isNull);
      expect(ClientSettingsModel.defaultModel().smartDownloadBudgetBytes, isNull);
    });

    test('copyWith sets a budget', () {
      final model = baseModel().copyWith(smartDownloadBudgetBytes: 1024);
      expect(model.smartDownloadBudgetBytes, 1024);
    });

    test('round-trips through the persisted json', () {
      final model = baseModel().copyWith(smartDownloadBudgetBytes: 2048);
      final decoded = jsonDecode(jsonEncode(model.toJson())) as Map<String, dynamic>;
      expect(ClientSettingsModel.fromJson(decoded).smartDownloadBudgetBytes, 2048);
    });

    test('missing key in stored json falls back to null', () {
      final json =
          jsonDecode(jsonEncode(baseModel().copyWith(smartDownloadBudgetBytes: 2048).toJson())) as Map<String, dynamic>;
      json.remove('smartDownloadBudgetBytes');
      expect(ClientSettingsModel.fromJson(json).smartDownloadBudgetBytes, isNull);
    });
  });

  group('ClientSettingsModel.currentShortcuts / defaultShortCuts', () {
    ClientSettingsModel baseModel() => ClientSettingsModel.internal(
          transcodeDownloadModel: TranscodeDownloadModel.fromDefaults(),
        );

    test('defaultShortCuts contains every GlobalHotKeys entry', () {
      final model = baseModel();
      expect(model.defaultShortCuts.keys.toSet(), GlobalHotKeys.values.toSet());
    });

    test('currentShortcuts overlays a configured override on top of the defaults', () {
      final overridden = KeyCombination(key: LogicalKeyboardKey.keyX);
      final model = baseModel().copyWith(shortcuts: {GlobalHotKeys.exit: overridden});

      expect(model.currentShortcuts[GlobalHotKeys.exit], overridden);
      expect(
        model.currentShortcuts[GlobalHotKeys.search],
        model.defaultShortCuts[GlobalHotKeys.search],
      );
    });

    test('macOS default shortcuts use the super key; other platforms use control', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final macModel = baseModel();
      expect(macModel.defaultShortCuts[GlobalHotKeys.search]?.modifier, LogicalKeyboardKey.superKey);

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final linuxModel = baseModel();
      expect(linuxModel.defaultShortCuts[GlobalHotKeys.search]?.modifier, LogicalKeyboardKey.controlLeft);

      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('LocaleConvert', () {
    const converter = LocaleConvert();

    test('fromJson returns null for null/empty input', () {
      expect(converter.fromJson(null), isNull);
      expect(converter.fromJson(''), isNull);
    });

    test('parses a bare language code', () {
      expect(converter.fromJson('en'), const Locale('en'));
    });

    test('parses language_COUNTRY', () {
      final locale = converter.fromJson('en_US');
      expect(locale?.languageCode, 'en');
      expect(locale?.countryCode, 'US');
    });

    test('parses language_Script (4-letter subtag)', () {
      final locale = converter.fromJson('zh_Hant');
      expect(locale?.languageCode, 'zh');
      expect(locale?.scriptCode, 'Hant');
    });

    test('parses language_Script_COUNTRY', () {
      final locale = converter.fromJson('zh_Hant_TW');
      expect(locale?.languageCode, 'zh');
      expect(locale?.scriptCode, 'Hant');
      expect(locale?.countryCode, 'TW');
    });

    test('returns null for too many subtags', () {
      expect(converter.fromJson('a_b_c_d'), isNull);
    });

    test('toJson delegates to Locale.toDisplayCode (null-safe)', () {
      expect(converter.toJson(null), isNull);
      expect(converter.toJson(const Locale('en', 'US')), converter.toJson(const Locale('en', 'US')));
    });
  });

  group('Vector2', () {
    test('fromSize / fromPosition extract x,y from Size/Offset', () {
      expect(Vector2.fromSize(const Size(100, 200)), const Vector2(x: 100, y: 200));
      expect(Vector2.fromPosition(const Offset(5, 6)), const Vector2(x: 5, y: 6));
    });

    test('toMap/fromMap round trip', () {
      const vector = Vector2(x: 1.5, y: 2.5);
      expect(Vector2.fromMap(vector.toMap()), vector);
    });

    test('toJson/fromJson string round trip', () {
      const vector = Vector2(x: 10, y: 20);
      expect(Vector2.fromJson(vector.toJson()), vector);
    });

    test('copyWith overrides only the given field', () {
      const vector = Vector2(x: 1, y: 2);
      expect(vector.copyWith(x: 9), const Vector2(x: 9, y: 2));
    });

    test('equality/hashCode based on x and y', () {
      expect(const Vector2(x: 1, y: 2), const Vector2(x: 1, y: 2));
      expect(const Vector2(x: 1, y: 2) == const Vector2(x: 1, y: 3), isFalse);
    });
  });

  group('ClientSettingsModel.statusBarBrightness', () {
    testWidgets('dark theme mode always yields light status bar content', (tester) async {
      final model = ClientSettingsModel.internal(
        transcodeDownloadModel: TranscodeDownloadModel.fromDefaults(),
        themeMode: ThemeMode.dark,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(model.statusBarBrightness(context), Brightness.light);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('light theme mode always yields dark status bar content', (tester) async {
      final model = ClientSettingsModel.internal(
        transcodeDownloadModel: TranscodeDownloadModel.fromDefaults(),
        themeMode: ThemeMode.light,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(model.statusBarBrightness(context), Brightness.dark);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
