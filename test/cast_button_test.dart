import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/providers/cast_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/video_player/components/cast_button.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';

import 'support/video_player_test_support.dart';

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

/// Extends the shared [FakeCastController] (which just counts `discover()`
/// calls) with the extra hooks the "Play on…" picker tests below need: a way
/// to seed a fixed device list, and to record dispatched `connect()` calls
/// without touching real Chromecast/DLNA/session network I/O.
class _TestCastController extends FakeCastController {
  _TestCastController(super.ref);

  final List<CastTarget> connected = [];

  void seed(CastState newState) => state = newState;

  @override
  Future<void> connect(CastTarget target) async {
    connected.add(target);
  }
}

const _chromecastTarget = CastTarget(id: 'cc:Living Room', name: 'Living Room', backend: CastBackend.chromecast);

const _sessionTarget = CastTarget(
  id: 'session:s1',
  name: 'Bedroom TV · bob',
  backend: CastBackend.jellyfinSession,
  session: SessionInfoDto(id: 's1', deviceName: 'Bedroom TV', userName: 'bob', supportsRemoteControl: true),
);

Future<ProviderContainer> _pumpCastButton(
  WidgetTester tester, {
  required void Function(_TestCastController) onCreated,
  CastState initial = const CastState(),
}) async {
  final container = ProviderContainer(
    overrides: [
      castProvider.overrideWith((ref) {
        final fake = _TestCastController(ref)..seed(initial);
        onCreated(fake);
        return fake;
      }),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      // AdaptiveLayout must wrap MaterialApp (as in lib/main.dart) since the
      // cast sheet is a modal route - a sibling of `home` under the root
      // Navigator, not a descendant of anything nested inside `home`.
      child: const AdaptiveLayout(
        data: _adaptiveModel,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CastButton()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows the idle cast icon when nothing is casting', (tester) async {
    await _pumpCastButton(tester, onCreated: (_) {});
    expect(find.byIcon(Icons.cast_rounded), findsOneWidget);
  });

  testWidgets('tapping it triggers discovery and opens the cast sheet', (tester) async {
    late _TestCastController fake;
    await _pumpCastButton(tester, onCreated: (f) => fake = f);

    await tester.tap(find.byType(CastButton));
    await tester.pumpAndSettle();

    expect(fake.discoverCallCount, 1);
    expect(find.text('Play on…'), findsOneWidget);
  });

  testWidgets('unified picker lists nearby cast devices and remote Jellyfin sessions in separate sections',
      (tester) async {
    await _pumpCastButton(
      tester,
      onCreated: (_) {},
      initial: const CastState(devices: [_chromecastTarget, _sessionTarget]),
    );

    await tester.tap(find.byType(CastButton));
    await tester.pumpAndSettle();

    expect(find.text('Nearby devices'), findsOneWidget);
    expect(find.text('Your other devices'), findsOneWidget);
    expect(find.text('Living Room'), findsOneWidget);
    expect(find.text('Bedroom TV · bob'), findsOneWidget);
  });

  testWidgets('tapping a Jellyfin session target dispatches the handoff to that session', (tester) async {
    late _TestCastController fake;
    await _pumpCastButton(
      tester,
      onCreated: (f) => fake = f,
      initial: const CastState(devices: [_chromecastTarget, _sessionTarget]),
    );

    await tester.tap(find.byType(CastButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bedroom TV · bob'));
    await tester.pumpAndSettle();

    expect(fake.connected, hasLength(1));
    expect(fake.connected.single.backend, CastBackend.jellyfinSession);
    expect(fake.connected.single.session?.id, 's1');
  });

  testWidgets('shows a combined empty state when nothing is discovered', (tester) async {
    await _pumpCastButton(tester, onCreated: (_) {});

    await tester.tap(find.byType(CastButton));
    await tester.pumpAndSettle();

    expect(find.text('No devices or active sessions found'), findsOneWidget);
  });
}
