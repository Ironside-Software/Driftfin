import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/items/overview_model.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/shared/detail_scaffold.dart';
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

ItemBaseModel _item({String name = 'Test Movie', String id = 'id-1'}) => ItemBaseModel(
      name: name,
      id: id,
      overview: const OverviewModel(),
      parentId: null,
      playlistId: null,
      images: null,
      childCount: null,
      primaryRatio: null,
      userData: const UserData(),
      canDownload: null,
      canDelete: null,
      jellyType: null,
    );

Widget _harness({ItemBaseModel? item, bool posterFillsContent = false, String label = 'Detail'}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdaptiveLayout(
        data: _adaptiveModel,
        child: DetailScaffold(
          label: label,
          item: item,
          posterFillsContent: posterFillsContent,
          content: (context, padding) => Padding(
            padding: padding,
            child: const Text('Detail content'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders with no item without throwing', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text('Detail content'), findsOneWidget);
  });

  testWidgets('renders with an item and posterFillsContent', (tester) async {
    await tester.pumpWidget(_harness(item: _item(), posterFillsContent: true));
    await tester.pump();

    expect(find.text('Detail content'), findsOneWidget);
    // Home button shown since layout mode is single.
    expect(find.byIcon(Icons.home_outlined), findsNothing);
  });

  testWidgets('back button pops the route', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byType(BackButtonIcon), findsOneWidget);
  });
}
