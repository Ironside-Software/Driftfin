import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/items/item_shared_models.dart';
import 'package:driftfin/models/syncing/sync_item.dart';
import 'package:driftfin/providers/connectivity_provider.dart';
import 'package:driftfin/providers/dashboard_provider.dart';
import 'package:driftfin/providers/library_screen_provider.dart' as library_state;
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';
import 'package:driftfin/providers/living_home_provider.dart';
import 'package:driftfin/providers/offline_catalog_provider.dart';
import 'package:driftfin/screens/dashboard/dashboard_screen.dart';
import 'package:driftfin/screens/library/library_screen.dart';
import 'package:driftfin/screens/offline/offline_catalog_screen.dart';

import 'offline_catalog_test.dart' show episode;

class _OnlineLibrary extends library_state.LibraryScreen {
  @override
  Future<void> fetchAllLibraries() async {}
}

Widget harness(
  Widget child, {
  bool offline = true,
  List<SyncedItem> items = const [],
  Stream<List<SyncedItem>>? stream,
}) => ProviderScope(
  overrides: [
    offlineStateProvider.overrideWithValue(offline),
    offlineCatalogProvider.overrideWith((ref) => stream ?? Stream.value(items)),
    dashboardProvider.overrideWith((ref) => throw StateError('Network dashboard accessed')),
    livingHomeProvider.overrideWith((ref) => throw StateError('Network home accessed')),
    library_state.libraryScreenProvider.overrideWith(
      () => offline ? throw StateError('Network library accessed') : _OnlineLibrary(),
    ),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: AdaptiveLayout(
      data: const AdaptiveLayoutModel(
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
      ),
      child: Scaffold(body: child),
    ),
  ),
);

void main() {
  testWidgets('offline dashboard renders local rows without network providers', (tester) async {
    await tester.pumpWidget(
      harness(
        const DashboardScreen(),
        items: [episode('Resuming', userData: const UserData(playbackPositionTicks: 10000000))],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Available offline'), findsOneWidget);
    expect(find.text('Next-up'), findsOneWidget);
    expect(find.text('Resuming'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline library forces local filter and searches series names', (tester) async {
    await tester.pumpWidget(
      harness(
        const LibraryScreen(),
        items: [
          episode('First', series: 'Northern Lights'),
          episode('Second', series: 'Elsewhere'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);
    await tester.enterText(find.byType(TextField), 'northern');
    await tester.pump();
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsNothing);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    expect(find.text('No results'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('Second'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('Available offline can be enabled and disabled while connected', (tester) async {
    await tester.pumpWidget(harness(const LibraryScreen(), offline: false, items: [episode('Download')]));
    await tester.pumpAndSettle();
    expect(find.byType(OfflineCatalogScreen), findsNothing);
    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Reconnect'), findsNothing);
    await tester.tap(find.byType(FilterChip));
    await tester.pumpAndSettle();
    expect(find.byType(OfflineCatalogScreen), findsNothing);
  });

  testWidgets('empty catalog provides reconnect action', (tester) async {
    await tester.pumpWidget(harness(const DashboardScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No downloads available on this device.'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);
  });

  testWidgets('database changes refresh catalog and local favorite filtering', (tester) async {
    final stream = StreamController<List<SyncedItem>>();
    addTearDown(stream.close);
    await tester.pumpWidget(harness(const OfflineCatalogScreen(favorites: true), stream: stream.stream));
    stream.add([episode('Favorite', userData: const UserData(isFavourite: true)), episode('Other')]);
    await tester.pumpAndSettle();
    expect(find.text('Favorite'), findsOneWidget);
    expect(find.text('Other'), findsNothing);
    stream.add([]);
    await tester.pumpAndSettle();
    expect(find.text('Favorite'), findsNothing);
    expect(find.text('No downloads available on this device.'), findsOneWidget);
  });

  testWidgets('catalog failures show retry', (tester) async {
    await tester.pumpWidget(harness(const OfflineCatalogScreen(), stream: Stream.error(StateError('read failed'))));
    await tester.pumpAndSettle();
    expect(find.text('Could not load downloads.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
