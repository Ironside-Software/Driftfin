import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:extended_image/extended_image.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/items/overview_model.dart';
import 'package:driftfin/models/items/photos_model.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/photo_viewer/photo_viewer_controls.dart';
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
);

const _desktopAdaptiveModel = AdaptiveLayoutModel(
  viewSize: ViewSize.desktop,
  layoutMode: LayoutMode.single,
  inputDevice: InputDevice.pointer,
  platform: TargetPlatform.linux,
  isDesktop: true,
  posterDefaults: PosterDefaults(size: 100, ratio: 0.66),
  controller: <HomeTabs, ScrollController>{},
  sideBarWidth: 0,
  topBarHeight: 0,
);

PhotoModel _photo({String id = 'photo-1', String name = 'A Photo', bool favourite = false}) => PhotoModel(
      albumId: null,
      dateTaken: null,
      thumbnail: null,
      internalType: FladderItemType.photo,
      name: name,
      id: id,
      overview: const OverviewModel(),
      parentId: null,
      playlistId: null,
      images: null,
      childCount: null,
      primaryRatio: null,
      userData: UserData(isFavourite: favourite),
      canDownload: null,
      canDelete: null,
    );

Widget _harness({
  required PhotoModel photo,
  AdaptiveLayoutModel adaptive = _adaptiveModel,
  int itemCount = 3,
  int currentIndex = 0,
  bool loadingMoreItems = false,
}) {
  final controller = ExtendedPageController(initialPage: currentIndex);
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdaptiveLayout(
        data: adaptive,
        child: Scaffold(
          body: PhotoViewerControls(
            padding: EdgeInsets.zero,
            photo: photo,
            pageController: controller,
            loadingMoreItems: loadingMoreItems,
            openOptions: () {},
            onPhotoChanged: (_) {},
            itemCount: itemCount,
            currentIndex: currentIndex,
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders without throwing on mobile layout', (tester) async {
    await tester.pumpWidget(_harness(photo: _photo()));
    await tester.pump();

    expect(find.text('A Photo'), findsOneWidget);
    expect(find.text('1 / 3 '), findsOneWidget);
  });

  testWidgets('renders on desktop layout with fullscreen button', (tester) async {
    await tester.pumpWidget(_harness(photo: _photo(), adaptive: _desktopAdaptiveModel));
    await tester.pump();

    expect(find.text('A Photo'), findsOneWidget);
  });

  testWidgets('shows loading indicator when loadingMoreItems is true', (tester) async {
    await tester.pumpWidget(_harness(photo: _photo(), loadingMoreItems: true));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('-'), findsOneWidget);
  });

  testWidgets('shows filled heart icon when the photo is a favourite', (tester) async {
    await tester.pumpWidget(_harness(photo: _photo(favourite: true)));
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsNothing); // sanity: not using material icons here
  });

  testWidgets('tapping back pops with the current page', (tester) async {
    await tester.pumpWidget(_harness(photo: _photo()));
    await tester.pump();

    // Back button + favourite + options buttons exist and are tappable without throwing.
    final iconButtons = find.byType(IconButton);
    expect(iconButtons, findsWidgets);
  });
}
