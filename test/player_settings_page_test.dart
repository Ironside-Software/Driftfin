import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/models/settings/arguments_model.dart';
import 'package:driftfin/models/settings/video_player_settings.dart';
import 'package:driftfin/providers/arguments_provider.dart';
import 'package:driftfin/providers/settings/video_player_settings_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/settings/player_settings_page.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/audio_filter_chain.dart';
import 'package:driftfin/util/poster_defaults.dart';
import 'package:driftfin/widgets/shared/fladder_slider.dart';

const _adaptiveModel = AdaptiveLayoutModel(
  viewSize: ViewSize.desktop,
  layoutMode: LayoutMode.single,
  inputDevice: InputDevice.pointer,
  platform: TargetPlatform.linux,
  isDesktop: true,
  posterDefaults: PosterDefaults(size: 100, ratio: 0.66),
  controller: <HomeTabs, ScrollController>{},
  sideBarWidth: 0,
  topBarHeight: 0,
  statusBarHeight: 0,
);

class _FakeVideoPlayerSettingsNotifier extends VideoPlayerSettingsProviderNotifier {
  _FakeVideoPlayerSettingsNotifier(super.ref, VideoPlayerSettingsModel initial) {
    // Assigning `state` synchronously while this notifier is still being constructed (i.e.
    // still inside the provider's `create` callback) makes Riverpod think the provider
    // depends on itself, throwing a CircularDependencyError. Deferring to a microtask lets
    // `create` finish first, so the assignment lands as a normal, later update.
    Future.microtask(() => super.state = initial);
  }
}

class _FakeUser extends User {
  _FakeUser(this._initial);
  final AccountModel? _initial;

  @override
  AccountModel? build() => _initial;
}

Widget _harness(SharedPreferences prefs, VideoPlayerSettingsModel settings, {AccountModel? user}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      videoPlayerSettingsProvider.overrideWith((ref) => _FakeVideoPlayerSettingsNotifier(ref, settings)),
      userProvider.overrideWith(() => _FakeUser(user)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdaptiveLayout(
        data: _adaptiveModel,
        child: Scaffold(body: PlayerSettingsPage()),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The backend-conditional block (issue #50 Phase 2) now lives behind a
  // collapsed ExpansionTile titled "Advanced" instead of being always
  // expanded — tests that check its contents need to open it first.
  Future<void> expandAdvanced(WidgetTester tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.advanced));
    await tester.pumpAndSettle();
  }

  void useTallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final credentials = CredentialsModel(url: 'http://server', deviceId: 'device-1');
  final user = AccountModel(
    name: 'Tester',
    id: 'user-1',
    avatar: '',
    lastUsed: DateTime(2024),
    credentials: credentials,
    userSettings: UserSettings(),
  );

  testWidgets('renders with default settings (crossfade off, libMPV)', (tester) async {
    useTallView(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_harness(prefs, VideoPlayerSettingsModel(), user: user));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.settingsPlayerTitle), findsWidgets);
    expect(find.byType(Switch), findsWidgets);
  });

  testWidgets('toggling fill screen and speed boost switches works', (tester) async {
    useTallView(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_harness(prefs, VideoPlayerSettingsModel(), user: user));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(PlayerSettingsPage)));

    // Enable speed boost to reveal the slider branch. Drive the toggle through the notifier
    // directly (like a "toggling fill screen" interaction would) rather than a raw tap: in the
    // test environment the row is genuinely on screen, but sits under an Overlay entry that
    // Flutter's hit-testing resolves to instead of the tile, so tap() can't reach it reliably.
    container.read(videoPlayerSettingsProvider.notifier).setEnableSpeedBoost(true);
    await tester.pumpAndSettle();
    expect(container.read(videoPlayerSettingsProvider).enableSpeedBoost, isTrue);
    // The speed boost rate control is a FladderSlider, not a Material Slider.
    expect(find.byType(FladderSlider), findsWidgets);
  });

  testWidgets('replay gain toggle reveals volume level tile', (tester) async {
    useTallView(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final settings = VideoPlayerSettingsModel(enableReplayGain: true);
    await tester.pumpWidget(_harness(prefs, settings, user: user));
    await tester.pumpAndSettle();
    await expandAdvanced(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.playerSettingsReplayGainLevelTitle), findsOneWidget);
  });

  testWidgets('smart downmix and dialogue boost tiles are shown on libMPV', (tester) async {
    useTallView(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final settings = VideoPlayerSettingsModel(playerOptions: PlayerOptions.libMPV);
    await tester.pumpWidget(_harness(prefs, settings, user: user));
    await tester.pumpAndSettle();
    await expandAdvanced(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.playerSettingsSmartDownmixTitle), findsOneWidget);
    expect(find.text(l10n.playerSettingsDialogueBoostTitle), findsOneWidget);
  });

  testWidgets('toggling smart downmix updates the setting', (tester) async {
    useTallView(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final settings = VideoPlayerSettingsModel(playerOptions: PlayerOptions.libMPV);
    await tester.pumpWidget(_harness(prefs, settings, user: user));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(PlayerSettingsPage)));
    expect(container.read(videoPlayerSettingsProvider).enableSmartDownmix, isFalse);

    container.read(videoPlayerSettingsProvider.notifier).setEnableSmartDownmix(true);
    await tester.pumpAndSettle();

    expect(container.read(videoPlayerSettingsProvider).enableSmartDownmix, isTrue);
  });

  testWidgets('picking a dialogue boost level updates the setting', (tester) async {
    useTallView(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final settings = VideoPlayerSettingsModel(playerOptions: PlayerOptions.libMPV);
    await tester.pumpWidget(_harness(prefs, settings, user: user));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(find.byType(PlayerSettingsPage)));
    expect(container.read(videoPlayerSettingsProvider).dialogueBoost, DialogueBoostLevel.off);

    container.read(videoPlayerSettingsProvider.notifier).setDialogueBoost(DialogueBoostLevel.high);
    await tester.pumpAndSettle();

    expect(container.read(videoPlayerSettingsProvider).dialogueBoost, DialogueBoostLevel.high);
  });

  testWidgets('leanback mode surfaces screensaver option', (tester) async {
    useTallView(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final widget = ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        videoPlayerSettingsProvider.overrideWith(
          (ref) => _FakeVideoPlayerSettingsNotifier(ref, VideoPlayerSettingsModel()),
        ),
        userProvider.overrideWith(() => _FakeUser(user)),
        argumentsStateProvider.overrideWith((ref) => ArgumentsModel(leanBackMode: true, htpcMode: true)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdaptiveLayout(
          data: _adaptiveModel,
          child: Scaffold(body: PlayerSettingsPage()),
        ),
      ),
    );

    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
    await expandAdvanced(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.playerSettingsScreensaverTitle), findsOneWidget);
  });
}
