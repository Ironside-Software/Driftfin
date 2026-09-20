import 'package:driftfin/providers/server_integration_config_provider.dart';
import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:driftfin/models/api_result.dart';
import 'package:driftfin/models/seerr/seerr_dashboard_model.dart';
import 'package:driftfin/providers/seerr_api_provider.dart';
import 'package:driftfin/providers/seerr_user_provider.dart';
import 'package:driftfin/providers/user_provider.dart';
import 'package:driftfin/seerr/seerr_models.dart';
import 'package:driftfin/util/seerr_helpers.dart';

part 'seerr_request_provider.freezed.dart';
part 'seerr_request_provider.g.dart';

@riverpod
class SeerrRequest extends _$SeerrRequest {
  late final api = ref.read(seerrApiProvider);
  int _generation = 0;

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  @override
  SeerrRequestModel build() {
    _generation++;
    ref.watch(userProvider.select((user) => (user?.id, user?.credentials.serverId, user?.credentials.token)));
    return SeerrRequestModel();
  }

  Future<void> initialize(SeerrDashboardPosterModel poster) async {
    final generation = ++_generation;
    try {
      state = SeerrRequestModel(poster: poster);

      final currentUserBody = await ref.read(seerrUserProvider.notifier).refreshUser();
      if (!_isCurrent(generation)) return;
      final isTv = poster.type == SeerrMediaType.tvshow;
      final use4k =
          currentUserBody?.canRequestMedia(isTv: isTv, is4k: false) != true &&
          currentUserBody?.canRequestMedia(isTv: isTv, is4k: true) == true;
      state = state.copyWith(currentUser: currentUserBody, selectedUser: currentUserBody, use4k: use4k);

      SeerrDashboardPosterModel updatedPoster = poster;
      if (isTv) {
        final tvDetailsResponse = await api.tvDetails(tvId: poster.tmdbId);
        if (!_isCurrent(generation)) return;
        if (tvDetailsResponse.isSuccessful && tvDetailsResponse.body != null) {
          final details = tvDetailsResponse.body!;

          final isAnime = SeerrHelpers.isAnime(details);
          final seasonStatusMap = SeerrHelpers.buildSeasonStatusMap(details, is4k: state.use4k);

          updatedPoster = poster.copyWith(
            seasons: details.seasons,
            seasonStatuses: seasonStatusMap.isEmpty ? poster.seasonStatuses : seasonStatusMap,
            mediaInfo: details.mediaInfo,
          );
          final userRegion = currentUserBody?.settings?.discoverRegion ?? 'US';
          final contentRating = SeerrHelpers.extractContentRating(details.contentRatings, userRegion);
          state = state.copyWith(
            poster: updatedPoster,
            isAnime: isAnime,
            genres: details.genres ?? [],
            voteAverage: details.voteAverage,
            contentRating: contentRating,
            releaseDate: details.firstAirDate,
          );
        }
      } else if (!isTv) {
        final movieDetailsResponse = await api.movieDetails(tmdbId: poster.tmdbId);
        if (!_isCurrent(generation)) return;
        if (movieDetailsResponse.isSuccessful && movieDetailsResponse.body != null) {
          final details = movieDetailsResponse.body!;
          updatedPoster = poster.copyWith(mediaInfo: details.mediaInfo);
          final userRegion = currentUserBody?.settings?.discoverRegion ?? 'US';
          final contentRating = SeerrHelpers.extractContentRating(details.contentRatings, userRegion);
          state = state.copyWith(
            poster: updatedPoster,
            genres: details.genres ?? [],
            voteAverage: details.voteAverage,
            contentRating: contentRating,
            releaseDate: details.releaseDate,
          );
        }
      }

      if (isTv) {
        _initializeSeasonSelection(updatedPoster);
      }

      await _loadQuotaForUser(currentUserBody?.id, force: true);
      if (!_isCurrent(generation)) return;

      if (isTv) {
        final loaded = await api.sonarrServers();
        if (!_isCurrent(generation)) return;
        final servers = loaded
            .where((server) => currentUserBody?.canRequestMedia(isTv: isTv, is4k: server.is4k == true) == true)
            .toList();
        final nextState = state.copyWith(sonarrServers: servers, use4k: state.use4k);
        final selectedServer = nextState.activeSonarr;
        state = nextState.copyWith(
          selectedSonarrServer: selectedServer,
          selectedProfile: nextState.pickProfileForServer(selectedServer),
          selectedRootFolder: nextState.pickRootFolderForServer(selectedServer),
          currentUser: currentUserBody,
          selectedUser: currentUserBody,
        );
      } else {
        final loaded = await api.radarrServers();
        if (!_isCurrent(generation)) return;
        final servers = loaded
            .where((server) => currentUserBody?.canRequestMedia(isTv: isTv, is4k: server.is4k == true) == true)
            .toList();
        final nextState = state.copyWith(radarrServers: servers, use4k: state.use4k);
        final selectedServer = nextState.activeRadarr;
        state = nextState.copyWith(
          selectedRadarrServer: selectedServer,
          selectedProfile: nextState.pickProfileForServer(selectedServer),
          selectedRootFolder: nextState.pickRootFolderForServer(selectedServer),
          currentUser: currentUserBody,
          selectedUser: currentUserBody,
        );
      }
    } catch (_) {
      if (_isCurrent(generation)) rethrow;
    }
  }

  Future<void> loadUsers() async {
    final generation = _generation;
    final users = await api.users();
    if (!_isCurrent(generation)) return;
    state = state.copyWith(availableUsers: users);
  }

  Future<void> _loadQuotaForUser(int? userId, {bool force = false}) async {
    if (userId == null) return;
    if (!force && state.userQuotas.containsKey(userId)) return;

    final generation = _generation;
    final quota = await api.userQuota(userId: userId);
    if (!_isCurrent(generation)) return;
    if (quota != null) {
      state = state.copyWith(userQuotas: {...state.userQuotas, userId: quota});
    } else if (force && state.userQuotas.containsKey(userId)) {
      final updated = Map<int, SeerrUserQuota>.from(state.userQuotas)..remove(userId);
      state = state.copyWith(userQuotas: updated);
    }
  }

  void selectProfile(SeerrServiceProfile profile) {
    state = state.copyWith(selectedProfile: profile);
  }

  void selectRootFolder(String folder) {
    state = state.copyWith(selectedRootFolder: folder);
  }

  void selectTags(List<SeerrServiceTag> tags) {
    state = state.copyWith(selectedTags: tags);
  }

  void toggleSeason(int seasonNumber, bool value) {
    if (state.isRequestedAlready(seasonNumber)) return;
    final current = Map<int, bool>.from(state.selectedSeasons);
    current[seasonNumber] = value;
    state = state.copyWith(selectedSeasons: current);
  }

  Future<void> selectUser(SeerrUserModel user) async {
    state = state.copyWith(selectedUser: user);
    await _loadQuotaForUser(user.id, force: true);
  }

  void selectServer(SeerrServer? server) {
    if (server == null || state.currentUser?.canRequestMedia(isTv: state.isTv, is4k: server.is4k == true) != true) {
      return;
    }

    if (server is SeerrSonarrServer) {
      state = state.copyWith(
        selectedSonarrServer: server,
        selectedProfile: state.pickProfileForServer(server),
        selectedRootFolder: state.pickRootFolderForServer(server),
        use4k: server.is4k == true,
      );
    } else if (server is SeerrRadarrServer) {
      state = state.copyWith(
        selectedRadarrServer: server,
        selectedProfile: state.pickProfileForServer(server),
        selectedRootFolder: state.pickRootFolderForServer(server),
        use4k: server.is4k == true,
      );
    }
    if (state.isTv && state.poster != null) _initializeSeasonSelection(state.poster!);
  }

  void toggle4k(bool enabled) {
    final poster = state.poster;
    if (poster == null || state.currentUser?.canRequestMedia(isTv: state.isTv, is4k: enabled) != true) return;
    if (enabled && !state.has4k) return;
    final nextState = state.copyWith(use4k: enabled);

    if (poster.type == SeerrMediaType.tvshow) {
      final selectedServer = nextState.activeSonarr;
      state = nextState.copyWith(
        selectedSonarrServer: selectedServer,
        selectedProfile: nextState.pickProfileForServer(selectedServer),
        selectedRootFolder: nextState.pickRootFolderForServer(selectedServer),
      );
    } else {
      final selectedServer = nextState.activeRadarr;
      state = nextState.copyWith(
        selectedRadarrServer: selectedServer,
        selectedProfile: nextState.pickProfileForServer(selectedServer),
        selectedRootFolder: nextState.pickRootFolderForServer(selectedServer),
      );
    }
    if (state.isTv) _initializeSeasonSelection(poster);
  }

  Future<ApiResult<SeerrMediaRequest?>?> submitRequest() async {
    final poster = state.poster;
    if (poster == null || !state.canSubmitRequest) return null;

    final canOverrideUser = !ref.read(managedIntegrationsProvider) && (state.currentUser?.canManageUsers ?? false);
    final userId = canOverrideUser ? state.selectedUser?.id ?? state.currentUser?.id : null;
    final tags = state.selectedTags.map((t) => t.id).whereType<int>().toList();

    final isTv = poster.type == SeerrMediaType.tvshow;
    final selectedServer = isTv ? state.selectedSonarrServer : state.selectedRadarrServer;

    final serverId = selectedServer?.id;
    final profileId = state.selectedProfile?.id;
    final rootFolder = state.selectedRootFolder ?? state.defaultRootFolder;

    if (isTv) {
      return (await api.requestSeries(
        tmdbId: poster.tmdbId,
        is4k: state.use4k,
        userId: userId,
        serverId: serverId,
        profileId: profileId,
        rootFolder: rootFolder,
        tags: tags,
        seasons: state.selectedSeasonNumbers,
      )).apiResult;
    } else {
      return (await api.requestMovie(
        tmdbId: poster.tmdbId,
        is4k: state.use4k,
        userId: userId,
        serverId: serverId,
        profileId: profileId,
        rootFolder: rootFolder,
        tags: tags,
      )).apiResult;
    }
  }

  Future<void> deleteRequest() async {
    final poster = state.poster;
    final requestId = state.activeRequestId;
    if (poster == null || requestId == null) return;

    await api.deleteRequest(requestId: requestId);
  }

  void _initializeSeasonSelection(SeerrDashboardPosterModel poster) {
    final seasons = poster.seasons ?? const <SeerrSeason>[];
    final statuses = SeerrHelpers.buildSeasonStatusMap(
      SeerrTvDetails(seasons: poster.seasons, mediaInfo: poster.mediaInfo),
      is4k: state.use4k,
    );

    final selection = <int, bool>{};
    for (final season in seasons) {
      final number = season.seasonNumber;
      if (number == null) continue;
      final status = statuses[number];
      final locked = status != null && status.isKnown && status != SeerrMediaStatus.deleted;
      selection[number] = locked;
    }

    state = state.copyWith(selectedSeasons: selection, seasonStatuses: statuses);
  }

  void selectAllSeasons() {
    final updatedSelection = <int, bool>{};
    for (final seasonNumber in state.selectedSeasons.keys) {
      if (state.isRequestedAlready(seasonNumber)) {
        updatedSelection[seasonNumber] = false;
      } else {
        updatedSelection[seasonNumber] = true;
      }
    }
    state = state.copyWith(selectedSeasons: updatedSelection);
  }
}

@Freezed(copyWith: true)
abstract class SeerrRequestModel with _$SeerrRequestModel {
  const SeerrRequestModel._();

  factory SeerrRequestModel({
    SeerrDashboardPosterModel? poster,
    @Default([]) List<SeerrSonarrServer> sonarrServers,
    @Default([]) List<SeerrRadarrServer> radarrServers,
    SeerrSonarrServer? selectedSonarrServer,
    SeerrRadarrServer? selectedRadarrServer,
    SeerrServiceProfile? selectedProfile,
    String? selectedRootFolder,
    @Default([]) List<SeerrServiceTag> selectedTags,
    @Default({}) Map<int, bool> selectedSeasons,
    @Default({}) Map<int, SeerrMediaStatus> seasonStatuses,
    @Default({}) Map<int, SeerrUserQuota> userQuotas,
    SeerrUserModel? currentUser,
    SeerrUserModel? selectedUser,
    @Default([]) List<SeerrUserModel> availableUsers,
    @Default(false) bool use4k,
    @Default(false) bool isAnime,
    @Default([]) List<SeerrGenre> genres,
    double? voteAverage,
    String? contentRating,
    String? releaseDate,
  }) = _SeerrRequestModel;

  bool get isTv => poster?.type == SeerrMediaType.tvshow;

  SeerrUserModel? get requestingUser => selectedUser ?? currentUser;

  List<SeerrMediaRequest> get _activeRequests => (poster?.mediaInfo?.requests ?? const <SeerrMediaRequest>[])
      .where((request) {
        if (request.id == null) return false;
        final status = SeerrRequestStatus.fromRaw(request.status);
        return status == SeerrRequestStatus.pending || status == SeerrRequestStatus.approved;
      })
      .toList(growable: false);

  bool get hasExistingRequest => _activeRequests.isNotEmpty;

  int? get activeRequestId {
    final requests = _activeRequests;
    if (requests.isEmpty) return null;

    final preferred = requests.firstWhereOrNull((request) => (request.is4k ?? false) == use4k);
    return preferred?.id ?? requests.first.id;
  }

  bool get canDeleteRequest => (currentUser?.canManageRequests ?? false) && activeRequestId != null;

  bool? get hasRequestPermission => currentUser?.canRequestMedia(isTv: isTv, is4k: activeServer?.is4k ?? use4k);

  SeerrQuotaEntry? get activeQuota {
    final userId = requestingUser?.id;
    if (userId == null) return null;
    final quota = userQuotas[userId];
    return isTv ? quota?.tv : quota?.movie;
  }

  bool get isQuotaRestricted {
    final quota = activeQuota;
    if (quota == null) return false;
    if (quota.restricted == true) return true;
    final limit = quota.limit;
    final remaining = quota.remaining;

    if (limit == null) return false;
    if (remaining != null && remaining <= 0) return true;
    return false;
  }

  SeerrSonarrServer? get fourKSonarr => sonarrServers.firstWhereOrNull((s) => s.is4k == true);
  SeerrRadarrServer? get fourKRadarr => radarrServers.firstWhereOrNull((s) => s.is4k == true);

  SeerrSonarrServer? get defaultSonarr =>
      sonarrServers.firstWhereOrNull((s) => s.is4k != true && s.isDefault == true) ??
      sonarrServers.firstWhereOrNull((s) => s.is4k != true);
  SeerrRadarrServer? get defaultRadarr =>
      radarrServers.firstWhereOrNull((s) => s.is4k != true && s.isDefault == true) ??
      radarrServers.firstWhereOrNull((s) => s.is4k != true);

  SeerrSonarrServer? get activeSonarr => use4k ? fourKSonarr : defaultSonarr;
  SeerrRadarrServer? get activeRadarr => use4k ? fourKRadarr : defaultRadarr;

  bool get has4k => isTv ? fourKSonarr != null : fourKRadarr != null;

  List<SeerrServer> get availableServers => isTv ? sonarrServers : radarrServers;

  SeerrServer? get activeServer => isTv ? selectedSonarrServer : selectedRadarrServer;

  List<SeerrServiceProfile> get availableProfiles =>
      isTv ? (selectedSonarrServer?.profiles ?? const []) : (selectedRadarrServer?.profiles ?? const []);

  List<SeerrServiceTag> get availableTags =>
      isTv ? (selectedSonarrServer?.tags ?? const []) : (selectedRadarrServer?.tags ?? const []);

  List<int>? get selectedSeasonNumbers {
    final enabled = selectedSeasons.entries
        .where((e) => e.value && !isRequestedAlready(e.key))
        .map((e) => e.key)
        .toList();
    if (enabled.isEmpty) return null;
    return enabled;
  }

  bool isRequestedAlready(int seasonNumber) {
    final status = seasonStatuses[seasonNumber];
    return status != null && status.isKnown && status != SeerrMediaStatus.deleted;
  }

  bool get canSubmitRequest {
    if (hasRequestPermission != true) return false;
    if (isQuotaRestricted) return false;

    if (isTv) {
      return selectedSeasonNumbers?.isNotEmpty ?? false;
    }

    final requests = poster?.mediaInfo?.requests ?? const [];
    if (requests.isEmpty) return true;

    final currentUserId = currentUser?.id;
    if (currentUserId == null) return true;

    final hasUserRequest = _activeRequests.any(
      (request) => request.requestedBy?.id == currentUserId && (request.is4k ?? false) == use4k,
    );
    return !hasUserRequest;
  }

  List<SeerrRootFolder> get availableRootFoldersRaw =>
      isTv ? (selectedSonarrServer?.rootFolders ?? const []) : (selectedRadarrServer?.rootFolders ?? const []);

  List<String> get availableRootFolders => availableRootFoldersRaw.map((r) => r.path).whereType<String>().toList();

  String? get defaultRootFolder {
    final server = activeServer;
    if (server is SeerrSonarrServer && isAnime) {
      return server.activeAnimeDirectory ?? server.activeDirectory;
    }
    return server?.activeDirectory;
  }

  String serverLabel(SeerrServer? server) {
    if (server == null) return 'Select Server';
    final name = server.name;
    final is4k = server.is4k;
    final suffix = is4k == true ? ' (4K)' : '';
    return '${name ?? 'Server'}$suffix';
  }

  SeerrServiceProfile? pickProfileForServer(SeerrServer? server) {
    final profiles = server?.profiles;
    final activeId = server is SeerrSonarrServer && isAnime
        ? server.activeAnimeProfileId ?? server.activeProfileId
        : server?.activeProfileId;

    if (profiles == null || profiles.isEmpty) return null;
    if (activeId == null) return profiles.first;
    return profiles.firstWhereOrNull((p) => p.id == activeId);
  }

  String? pickRootFolderForServer(SeerrServer? server) {
    final folders = server?.rootFolders;
    final activeDirectory = server is SeerrSonarrServer && isAnime
        ? server.activeAnimeDirectory
        : server?.activeDirectory;

    final available = folders ?? const [];
    if (available.isEmpty) return activeDirectory;

    final match = available.firstWhereOrNull((r) => r.path == activeDirectory);

    return match?.path ?? activeDirectory ?? available.first.path;
  }
}
