// Verifies the BasePlayer capability matrix (issue #47): every backend must
// report an explicit PlayerCapabilities value, and UI-relevant capabilities
// must be honest about what each engine can actually do.
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/stubs/web/lib_mdk_web.dart' as web_stub;
import 'package:driftfin/wrappers/players/lib_mdk.dart';
import 'package:driftfin/wrappers/players/lib_mpv.dart';
import 'package:driftfin/wrappers/players/native_player.dart';
import 'package:driftfin/wrappers/players/player_capabilities.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BasePlayer capability matrix', () {
    test('LibMPV (the default, real mpv engine) supports the full feature set', () {
      final capabilities = LibMPV().capabilities;
      expect(capabilities.screenshots, isTrue);
      expect(capabilities.audioDsp, isTrue);
      expect(capabilities.ambientGlow, isTrue);
      expect(capabilities.errorReporting, isTrue);
      expect(capabilities.subtitleDelay, isTrue);
      expect(capabilities.crossfade, isTrue);
      expect(capabilities.secondarySubtitles, isTrue);
    });

    test('LibMDK (FVP/mdk) supports screenshots, subtitle delay and error reporting', () {
      final capabilities = LibMDK().capabilities;
      expect(capabilities.screenshots, isTrue);
      expect(capabilities.subtitleDelay, isTrue);
      expect(capabilities.errorReporting, isTrue);
      expect(capabilities.audioDsp, isFalse);
      expect(capabilities.ambientGlow, isFalse);
      expect(capabilities.crossfade, isFalse);
      expect(capabilities.secondarySubtitles, isFalse);
    });

    test('NativePlayer (Android-TV ExoPlayer) gray-zones audio DSP and screenshots', () {
      final capabilities = NativePlayer().capabilities;
      expect(capabilities.subtitleDelay, isTrue);
      expect(capabilities.errorReporting, isTrue);
      expect(capabilities.screenshots, isFalse);
      expect(capabilities.audioDsp, isFalse);
      expect(capabilities.ambientGlow, isFalse);
      expect(capabilities.crossfade, isFalse);
      expect(capabilities.secondarySubtitles, isFalse);
    });

    test('web stub reports no optional capabilities', () {
      expect(web_stub.LibMDK().capabilities, PlayerCapabilities.none);
    });

    test('no capability is silently true-by-default', () {
      expect(const PlayerCapabilities(), PlayerCapabilities.none);
      expect(PlayerCapabilities.none.screenshots, isFalse);
      expect(PlayerCapabilities.none.audioDsp, isFalse);
      expect(PlayerCapabilities.none.ambientGlow, isFalse);
      expect(PlayerCapabilities.none.perTitleZoomPan, isFalse);
      expect(PlayerCapabilities.none.errorReporting, isFalse);
      expect(PlayerCapabilities.none.subtitleDelay, isFalse);
      expect(PlayerCapabilities.none.crossfade, isFalse);
      expect(PlayerCapabilities.none.secondarySubtitles, isFalse);
    });
  });

  group('PlayerCapabilities value semantics', () {
    test('equal when every field matches', () {
      const a = PlayerCapabilities(screenshots: true, audioDsp: true, subtitleDelay: true);
      const b = PlayerCapabilities(screenshots: true, audioDsp: true, subtitleDelay: true);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('is identical to itself', () {
      const a = PlayerCapabilities(screenshots: true);
      // ignore: unrelated_type_equality_checks
      expect(identical(a, a), isTrue);
      expect(a == a, isTrue);
    });

    test('not equal when any single field differs', () {
      const base = PlayerCapabilities(screenshots: true, audioDsp: true);

      expect(base, isNot(const PlayerCapabilities(screenshots: true, audioDsp: true, secondarySubtitles: true)));
      expect(base, isNot(const PlayerCapabilities(screenshots: false, audioDsp: true)));
      expect(base, isNot(const PlayerCapabilities(screenshots: true, audioDsp: false)));
      expect(base, isNot(const PlayerCapabilities(screenshots: true, audioDsp: true, ambientGlow: true)));
      expect(base, isNot(const PlayerCapabilities(screenshots: true, audioDsp: true, perTitleZoomPan: true)));
      expect(base, isNot(const PlayerCapabilities(screenshots: true, audioDsp: true, errorReporting: true)));
      expect(base, isNot(const PlayerCapabilities(screenshots: true, audioDsp: true, subtitleDelay: true)));
      expect(base, isNot(const PlayerCapabilities(screenshots: true, audioDsp: true, crossfade: true)));
    });

    test('is not equal to an unrelated type', () {
      // ignore: unrelated_type_equality_checks
      expect(const PlayerCapabilities() == 'not a PlayerCapabilities', isFalse);
    });

    test('toString reports every field', () {
      const capabilities = PlayerCapabilities(
        screenshots: true,
        audioDsp: true,
        ambientGlow: true,
        perTitleZoomPan: true,
        errorReporting: true,
        subtitleDelay: true,
        crossfade: true,
      );

      final text = capabilities.toString();
      expect(text, contains('screenshots: true'));
      expect(text, contains('audioDsp: true'));
      expect(text, contains('ambientGlow: true'));
      expect(text, contains('perTitleZoomPan: true'));
      expect(text, contains('errorReporting: true'));
      expect(text, contains('subtitleDelay: true'));
      expect(text, contains('crossfade: true'));
    });
  });
}
