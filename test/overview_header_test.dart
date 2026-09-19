import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/screens/details_screens/components/overview_header.dart';
import 'package:driftfin/screens/details_screens/components/media_stream_information.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/items/media_streams_model.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';
import 'package:driftfin/screens/home_screen.dart';

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

Widget _harness(Widget child, {AdaptiveLayoutModel model = _adaptiveModel}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdaptiveLayout(
        data: model,
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders minimal header with only a name', (tester) async {
    await tester.pumpWidget(_harness(const OverviewHeader(name: 'The Matrix')));
    await tester.pumpAndSettle();

    expect(find.text('The Matrix'), findsOneWidget);
  });

  testWidgets('renders full metadata: subtitle, original title, genres, labels', (tester) async {
    await tester.pumpWidget(
      _harness(
        OverviewHeader(
          name: 'The Matrix',
          subTitle: 'A hacker discovers reality',
          originalTitle: 'La Matrice',
          productionYear: '1999',
          officialRating: 'R',
          communityRating: 8.7,
          runTime: const Duration(minutes: 136),
          genres: [
            GenreItems(id: '1', name: 'Action'),
            GenreItems(id: '2', name: 'Sci-Fi'),
          ],
          studios: [Studio(id: 's1', name: 'Warner Bros')],
          additionalLabels: const [SimpleLabel(label: Text('Extra Label'))],
          summary: const Text('A great movie summary.'),
          mainButton: const Icon(Icons.play_arrow),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The Matrix'), findsOneWidget);
    expect(find.text('A hacker discovers reality'), findsOneWidget);
    expect(find.text('La Matrice'), findsOneWidget);
    expect(find.text('1999'), findsOneWidget);
    expect(find.text('R'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
    // Genres renders genre.name.capitalize(), which uppercases only the first
    // character and lowercases the rest (see lib/util/string_extensions.dart).
    expect(find.text('Sci-fi'), findsOneWidget);
    expect(find.text('Extra Label'), findsOneWidget);
    expect(find.text('A great movie summary.'), findsOneWidget);
  });

  testWidgets('renders media stream options row when mediaStreamHelper is provided', (tester) async {
    final mediaStreamHelper = MediaStreamHelper(
      mediaStream: MediaStreamsModel(
        versionStreamIndex: 0,
        defaultAudioStreamIndex: -1,
        defaultSubStreamIndex: -1,
        versionStreams: [
          VersionStreamModel(
            name: 'Version 1',
            index: 0,
            defaultAudioStreamIndex: -1,
            defaultSubStreamIndex: -1,
            videoStreams: const [],
            audioStreams: [],
            subStreams: [],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _harness(
        OverviewHeader(
          name: 'Some Show',
          mediaStreamHelper: mediaStreamHelper,
          centerButtons: const Icon(Icons.favorite),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Some Show'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('non-phone layout renders poster and title row', (tester) async {
    const desktopModel = AdaptiveLayoutModel(
      viewSize: ViewSize.desktop,
      layoutMode: LayoutMode.dual,
      inputDevice: InputDevice.pointer,
      platform: TargetPlatform.linux,
      isDesktop: true,
      posterDefaults: PosterDefaults(size: 100, ratio: 0.66),
      controller: <HomeTabs, ScrollController>{},
      sideBarWidth: 0,
      topBarHeight: 0,
      statusBarHeight: 0,
    );

    await tester.pumpWidget(
      _harness(
        OverviewHeader(
          name: 'Desktop Item',
          poster: Container(width: 50, height: 75, color: Colors.blue),
        ),
        model: desktopModel,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Desktop Item'), findsOneWidget);
    expect(find.byType(Container), findsWidgets);
  });
}
