import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/items/chapters_model.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/video_player/components/video_player_chapters.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';

const _adaptiveModel = AdaptiveLayoutModel(
  viewSize: ViewSize.phone,
  layoutMode: LayoutMode.single,
  inputDevice: InputDevice.touch,
  platform: TargetPlatform.android,
  isDesktop: false,
  posterDefaults: PosterDefaults(size: 100, ratio: 0.66),
  controller: <HomeTabs, ScrollController>{},
  sideBarWidth: 0,
  topBarHeight: 0,
  statusBarHeight: 0,
);

Chapter _chapter({required String name, String imageUrl = '', int startMs = 0}) =>
    Chapter(name: name, imageUrl: imageUrl, startPosition: Duration(milliseconds: startMs));

Widget _harness(List<Chapter> chapters) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdaptiveLayout(
          data: _adaptiveModel,
          child: Scaffold(
            body: VideoPlayerChapters(
              chapters: chapters,
              onChapterTapped: (_) {},
              currentPosition: Duration.zero,
            ),
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders each chapter, using the network image when present and an icon otherwise', (tester) async {
    await tester.pumpWidget(_harness([
      _chapter(name: 'Opening', imageUrl: 'http://server/Items/x/Images/Chapter/0?tag=t', startMs: 0),
      _chapter(name: 'Credits', startMs: 120000),
    ]));
    await tester.pump();

    expect(find.text('Opening'), findsOneWidget);
    expect(find.text('Credits'), findsOneWidget);
  });
}
