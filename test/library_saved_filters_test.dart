import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/models/library_filters_model.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/library_search/widgets/library_saved_filters.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';

const _testLayoutModel = AdaptiveLayoutModel(
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

class _FakeUser extends User {
  _FakeUser(this.initial);
  final AccountModel? initial;

  @override
  AccountModel? build() {
    ref.onDispose(debouncer.dispose);
    return initial;
  }
}

AccountModel _accountWithFilters(List<LibraryFiltersModel> filters) {
  return AccountModel(
    name: 'test',
    id: 'user-id',
    avatar: '',
    lastUsed: DateTime(2024),
    credentials: CredentialsModel(url: 'http://server'),
    libraryFilters: filters,
  );
}

Future<SharedPreferences> _mockPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Future<ProviderContainer> _containerWith(List<LibraryFiltersModel> filters) async {
  final prefs = await _mockPrefs();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userProvider.overrideWith(() => _FakeUser(_accountWithFilters(filters))),
    ],
  );
}

Widget _harness(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const AdaptiveLayout(
      data: _testLayoutModel,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _OpenButton()),
      ),
    ),
  );
}

class _OpenButton extends StatelessWidget {
  const _OpenButton();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => showSavedFilters(context, const ValueKey('saved-filters')),
      child: const Text('open'),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows a home-shelf toggle for each saved filter', (tester) async {
    final filter = LibraryFiltersModel(id: 'f1', name: 'Unwatched Sci-Fi', isFavourite: false, showOnHome: false);
    final container = await _containerWith([filter]);
    addTearDown(container.dispose);

    await tester.pumpWidget(_harness(container));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.addToHomeShelf), findsOneWidget);
  });

  testWidgets('shows the remove action once the filter is already a home shelf', (tester) async {
    final filter = LibraryFiltersModel(id: 'f1', name: 'Unwatched Sci-Fi', isFavourite: false, showOnHome: true);
    final container = await _containerWith([filter]);
    addTearDown(container.dispose);

    await tester.pumpWidget(_harness(container));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.removeFromHomeShelf), findsOneWidget);
  });

  testWidgets('tapping the toggle saves the filter with showOnHome flipped', (tester) async {
    final filter = LibraryFiltersModel(id: 'f1', name: 'Unwatched Sci-Fi', isFavourite: false, showOnHome: false);
    final container = await _containerWith([filter]);
    addTearDown(container.dispose);

    await tester.pumpWidget(_harness(container));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.addToHomeShelf));
    await tester.pumpAndSettle();

    final saved = container.read(userProvider)?.libraryFilters.first;
    expect(saved?.showOnHome, isTrue);
    container.read(userProvider.notifier).debouncer.dispose();
  });
}
