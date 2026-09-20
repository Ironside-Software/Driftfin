import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:driftfin/l10n/generated/app_localizations.dart';
import 'package:driftfin/models/account_model.dart';
import 'package:driftfin/models/credentials_model.dart';
import 'package:driftfin/models/seerr_credentials_model.dart';
import 'package:driftfin/models/items/images_models.dart';
import 'package:driftfin/models/seerr/seerr_dashboard_model.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/providers/connectivity_provider.dart';
import 'package:driftfin/screens/seerr/widgets/seerr_request_popup.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout.dart';
import 'package:driftfin/util/adaptive_layout/adaptive_layout_model.dart';
import 'package:driftfin/util/poster_defaults.dart';
import 'package:driftfin/util/seerr_helpers.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:driftfin/providers/seerr/seerr_request_provider.dart';
import 'package:driftfin/providers/seerr/seerr_details_provider.dart';
import 'package:driftfin/seerr/seerr_models.dart';

class _User extends User {
  @override
  AccountModel build() => AccountModel(
    name: 'test',
    id: 'first',
    avatar: '',
    lastUsed: DateTime(2026),
    credentials: CredentialsModel(serverId: 'server'),
    seerrCredentials: const SeerrCredentialsModel(
      serverUrl: 'https://seerr.test',
      apiKey: 'manual',
      origin: CredentialOrigin.manual,
    ),
  );

  @override
  set userState(AccountModel? account) => state = account;
}

class _Details extends SeerrDetails {
  late Future<void> pending;

  @override
  Future<void> fetch() => pending = super.fetch();
}

final _movie = SeerrDashboardPosterModel(
  id: 'movie:550',
  tmdbId: 550,
  type: SeerrMediaType.movie,
  title: 'Movie',
  overview: 'Overview',
  images: ImagesData(),
  mediaStatus: SeerrMediaStatus.unknown,
  jellyfinItemId: null,
);

http.Response _response(http.Request request, int permissions) {
  final path = request.url.path;
  final Object body;
  if (path.endsWith('/auth/me')) {
    body = {'id': 42, 'permissions': permissions};
  } else if (path.endsWith('/movie/550')) {
    body = {'id': 550, 'title': 'Movie'};
  } else if (path.endsWith('/quota')) {
    body = <String, dynamic>{};
  } else if (path.endsWith('/service/radarr')) {
    body = [
      {'id': 1},
      {'id': 2},
    ];
  } else if (path.contains('/service/radarr/')) {
    body = {
      'server': {'id': int.parse(path.split('/').last), 'is4k': path.endsWith('/2'), 'isDefault': true},
    };
  } else if (path.endsWith('/request')) {
    body = {
      'id': 99,
      'status': 1,
      'is4k': true,
      'requestedBy': {'id': 42},
    };
  } else {
    throw StateError('Unexpected fixture route: $path');
  }
  return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('4K-only initialization selects the matching server and submits 4K', () async {
    http.Request? mutation;
    await http.runWithClient(
      () async {
        final container = ProviderContainer(overrides: [userProvider.overrideWith(_User.new)]);
        addTearDown(container.dispose);
        final subscription = container.listen(seerrRequestProvider, (_, _) {});
        addTearDown(subscription.close);
        final notifier = container.read(seerrRequestProvider.notifier);
        await notifier.initialize(_movie);
        final state = container.read(seerrRequestProvider);
        expect(state.use4k, isTrue);
        expect(state.selectedRadarrServer?.id, 2);
        expect(state.availableServers, hasLength(1));
        expect(state.canSubmitRequest, isTrue);
        notifier.toggle4k(false);
        expect(container.read(seerrRequestProvider).use4k, isTrue);
        await notifier.submitRequest();
        expect(mutation, isNotNull);
        expect(jsonDecode(mutation!.body)['is4k'], isTrue);
        expect(jsonDecode(mutation!.body)['serverId'], 2);
      },
      () => MockClient((request) async {
        if (request.method == 'POST') mutation = request;
        return _response(request, SeerrPermission.request4kMovie.bit);
      }),
    );
  });

  test('late initialization cannot restore another account’s request state', () async {
    final reachedDetails = Completer<void>();
    final pending = Completer<http.Response>();
    await http.runWithClient(
      () async {
        final container = ProviderContainer(overrides: [userProvider.overrideWith(_User.new)]);
        addTearDown(container.dispose);
        final subscription = container.listen(seerrRequestProvider, (_, _) {});
        addTearDown(subscription.close);
        final initialize = container.read(seerrRequestProvider.notifier).initialize(_movie);
        await reachedDetails.future;
        container.read(userProvider.notifier).userState = container.read(userProvider)!.copyWith(id: 'second');
        await container.pump();
        pending.complete(http.Response('{"id":550}', 200));
        await initialize;
        expect(container.read(seerrRequestProvider).poster, isNull);
        expect(container.read(seerrRequestProvider).currentUser, isNull);
      },
      () => MockClient((request) async {
        if (request.url.path.endsWith('/movie/550')) {
          reachedDetails.complete();
          return pending.future;
        }
        return _response(request, SeerrPermission.requestMovie.bit);
      }),
    );
  });

  test('closing the request popup discards pending details safely', () async {
    final reachedDetails = Completer<void>();
    final pending = Completer<http.Response>();
    await http.runWithClient(
      () async {
        final container = ProviderContainer(overrides: [userProvider.overrideWith(_User.new)]);
        addTearDown(container.dispose);
        final subscription = container.listen(seerrRequestProvider, (_, _) {});
        final initialize = container.read(seerrRequestProvider.notifier).initialize(_movie);
        await reachedDetails.future;
        subscription.close();
        await container.pump();
        expect(container.exists(seerrRequestProvider), isFalse);
        pending.complete(http.Response('{"id":550}', 200));
        await initialize;
        expect(container.exists(seerrRequestProvider), isFalse);
      },
      () => MockClient((request) async {
        if (request.url.path.endsWith('/movie/550')) {
          reachedDetails.complete();
          return pending.future;
        }
        return _response(request, SeerrPermission.requestMovie.bit);
      }),
    );
  });

  test('details retain the latest media state after recommendations finish', () async {
    final details = _Details();
    final provider = seerrDetailsProvider(tmdbId: 550, mediaType: SeerrMediaType.movie);
    var detailCalls = 0;
    await http.runWithClient(
      () async {
        final container = ProviderContainer(
          overrides: [
            userProvider.overrideWith(_User.new),
            offlineStateProvider.overrideWith((ref) => false),
            provider.overrideWith(() => details),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        await details.pending;
        expect(container.read(provider).poster?.mediaInfo?.status, 2);
        expect(container.read(provider).currentUser?.id, 42);
      },
      () => MockClient((request) async {
        if (request.url.path.endsWith('/movie/550')) {
          return http.Response(
            jsonEncode({
              'id': 550,
              'title': 'Movie',
              'mediaInfo': {'status': ++detailCalls},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/auth/me')) return _response(request, SeerrPermission.requestMovie.bit);
        return http.Response('{}', 200, headers: {'content-type': 'application/json'});
      }),
    );
  });

  for (final fail in [false, true]) {
    test('closing details ignores a late ${fail ? 'error' : 'response'}', () async {
      final reachedDetails = Completer<void>();
      final pending = Completer<http.Response>();
      final details = _Details();
      final provider = seerrDetailsProvider(tmdbId: 550, mediaType: SeerrMediaType.movie);
      await http.runWithClient(
        () async {
          final container = ProviderContainer(
            overrides: [
              userProvider.overrideWith(_User.new),
              offlineStateProvider.overrideWith((ref) => false),
              provider.overrideWith(() => details),
            ],
          );
          addTearDown(container.dispose);
          final subscription = container.listen(provider, (_, _) {});
          await reachedDetails.future;
          subscription.close();
          await container.pump();
          expect(container.exists(provider), isFalse);
          if (fail) {
            pending.completeError(StateError('late failure'));
          } else {
            pending.complete(http.Response('{"id":550,"title":"Old account"}', 200));
          }
          await details.pending;
          expect(container.exists(provider), isFalse);
        },
        () => MockClient((request) async {
          reachedDetails.complete();
          return pending.future;
        }),
      );
    });
  }

  test('account change clears details and ignores the previous account response', () async {
    final reachedDetails = Completer<void>();
    final pending = Completer<http.Response>();
    final details = _Details();
    final provider = seerrDetailsProvider(tmdbId: 550, mediaType: SeerrMediaType.movie, poster: _movie);
    var calls = 0;
    await http.runWithClient(
      () async {
        final container = ProviderContainer(
          overrides: [
            userProvider.overrideWith(_User.new),
            offlineStateProvider.overrideWith((ref) => false),
            provider.overrideWith(() => details),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        await reachedDetails.future;
        final oldFetch = details.pending;
        container.read(userProvider.notifier).userState = container.read(userProvider)!.copyWith(id: 'second');
        await container.pump();
        await details.pending;
        expect(container.read(provider).poster, isNull);
        pending.complete(http.Response('{"id":550,"title":"Old account"}', 200));
        await oldFetch;
        expect(container.read(provider).poster, isNull);
        expect(container.read(provider).currentUser, isNull);
      },
      () => MockClient((request) async {
        if (++calls == 1) {
          reachedDetails.complete();
          return pending.future;
        }
        return http.Response('{}', 404);
      }),
    );
  });

  test('normal season availability and requests do not block 4K selection', () {
    final details = SeerrTvDetails(
      seasons: [SeerrSeason(seasonNumber: 1), SeerrSeason(seasonNumber: 2)],
      mediaInfo: SeerrMediaInfo(
        seasons: [
          SeerrMediaInfoSeason.fromJson({'seasonNumber': 1, 'status': 5, 'status4k': 1}),
        ],
        requests: [
          SeerrMediaRequest.fromJson({
            'id': 1,
            'status': 2,
            'is4k': false,
            'seasons': [1],
          }),
          SeerrMediaRequest.fromJson({
            'id': 2,
            'status': 1,
            'is4k': true,
            'seasons': [2],
          }),
        ],
      ),
    );
    final normal = SeerrHelpers.buildSeasonStatusMap(details);
    final fourK = SeerrHelpers.buildSeasonStatusMap(details, is4k: true);
    expect(normal[1], SeerrMediaStatus.available);
    expect(normal[2], isNull);
    expect(fourK[1], SeerrMediaStatus.unknown);
    expect(fourK[2], SeerrMediaStatus.pending);
  });

  testWidgets('regular requesters can select 4K without advanced management rights', (tester) async {
    final paths = <String>[];
    await http.runWithClient(
      () async {
        final container = ProviderContainer(overrides: [userProvider.overrideWith(_User.new)]);
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: AdaptiveLayout(
                data: const AdaptiveLayoutModel(
                  viewSize: ViewSize.desktop,
                  layoutMode: LayoutMode.single,
                  inputDevice: InputDevice.pointer,
                  platform: TargetPlatform.windows,
                  isDesktop: true,
                  posterDefaults: PosterDefaults(size: 350, ratio: .55),
                  controller: {},
                  sideBarWidth: 0,
                  topBarHeight: 0,
                  statusBarHeight: 0,
                ),
                child: Scaffold(body: SeerrRequestPopup(requestModel: _movie)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          container.read(seerrRequestProvider).currentUser,
          isNotNull,
          reason: 'Popup initialization must finish before quality selection: $paths',
        );
        expect(find.text('4K'), findsOneWidget);
        expect(container.read(seerrRequestProvider).use4k, isFalse);
        await tester.tap(find.text('4K'));
        await tester.pumpAndSettle();
        expect(container.read(seerrRequestProvider).use4k, isTrue);
        expect(container.read(seerrRequestProvider).selectedRadarrServer?.id, 2);
        expect(container.read(seerrRequestProvider).canSubmitRequest, isTrue);
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        paths.add(request.url.path);
        return _response(request, SeerrPermission.requestMovie.bit | SeerrPermission.request4kMovie.bit);
      }),
    );
  });

  test('an existing normal movie does not hide the 4K request action', () {
    final owned = _movie.copyWith(mediaStatus: SeerrMediaStatus.available);
    expect(
      SeerrDetailsModel(
        mediaType: SeerrMediaType.movie,
        poster: owned,
        currentUser: SeerrUserModel(id: 1, permissions: SeerrPermission.request4kMovie.bit),
      ).canRequestMore,
      isTrue,
    );
    expect(
      SeerrDetailsModel(
        mediaType: SeerrMediaType.movie,
        poster: owned,
        currentUser: SeerrUserModel(id: 1, permissions: SeerrPermission.requestMovie.bit),
      ).canRequestMore,
      isFalse,
    );
  });

  test('4K-only permissions expose request actions for the permitted media type', () {
    final movieUser = SeerrUserModel(id: 1, permissions: SeerrPermission.request4kMovie.bit);
    final tvUser = SeerrUserModel(id: 2, permissions: SeerrPermission.request4kTv.bit);
    expect(movieUser.canRequestMedia(isTv: false), isTrue);
    expect(movieUser.canRequestMedia(isTv: true), isFalse);
    expect(tvUser.canRequestMedia(isTv: true), isTrue);
    expect(tvUser.canRequestMedia(isTv: false), isFalse);
  });

  test('request submission checks permissions for the selected quality', () {
    const fourK = SeerrRadarrServer(id: 2, is4k: true);
    final fourKUser = SeerrUserModel(id: 1, permissions: SeerrPermission.request4kMovie.bit);
    final normalUser = SeerrUserModel(id: 2, permissions: SeerrPermission.requestMovie.bit);
    expect(
      SeerrRequestModel(currentUser: fourKUser, selectedRadarrServer: fourK, use4k: true).hasRequestPermission,
      isTrue,
    );
    expect(
      SeerrRequestModel(currentUser: normalUser, selectedRadarrServer: fourK, use4k: true).hasRequestPermission,
      isFalse,
    );
    expect(SeerrRequestModel(currentUser: fourKUser).hasRequestPermission, isFalse);
  });
}
