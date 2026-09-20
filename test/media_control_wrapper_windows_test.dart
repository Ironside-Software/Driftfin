import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smtc_windows/smtc_windows.dart';

import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/wrappers/media_control_wrapper.dart';

import 'support/video_player_test_support.dart';

final _refProvider = Provider<Ref>((ref) => ref);

class _Controls implements SMTCWindows {
  final buttons = StreamController<PressedButton>.broadcast();

  @override
  Stream<PressedButton> get buttonPressStream => buttons.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Wrapper extends MediaControlsWrapper {
  _Wrapper(Ref ref) : super(ref: ref);

  int plays = 0;

  @override
  Future<void> play() async => plays++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Windows backend replacement reuses controls and removes stale button listeners', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controls = _Controls();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        windowsMediaControlsProvider.overrideWithValue(controls),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(controls.buttons.close);
    final wrapper = _Wrapper(container.read(_refProvider));
    addTearDown(wrapper.dispose);

    await wrapper.setup(FakeBasePlayer());
    expect(wrapper.smtc, same(controls));
    await wrapper.setup(FakeBasePlayer());
    expect(wrapper.smtc, same(controls));
    controls.buttons.add(PressedButton.play);
    await Future<void>.delayed(Duration.zero);
    expect(wrapper.plays, 1);

    await wrapper.dispose();
    controls.buttons.add(PressedButton.play);
    await Future<void>.delayed(Duration.zero);
    expect(wrapper.plays, 1);
    expect(controls.buttons.hasListener, isFalse);

    await wrapper.setup(FakeBasePlayer());
    expect(wrapper.smtc, same(controls));
    controls.buttons.add(PressedButton.play);
    await Future<void>.delayed(Duration.zero);
    expect(wrapper.plays, 2);
  });
}
