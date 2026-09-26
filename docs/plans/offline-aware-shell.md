# Offline-aware shell — GitHub #43

## Scope

Implement the browsing portion of the Smart Downloads epic before expanding automatic deletion. Keep the existing storage budget and reclamation policy. Next-N scheduling, undoable reclamation, and the app-wide error-state audit remain separate work.

## Implementation

1. Expose a live query over all user-scoped download records from the existing `SyncNotifier` database. Include nested episodes and tracks, and exclude metadata-only entries, unfinished downloads, deleted items, missing files, and empty files. Re-query after download activity changes.
2. Render Home from this local catalog: continue watching, next unwatched episode per series, and all available downloads. Compute Next Up by series ID and numeric season/episode order, using locally queued watched state. Exclude specials and completed series.
3. Offer an Available offline filter in Library, including while connected. Offline mode forces this filter. Search and Favorites browse local downloads. Hide server libraries, saved server filters, playlists, Calendar, and Seerr entry points while disconnected.
4. Play from the local file directly through the existing playback model and player. Preserve the offline watched-state queue and flush it on reconnection. Show reconnect, retry, and clear-search actions for the corresponding empty/error states.
5. Verify local selection and playback with unit tests, and verify offline Home, Library, Favorites, errors, and connectivity transitions with widget tests. Run the full test suite, `flutter analyze lib/`, and 120-column Dart formatting.

## Boundaries and device validation

Next Up considers only downloaded episodes: missing episodes cannot be inferred from the server while offline. Local browsing searches titles and series names; server filter controls are not applied to the device catalog. Web has no downloadable catalog. New strings fall back to English until translated.

Before release, verify on a device: download multiple seasons, disable connectivity, cold-start the app, browse and play a download, stop mid-episode, mark/finish an episode, reconnect, and confirm queued progress reaches Jellyfin. Repeat with a removed media file and after changing accounts. Confirm keyboard/D-pad navigation and player presentation on desktop/TV. Automated tests do not establish OS background scheduling or real-device playback fidelity.
