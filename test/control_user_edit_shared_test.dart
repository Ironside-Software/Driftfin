import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/screens/control_panel/control_user_edit/control_user_edit_shared.dart';
import 'package:driftfin/screens/home_screen.dart';
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

Widget _harness(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // AdaptiveLayout must wrap the Navigator (via `builder`), not just
      // `home`, because dialogs render into the Navigator's Overlay, which
      // sits alongside `home` rather than beneath it.
      builder: (context, child) => AdaptiveLayout(
        data: _adaptiveModel,
        child: child!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccessSchedulesEditor', () {
    testWidgets('renders empty state when there are no schedules', (tester) async {
      await tester.pumpWidget(_harness(const AccessSchedulesEditor(label: 'Access', schedules: [])));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text('Access'), findsOneWidget);
      expect(find.text(l10n.empty), findsOneWidget);
    });

    testWidgets('renders a list of schedules with remove buttons', (tester) async {
      AccessSchedule? removed;
      final schedules = [
        const AccessSchedule(dayOfWeek: DynamicDayOfWeek.monday, startHour: 8, endHour: 20),
        const AccessSchedule(dayOfWeek: DynamicDayOfWeek.everyday, startHour: 0, endHour: 23),
      ];

      await tester.pumpWidget(_harness(AccessSchedulesEditor(
        label: 'Access',
        schedules: schedules,
        onRemoveSchedule: (schedule) => removed = schedule,
      )));
      await tester.pumpAndSettle();

      final deleteButtons = find.byWidgetPredicate(
          (w) => w is IconButton && w.icon is Icon && (w.icon as Icon).icon == IconsaxPlusBold.trash);
      expect(deleteButtons, findsWidgets);
      await tester.tap(deleteButtons.first);
      await tester.pumpAndSettle();
      expect(removed, isNotNull);
    });

    testWidgets('opens the add-schedule dialog and creates a schedule', (tester) async {
      AccessSchedule? added;
      await tester.pumpWidget(_harness(AccessSchedulesEditor(
        label: 'Access',
        schedules: const [],
        onAddSchedule: (schedule) => added = schedule,
      )));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      expect(find.text(l10n.addAccessSchedule), findsOneWidget);
      await tester.tap(find.text(l10n.create));
      await tester.pumpAndSettle();

      expect(added, isNotNull);
    });

    testWidgets('cancel closes the add-schedule dialog without adding', (tester) async {
      AccessSchedule? added;
      await tester.pumpWidget(_harness(AccessSchedulesEditor(
        label: 'Access',
        schedules: const [],
        onAddSchedule: (schedule) => added = schedule,
      )));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();

      expect(added, isNull);
      expect(find.text(l10n.addAccessSchedule), findsNothing);
    });
  });

  group('TagsEditor', () {
    testWidgets('renders empty state when there are no tags', (tester) async {
      await tester.pumpWidget(_harness(TagsEditor(label: 'Tags', tags: const [], onTagAdded: (_) {})));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.empty), findsOneWidget);
    });

    testWidgets('renders chips for tags and removes one', (tester) async {
      String? removedTag;
      await tester.pumpWidget(_harness(TagsEditor(
        label: 'Tags',
        tags: const ['action', 'drama'],
        onTagAdded: (_) {},
        onTagRemoved: (tag) => removedTag = tag,
      )));
      await tester.pumpAndSettle();

      expect(find.text('action'), findsOneWidget);
      expect(find.text('drama'), findsOneWidget);

      await tester.tap(find.descendant(of: find.widgetWithText(Chip, 'action'), matching: find.byType(Icon)));
      await tester.pumpAndSettle();
      expect(removedTag, 'action');
    });

    testWidgets('adds a tag through the dialog submit action', (tester) async {
      String? addedTag;
      await tester.pumpWidget(_harness(TagsEditor(
        label: 'Tags',
        tags: const [],
        onTagAdded: (tag) => addedTag = tag,
      )));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.byType(IconButton).first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'newTag');
      await tester.tap(find.text(l10n.create));
      await tester.pumpAndSettle();

      expect(addedTag, 'newTag');
    });
  });
}
