import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';
import 'package:driftfin/widgets/shared/fladder_slider.dart';

const _touchModel = AdaptiveLayoutModel(
  viewSize: ViewSize.phone,
  layoutMode: LayoutMode.single,
  inputDevice: InputDevice.touch,
  platform: TargetPlatform.android,
  isDesktop: false,
  posterDefaults: PosterDefaults(size: 100, ratio: 0.66),
  controller: {},
  sideBarWidth: 0,
  topBarHeight: 0,
  statusBarHeight: 0,
);

const _dpadModel = AdaptiveLayoutModel(
  viewSize: ViewSize.television,
  layoutMode: LayoutMode.single,
  inputDevice: InputDevice.dPad,
  platform: TargetPlatform.android,
  isDesktop: false,
  posterDefaults: PosterDefaults(size: 100, ratio: 0.66),
  controller: {},
  sideBarWidth: 0,
  topBarHeight: 0,
  statusBarHeight: 0,
);

Widget _harness(
  Widget slider, {
  AdaptiveLayoutModel model = _touchModel,
}) {
  return MaterialApp(
    home: AdaptiveLayout(
      data: model,
      child: Scaffold(
        body: SizedBox(width: 300, child: slider),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders without throwing at default values', (tester) async {
    await tester.pumpWidget(_harness(const FladderSlider(value: 0.5)));
    await tester.pumpAndSettle();
    expect(find.byType(FladderSlider), findsOneWidget);
  });

  testWidgets('renders with divisions and shows division dots', (tester) async {
    await tester.pumpWidget(_harness(const FladderSlider(value: 0.4, divisions: 4)));
    await tester.pumpAndSettle();
    expect(find.byType(FladderSlider), findsOneWidget);
  });

  testWidgets('tap invokes onChanged and onChangeEnd', (tester) async {
    double? changed;
    double? changedEnd;
    await tester.pumpWidget(_harness(FladderSlider(
      value: 0.2,
      onChanged: (v) => changed = v,
      onChangeEnd: (v) => changedEnd = v,
    )));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.byType(FladderSlider)));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changedEnd, isNotNull);
  });

  testWidgets('horizontal drag invokes onChangeStart, onChanged, onChangeEnd', (tester) async {
    double? start;
    double? changed;
    double? end;
    await tester.pumpWidget(_harness(FladderSlider(
      value: 0.5,
      onChangeStart: (v) => start = v,
      onChanged: (v) => changed = v,
      onChangeEnd: (v) => end = v,
    )));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(FladderSlider), const Offset(50, 0));
    await tester.pumpAndSettle();

    expect(start, isNotNull);
    expect(changed, isNotNull);
    expect(end, isNotNull);
  });

  testWidgets('updating value via didUpdateWidget triggers animation', (tester) async {
    Widget build(double value) => _harness(FladderSlider(value: value));
    await tester.pumpWidget(build(0.1));
    await tester.pumpAndSettle();

    await tester.pumpWidget(build(0.8));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(FladderSlider), findsOneWidget);
  });

  testWidgets('renders as a FocusButton and handles dpad key input on dpad devices', (tester) async {
    double? changed;
    double? end;
    await tester.pumpWidget(_harness(
      FladderSlider(value: 0.5, onChanged: (v) => changed = v, onChangeEnd: (v) => end = v),
      model: _dpadModel,
    ));
    await tester.pumpAndSettle();

    // FladderSlider builds its own internal FocusButton with its own Focus
    // widget/node as a descendant. Focus.of() searches ancestors, so it can't
    // resolve this node from any context in or under the tree; grab the
    // Focus widget itself and request focus on its node directly.
    final focusWidget = tester.widget<Focus>(find
        .descendant(
          of: find.byType(FladderSlider),
          matching: find.byType(Focus),
        )
        .first);
    focusWidget.focusNode!.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(end, isNotNull);
  });

  testWidgets('showThumb false hides the thumb without throwing', (tester) async {
    await tester.pumpWidget(_harness(const FladderSlider(value: 0.6, showThumb: false)));
    await tester.pumpAndSettle();
    expect(find.byType(FladderSlider), findsOneWidget);
  });
}
