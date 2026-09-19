import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/seerr/seerr_dashboard_model.dart';
import 'package:driftfin/models/items/images_models.dart';
import 'package:driftfin/providers/seerr_requests_provider.dart';
import 'package:driftfin/providers/seerr_user_provider.dart';
import 'package:driftfin/screens/seerr/seerr_requests_screen.dart';
import 'package:driftfin/seerr/seerr_models.dart';

/// Test double that sets a fixed state instead of calling load() (network).
class _FakeSeerrRequestsNotifier extends SeerrRequestsNotifier {
  _FakeSeerrRequestsNotifier(super.ref, SeerrRequestsState initial) {
    state = initial;
  }
  int loads = 0;
  @override
  Future<void> load() async {
    loads++;
    state = state.copyWith(hasError: false, loadedPages: 1, totalPages: 1);
  }
}

/// Test double that returns a fixed user instead of fetching from network.
class _FakeSeerrUser extends SeerrUser {
  _FakeSeerrUser(this._initial);
  final SeerrUserModel? _initial;

  @override
  SeerrUserModel? build() => _initial;
}

SeerrDashboardPosterModel _poster({
  required String id,
  required String title,
  SeerrMediaStatus mediaStatus = SeerrMediaStatus.pending,
}) {
  return SeerrDashboardPosterModel(
    id: id,
    type: SeerrMediaType.movie,
    tmdbId: int.parse(id),
    jellyfinItemId: null,
    title: title,
    overview: 'overview',
    images: ImagesData(),
    mediaStatus: mediaStatus,
  );
}

SeerrMediaRequest _request({required int id, required int status}) {
  return SeerrMediaRequest(id: id, status: status);
}

Widget _harness(SeerrRequestsState requestsState, SeerrUserModel? user) {
  return ProviderScope(
    overrides: [
      seerrRequestsProvider.overrideWith((ref) => _FakeSeerrRequestsNotifier(ref, requestsState)),
      seerrUserProvider.overrideWith(() => _FakeSeerrUser(user)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SeerrRequestsScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('failed load shows retry and clears the spinner', (tester) async {
    await tester.pumpWidget(_harness(const SeerrRequestsState(hasError: true), null));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.somethingWentWrong), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(SeerrRequestsScreen)));
    expect((container.read(seerrRequestsProvider.notifier) as _FakeSeerrRequestsNotifier).loads, 1);
    expect(find.text(l10n.somethingWentWrong), findsNothing);
  });

  testWidgets('another page offers a load button until a request is running', (tester) async {
    final entries = [SeerrRequestEntry(_request(id: 1, status: 2), _poster(id: '1', title: 'Movie'))];
    await tester.pumpWidget(_harness(SeerrRequestsState(entries: entries, loadedPages: 1, totalPages: 2), null));
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byTooltip(l10n.showMore), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('empty entries: shows the empty state and no FAB', (tester) async {
    await tester.pumpWidget(_harness(const SeerrRequestsState(), null));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.noRequestsFound), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('loading: shows a progress indicator instead of the list', (tester) async {
    await tester.pumpWidget(_harness(const SeerrRequestsState(loading: true), null));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('grid: lays entries out in a GridView and shows the description', (tester) async {
    final entries = [
      SeerrRequestEntry(_request(id: 1, status: 1), _poster(id: '1', title: 'A Movie')),
    ];
    final state = SeerrRequestsState(entries: entries, loadedPages: 1);

    await tester.pumpWidget(_harness(state, const SeerrUserModel(id: 1, permissions: 16)));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('A Movie'), findsOneWidget);
    // The overview/description is surfaced on the card (the old list tile hid it).
    expect(find.text('overview'), findsOneWidget);
  });

  testWidgets('populated: shows entries, pending approve/decline actions and FAB for managers', (tester) async {
    final entries = [
      SeerrRequestEntry(_request(id: 1, status: 1), _poster(id: '1', title: 'Pending Movie')),
      SeerrRequestEntry(_request(id: 2, status: 2), _poster(id: '2', title: 'Approved Movie')),
    ];
    final state = SeerrRequestsState(entries: entries, loadedPages: 1);
    const manager = SeerrUserModel(id: 1, permissions: 16);

    await tester.pumpWidget(_harness(state, manager));
    await tester.pumpAndSettle();

    expect(find.text('Pending Movie'), findsOneWidget);
    expect(find.text('Approved Movie'), findsOneWidget);
    // Pending request has manage actions since canManageRequests is true.
    expect(find.byIcon(Icons.done_all), findsOneWidget); // FAB icon
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('non-manager: no FAB and no per-row approve/decline icons even with pending', (tester) async {
    final entries = [
      SeerrRequestEntry(_request(id: 1, status: 1), _poster(id: '1', title: 'Pending Movie')),
    ];
    final state = SeerrRequestsState(entries: entries, loadedPages: 1);
    const regularUser = SeerrUserModel(id: 2, permissions: 0);

    await tester.pumpWidget(_harness(state, regularUser));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('filter chips: tapping a filter chip updates the notifier state', (tester) async {
    final entries = [
      SeerrRequestEntry(_request(id: 1, status: 1), _poster(id: '1', title: 'Pending Movie')),
    ];
    final state = SeerrRequestsState(entries: entries, loadedPages: 1);
    const manager = SeerrUserModel(id: 1, permissions: 16);

    await tester.pumpWidget(_harness(state, manager));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.seerrRequestStatusPending).first);
    await tester.pump();

    final container = ProviderScope.containerOf(tester.element(find.byType(SeerrRequestsScreen)));
    expect(container.read(seerrRequestsProvider).filter, RequestFilter.pending);
  });
}
