import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/book_model.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/items/images_models.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/items/overview_model.dart';
import 'package:driftfin/models/syncing/sync_item.dart';
import 'package:driftfin/models/syncing/sync_settings_model.dart';
import 'package:driftfin/providers/sync_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/shared/media/poster_list_item.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';

/// Test double for [SyncNotifier] so `poster.generateActions()` (which reads
/// `syncProvider` while building the long-press/context-menu action list)
/// doesn't touch the real database/background-downloader machinery the real
/// notifier wires up in its constructor. Mirrors the pattern already used in
/// test/episode_detail_screen_test.dart.
class _FakeSyncNotifier extends StateNotifier<SyncSettingsModel> implements SyncNotifier {
  _FakeSyncNotifier() : super(SyncSettingsModel());

  @override
  Stream<SyncedItem?> watchItem(String id) => Stream.value(null);

  @override
  Future<SyncedItem?> getSyncedItem(String? id) async => null;

  @override
  Future<List<SyncedItem>> getNestedChildren(SyncedItem? item) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _phoneModel = AdaptiveLayoutModel(
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

const _desktopModel = AdaptiveLayoutModel(
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

ItemBaseModel _item({
  String name = 'Item',
  String id = 'id-1',
  ImagesData? images,
  UserData userData = const UserData(),
  OverviewModel overview = const OverviewModel(),
}) =>
    ItemBaseModel(
      name: name,
      id: id,
      overview: overview,
      parentId: null,
      playlistId: null,
      images: images,
      childCount: null,
      primaryRatio: null,
      userData: userData,
      canDownload: null,
      canDelete: null,
      jellyType: null,
    );

BookModel _book({
  String name = 'Book',
  String id = 'book-1',
  UserData userData = const UserData(),
}) =>
    BookModel(
      parentName: 'Series Name',
      name: name,
      id: id,
      overview: const OverviewModel(),
      parentId: null,
      playlistId: null,
      images: null,
      childCount: null,
      primaryRatio: null,
      userData: userData,
      canDownload: null,
      canDelete: null,
    );

Widget _harness(ItemBaseModel poster, {AdaptiveLayoutModel model = _phoneModel, Widget? subTitle}) {
  return ProviderScope(
    overrides: [
      syncProvider.overrideWith((ref) => _FakeSyncNotifier()),
    ],
    // AdaptiveLayout must wrap MaterialApp (as it does in lib/main.dart) so
    // that modal routes pushed on the root navigator (e.g. showBottomSheetPill,
    // which uses useRootNavigator: true) still see it via context.
    child: AdaptiveLayout(
      data: model,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PosterListItem(poster: poster, subTitle: subTitle),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders title and subtext for a plain item with no image', (tester) async {
    final item = _item(name: 'My Movie', overview: const OverviewModel(yearAired: 1999));
    await tester.pumpWidget(_harness(item));
    await tester.pumpAndSettle();

    expect(find.text('My Movie'), findsOneWidget);
  });

  testWidgets('does not show a favourite heart icon when not favourited', (tester) async {
    final item = _item(userData: const UserData(isFavourite: false));
    await tester.pumpWidget(_harness(item));
    await tester.pumpAndSettle();

    expect(find.byIcon(IconsaxPlusBold.heart), findsNothing);
  });

  testWidgets('shows a favourite heart icon when item is favourited', (tester) async {
    final item = _item(userData: const UserData(isFavourite: true));
    await tester.pumpWidget(_harness(item));
    await tester.pumpAndSettle();

    expect(find.byIcon(IconsaxPlusBold.heart), findsOneWidget);
  });

  testWidgets('renders a book with a progressed page badge', (tester) async {
    final book = _book(userData: const UserData(playbackPositionTicks: 6000000000, progress: 10));
    await tester.pumpWidget(_harness(book));
    await tester.pumpAndSettle();

    expect(find.text('Book'), findsOneWidget);
  });

  testWidgets('renders an optional subTitle widget alongside subtext', (tester) async {
    final item = _item(name: 'With Subtitle');
    await tester.pumpWidget(_harness(item, subTitle: const Text('Custom Subtitle')));
    await tester.pumpAndSettle();

    expect(find.text('Custom Subtitle'), findsOneWidget);
  });

  testWidgets('desktop layout shows a popup menu options button', (tester) async {
    final item = _item(name: 'Desktop Item');
    await tester.pumpWidget(_harness(item, model: _desktopModel));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton), findsOneWidget);
  });

  testWidgets('phone layout does not show a popup menu options button', (tester) async {
    final item = _item(name: 'Phone Item');
    await tester.pumpWidget(_harness(item));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton), findsNothing);
  });

  testWidgets('tapping the item invokes navigation without throwing', (tester) async {
    final item = _item(name: 'Tap Item');
    await tester.pumpWidget(_harness(item));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tap Item'));
    await tester.pumpAndSettle();
  });

  testWidgets('long-press opens the bottom sheet with item actions', (tester) async {
    final item = _item(name: 'LongPress Item');
    await tester.pumpWidget(_harness(item));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(PosterListItem));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsWidgets);
  });
}
