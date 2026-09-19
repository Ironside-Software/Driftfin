import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:driftfin/jellyfin/jellyfin_open_api.swagger.dart';
import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/models/discovery_search.dart';
import 'package:driftfin/models/item_base_model.dart';
import 'package:driftfin/models/library_filter_model.dart';
import 'package:driftfin/models/library_search/library_search_model.dart';
import 'package:driftfin/models/plugin_capabilities.dart';
import 'package:driftfin/models/server_integration_config.dart';
import 'package:driftfin/providers/api_provider.dart';
import 'package:driftfin/providers/discovery_search_provider.dart';
import 'package:driftfin/providers/library_search_provider.dart';
import 'package:driftfin/providers/seerr_user_provider.dart';
import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:driftfin/providers/shared_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/routes/auto_router.gr.dart';
import 'package:driftfin/screens/home_screen.dart';
import 'package:driftfin/screens/seerr/widgets/seerr_poster_card.dart';
import 'package:driftfin/screens/shared/media/poster_widget.dart';
import 'package:driftfin/seerr/seerr_models.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';

class _Router extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [AutoRoute(page: LibrarySearchRoute.page, initial: true)];
}

class _User extends User {
  @override
  AccountModel build() => AccountModel(
    id: 'alice',
    name: 'Alice',
    avatar: '',
    lastUsed: DateTime(2026),
    credentials: CredentialsModel(serverId: 'server', url: 'https://jellyfin.test', token: 'session'),
  );
  @override
  void addSearchQuery(String value) {}
}

class _SeerrUser extends SeerrUser {
  @override
  SeerrUserModel? build() => null;
}

class _Config extends ServerIntegrationConfigNotifier {
  _Config(super.ref) {
    state = ServerIntegrationConfig.managed(
      const PluginCapabilities(
        protocolVersion: 1,
        features: {'discovery': PluginFeature(supported: true, allowed: true)},
      ),
    );
  }
}

class _Library extends LibrarySearchNotifier {
  _Library(super.ref, {bool filtered = false}) {
    state = LibrarySearchModel(
      filters: LibraryFilterModel(searchQuery: 'movie', favourites: filtered ? true : null),
      posters: [
        ItemBaseModel.fromBaseDto(
          const BaseItemDto(id: 'owned', name: 'Owned movie', type: BaseItemKind.movie, providerIds: {'Tmdb': '550'}),
          null,
        ),
      ],
    );
  }
  @override
  Future<void> initRefresh({required List<String> parentIds, LibraryFilterModel? filters}) async {}
  @override
  Future<void> loadMore({bool? init}) async {}
  @override
  Future<List<ItemBaseModel>> fetchSuggestions(String searchTerm, {int limit = 25}) async => [];
}

const _layout = AdaptiveLayoutModel(
  viewSize: ViewSize.desktop,
  layoutMode: LayoutMode.single,
  inputDevice: InputDevice.touch,
  platform: TargetPlatform.linux,
  isDesktop: true,
  posterDefaults: PosterDefaults(size: 350, ratio: 0.55),
  controller: <HomeTabs, ScrollController>{},
  sideBarWidth: 0,
  topBarHeight: 0,
  statusBarHeight: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester, {
    bool filtered = false,
    bool failure = false,
    bool phone = false,
    bool duplicateFirstPage = false,
    List<http.Request>? requests,
  }) async {
    tester.view.physicalSize = phone ? const Size(390, 844) : const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final router = _Router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProvider.overrideWith(_User.new),
          seerrUserProvider.overrideWith(_SeerrUser.new),
          sharedPreferencesProvider.overrideWithValue(preferences),
          serverUrlProvider.overrideWith((_) => 'https://jellyfin.test'),
          serverIntegrationConfigProvider.overrideWith(_Config.new),
          librarySearchProvider(const ValueKey('EmptySearch')).overrideWith((ref) => _Library(ref, filtered: filtered)),
          discoverySearchProvider.overrideWith(
            (ref, query) => DiscoverySearchNotifier(
              ref,
              query,
              client: MockClient((request) async {
                requests?.add(request);
                return failure
                    ? http.Response('', 502)
                    : http.Response(
                        jsonEncode({
                          'page': int.parse(request.url.queryParameters['page']!),
                          'totalPages': duplicateFirstPage ? 2 : 1,
                          'results': [
                            {
                              'tmdbId': 550,
                              'mediaType': 'movie',
                              'title': 'Owned catalog duplicate',
                              'libraryItemId': 'owned',
                              'availability': 'available',
                              'canPlay': true,
                            },
                            if (!duplicateFirstPage || request.url.queryParameters['page'] == '2')
                              {
                                'tmdbId': 680,
                                'mediaType': 'movie',
                                'title': 'New movie',
                                'availability': 'requestable',
                                'canRequest': true,
                              },
                          ],
                        }),
                        200,
                      );
              }),
            ),
          ),
        ],
        child: AdaptiveLayout(
          data: phone ? _layout.copyWith(viewSize: ViewSize.phone, isDesktop: false) : _layout,
          child: MaterialApp.router(
            routerConfig: router.config(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('active search combines library and catalog once and switches scopes', (tester) async {
    await pump(tester);
    expect(find.byType(PosterWidget), findsOneWidget);
    expect(find.byType(SeerrPosterCard), findsOneWidget);
    expect(find.text('Owned catalog duplicate'), findsNothing);
    expect(find.text('Requestable'), findsOneWidget);
    final scopes = find.byType(SegmentedButton<SearchScope>);
    await tester.tap(find.descendant(of: scopes, matching: find.text('Discover')));
    await tester.pumpAndSettle();
    expect(find.byType(PosterWidget), findsNothing);
    expect(find.byType(SeerrPosterCard), findsNWidgets(2));
    await tester.tap(find.descendant(of: scopes, matching: find.text('Library')));
    await tester.pumpAndSettle();
    expect(find.byType(PosterWidget), findsOneWidget);
    expect(find.byType(SeerrPosterCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('discovery outage leaves library cards and a retry action visible', (tester) async {
    await pump(tester, failure: true);
    expect(find.byType(PosterWidget), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(SeerrPosterCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clearing a typed query removes results from both sources', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byType(PosterWidget), findsNothing);
    expect(find.byType(SeerrPosterCard), findsNothing);
  });

  testWidgets('advanced filters stay in Library mode', (tester) async {
    await pump(tester, filtered: true);
    final control = tester.widget<SegmentedButton<SearchScope>>(find.byType(SegmentedButton<SearchScope>));
    expect(control.selected, {SearchScope.library});
    expect(
      control.segments.where((segment) => segment.value != SearchScope.library).every((segment) => !segment.enabled),
      isTrue,
    );
    expect(find.byType(SeerrPosterCard), findsNothing);
  });

  testWidgets('scope controls and discovery cards fit a phone viewport', (tester) async {
    await pump(tester, phone: true);
    final scopes = find.byType(SegmentedButton<SearchScope>);
    await tester.tap(find.descendant(of: scopes, matching: find.text('Discover')));
    await tester.pumpAndSettle();
    expect(find.byType(SeerrPosterCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a duplicate-only catalog page still offers the next page', (tester) async {
    await pump(tester, duplicateFirstPage: true);
    expect(find.byType(SeerrPosterCard), findsNothing);
    await tester.tap(find.text('More discovery results'));
    await tester.pumpAndSettle();
    expect(find.byType(SeerrPosterCard), findsOneWidget);
    expect(find.text('More discovery results'), findsNothing);
  });

  testWidgets('refresh reloads discovery without resubmitting a request', (tester) async {
    final requests = <http.Request>[];
    await pump(tester, requests: requests);
    expect(requests, hasLength(1));
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(requests.every((request) => request.method == 'GET' && request.url.queryParameters['page'] == '1'), isTrue);
  });
}
