import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/items/images_models.dart';
import 'package:driftfin/models/seerr/seerr_dashboard_model.dart';
import 'package:driftfin/providers/seerr_user_provider.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/seerr/seerr_media_management.dart';
import 'package:driftfin/seerr/seerr_models.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';

/// Test double that returns a fixed user instead of fetching from network.
class _FakeSeerrUser extends SeerrUser {
  _FakeSeerrUser(this._initial);
  final SeerrUserModel? _initial;

  @override
  SeerrUserModel? build() => _initial;
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

SeerrDashboardPosterModel _poster({SeerrMediaInfo? mediaInfo}) {
  return SeerrDashboardPosterModel(
    id: '1',
    type: SeerrMediaType.movie,
    tmdbId: 1,
    jellyfinItemId: null,
    title: 'Some Movie',
    overview: 'overview',
    images: ImagesData(),
    mediaStatus: SeerrMediaStatus.pending,
    mediaInfo: mediaInfo,
  );
}

Widget _harness(SeerrDashboardPosterModel poster, SeerrUserModel? user) {
  return ProviderScope(
    overrides: [
      seerrUserProvider.overrideWith(() => _FakeSeerrUser(user)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AdaptiveLayout(
        data: _phoneModel,
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showMediaManagementSheet(
                context: context,
                mediaInfo: poster,
                onActionComplete: () {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mediaInfo null: renders the unknown text', (tester) async {
    await tester.pumpWidget(_harness(_poster(mediaInfo: null), null));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.unknown), findsOneWidget);
  });

  testWidgets('manager user with serviceUrl: extra manage buttons render', (tester) async {
    final mediaInfo = SeerrMediaInfo(id: 1, tmdbId: 1, serviceUrl: 'https://sonarr.example.com');
    const manager = SeerrUserModel(id: 1, permissions: 16);

    await tester.pumpWidget(_harness(_poster(mediaInfo: mediaInfo), manager));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // Basic actions always present.
    expect(find.text(l10n.openInSeerr), findsOneWidget);
    // Manager-only actions gated behind canManageRequests + serviceUrl.
    expect(find.text(l10n.openInRadarr), findsOneWidget);
    expect(find.text(l10n.removeFromRadarr), findsOneWidget);
    expect(find.text(l10n.markAsAvailable), findsOneWidget);
    expect(find.text(l10n.deleteData), findsOneWidget);
  });

  testWidgets('non-manager user: manage-only buttons are absent', (tester) async {
    final mediaInfo = SeerrMediaInfo(id: 1, tmdbId: 1, serviceUrl: 'https://sonarr.example.com');
    const regularUser = SeerrUserModel(id: 2, permissions: 0);

    await tester.pumpWidget(_harness(_poster(mediaInfo: mediaInfo), regularUser));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.openInSeerr), findsOneWidget);
    expect(find.text(l10n.openInRadarr), findsNothing);
    expect(find.text(l10n.removeFromRadarr), findsNothing);
    expect(find.text(l10n.deleteData), findsNothing);
  });
}
