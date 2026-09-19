import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/user_provider.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/items/images_models.dart';
import 'package:driftfin/models/seerr/seerr_dashboard_model.dart';
import 'package:driftfin/providers/seerr_user_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/seerr/widgets/seerr_poster_card.dart';
import 'package:driftfin/seerr/seerr_models.dart';
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

/// Fake notifier so we never hit the Jellyseerr network API through
/// [seerrUserProvider]'s real `build()`.
class _FakeSeerrUser extends SeerrUser {
  _FakeSeerrUser(this._value);
  final SeerrUserModel? _value;

  @override
  SeerrUserModel? build() => _value;
}

late SharedPreferences _prefs;

class _User extends User {
  @override
  AccountModel build() => AccountModel(
        name: 'Test',
        id: 'user',
        avatar: '',
        lastUsed: DateTime(2026),
        credentials: CredentialsModel.internal(serverId: 'server'),
      );
}

final _availablePoster = SeerrDashboardPosterModel(
  id: 'req-1',
  type: SeerrMediaType.movie,
  tmdbId: 1,
  jellyfinItemId: null,
  title: 'Available Movie',
  overview: '',
  images: ImagesData(),
  mediaStatus: SeerrMediaStatus.available,
);

final _requestablePoster = SeerrDashboardPosterModel(
  id: '',
  type: SeerrMediaType.tvshow,
  tmdbId: 2,
  jellyfinItemId: null,
  title: 'Requestable Show',
  overview: '',
  images: ImagesData(),
  mediaStatus: SeerrMediaStatus.unknown,
);

Widget _harness(SeerrDashboardPosterModel poster, {SeerrUserModel? user}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(_prefs),
      userProvider.overrideWith(_User.new),
      seerrUserProvider.overrideWith(() => _FakeSeerrUser(user)),
    ],
    // AdaptiveLayout must wrap MaterialApp (as it does in lib/main.dart) so
    // that modal routes pushed on the root navigator (e.g. showBottomSheetPill,
    // which uses useRootNavigator: true) still see it via context.
    child: AdaptiveLayout(
      data: _adaptiveModel,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 300,
              child: SeerrPosterCard(poster: poster),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('movie card marks watched and unwatched without navigating', (tester) async {
    await tester.pumpWidget(_harness(_availablePoster));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.byTooltip(RegExp(l10n.markAsWatched)));
    await tester.pumpAndSettle();
    expect(find.byTooltip(RegExp(l10n.markAsUnwatched)), findsOneWidget);
    expect(_prefs.getKeys().where((key) => key.startsWith('discoverWatched:')), hasLength(1));
    await tester.tap(find.byTooltip(RegExp(l10n.markAsUnwatched)));
    await tester.pumpAndSettle();
    expect(find.byTooltip(RegExp(l10n.markAsWatched)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a poster with a display status badge', (tester) async {
    await tester.pumpWidget(_harness(_availablePoster));
    await tester.pumpAndSettle();

    expect(find.text('Available Movie'), findsWidgets);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('renders a poster without a display status', (tester) async {
    await tester.pumpWidget(_harness(_requestablePoster));
    await tester.pumpAndSettle();

    expect(find.text('Requestable Show'), findsWidgets);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('long-press opens the bottom sheet with item actions', (tester) async {
    await tester.pumpWidget(_harness(_availablePoster));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(SeerrPosterCard));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsWidgets);
  });
}
