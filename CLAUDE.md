# Driftfin — agent guide

Driftfin is a cross-platform **Jellyfin client in Flutter**, a fork of [Fladder](https://github.com/DonutWare/Fladder) (GPL-3.0). Targets: Android (+ TV), iOS, macOS, Windows, Linux, Web.

## Toolchain

Use the **pinned Flutter via fvm**, not the system one (`.fvmrc` pins `3.47.5`). Prefix every command:

```bash
FLUTTER=~/fvm/versions/3.47.5/bin/flutter
DART=~/fvm/versions/3.47.5/bin/dart
```

Linux dev needs `libmpv-dev` (`sudo apt install libmpv-dev`); desktop builds also need `clang cmake ninja-build pkg-config libgtk-3-dev libcurl4-openssl-dev openjdk-17-jdk-headless` (curl is required by sentry-native; the JDK supplies JNI headers).

## Command cheat-sheet

```bash
$FLUTTER pub get
$FLUTTER analyze lib/                                   # must be clean (CI fails on info)
$DART format --line-length 120 <paths>                  # 120 cols — CI enforces it
$FLUTTER test                                           # unit + widget tests in test/
$FLUTTER run -d <linux|macos|windows|chrome|<device>>   # run the app
$FLUTTER gen-l10n                                        # regenerate localizations
$DART run build_runner build   # see Codegen
$DART run pigeon --input pigeons/<file>.dart            # regen one bridge (output paths fixed in @ConfigurePigeon)
```

## Testing

**Unit and widget tests are required** for every change — bugfix or new feature. Put new tests in `test/`, named after the code they cover (`*_test.dart`). Run with `$FLUTTER test` (Flutter's built-in `flutter_test`) — both unit and widget tests run here, no device needed. CI runs `flutter test` on every PR and must pass. Live integration tests (Trakt/Sonarr/Radarr) self-skip without creds. No on-device integration/e2e suites yet.

## Codegen (do this after editing models/providers/routes/APIs)

Most generated files come from **build_runner**, not by hand:
`*.freezed.dart` (freezed), `*.mapper.dart` (dart_mappable), json/riverpod/chopper `*.g.dart`, auto_route `*.gr.dart`. After changing an annotated source, run:

```bash
$DART run build_runner build
```

Two generators are **not** build_runner: localizations (`flutter gen-l10n`, from `lib/l10n/app_en.arb`) and the native bridge (`dart run pigeon`, from `pigeons/`).

## Never hand-edit generated files

`*.g.dart`, `*.freezed.dart`, `*.mapper.dart`, `*.swagger*.dart`, `*.gr.dart`, `lib/l10n/generated/`, `lib/src/*.g.dart`, `android/.../api/*.g.kt`. Change the source and regenerate.

## Architecture

- **State:** Riverpod (mix of codegen `@riverpod` and manual `StateNotifierProvider`).
- **Jellyfin API:** generated OpenAPI client in `lib/jellyfin/jellyfin_open_api.swagger*.dart` (chopper). Reach it via `JellyService` (`lib/providers/service_provider.dart`): `ref.read(jellyApiProvider).api.<endpoint>()`. Server URL is `serverUrlProvider`; token/deviceId live in `ref.read(userProvider)?.credentials`.
- **Playback:** `MediaControlsWrapper` (`lib/wrappers/media_control_wrapper.dart`) wraps a `BasePlayer` — `lib_mpv` (media_kit/libmpv, the default everywhere), `lib_mdk` (FVP), `native_player` (Android-TV ExoPlayer via pigeon). Exposed by `videoPlayerProvider`; current item is `playBackModel`; `PlaybackModelHelper.loadNewVideo(item)` starts playback.
- **Native bridge (pigeon):** sources in `pigeons/`, Dart in `lib/src/*.g.dart`, Kotlin in `android/.../io/github/hamadtheironside/driftfin/api/`. **Every channel prefix must be `io_github_hamadtheironside_driftfin`** (the rebrand left some stale; keep new ones consistent).
- **Localization:** add keys to `lib/l10n/app_en.arb` and run `gen-l10n`. `lib/l10n/generated/` is gitignored (built on demand).
- **Core abstractions** (most-connected nodes in the code graph): `clientSettingsProvider`, `videoPlayerProvider`, `mediaPlaybackProvider`, `videoPlayerSettingsProvider`, `ItemBaseModel`, `JellyService`, `syncProvider` (offline downloads), `PlaybackModelHelper`.

## Repo layout (`lib/`)

```
jellyfin/   generated Jellyfin OpenAPI client (chopper) — do not edit
src/        generated pigeon Dart bindings — do not edit
models/     data models (freezed / dart_mappable)
providers/  Riverpod providers (api, settings/, syncplay/, ...)
wrappers/   player backends (media_control_wrapper + players/)
screens/    UI by feature (video_player/, dashboard/, control_panel/, ...)
widgets/    shared widgets        routes/  auto_route config
seerr/      Jellyseerr integration  services/ background services
l10n/       app_*.arb (+ gitignored generated/)
```

## Conventions

- This fork has **diverged** from Fladder. Upstream merges are explicit maintenance tasks; preserve Driftfin features and branding when resolving conflicts. (Origin/license credit stays in `README.md`.)
- **Conventional Commits.** No `Co-Authored-By: Claude` trailer (`includeCoAuthoredBy: false`).
- Before pushing: `analyze` clean + `format --line-length 120`. CI (`.github/workflows/checks.yaml`) runs both on PRs (analyze `fail-on: info`).
- Feature requests/bugs go through GitHub **Issues** (Discussions disabled); roadmap is a public Project board with milestones `v1` and `Store releases`.

## Releases

`release.yml` builds and publishes on any pushed `v*` tag (Web/Windows/macOS/Linux + Android + unsigned iOS). The release version is the tag minus the leading `v`.

Android ships **two** APK sets per ABI: a `--release` (AOT-optimized) build — the recommended download — and a `--debug` build (`-debug` suffix) kept for bug diagnosis. `app/build.gradle` signs the release build with the project release key when `android/app/key.properties` + `keystore.jks` exist, and falls back to the debug key otherwise, so the build needs **no keystore to succeed** — a keyless build is just debug-signed (installable, not Play-publishable). To release-sign in CI, set the `KEYSTORE_BASE_64` (base64 of the `.jks`), `RELEASE_KEYSTORE_PASSWORD`, `RELEASE_KEYSTORE_ALIAS`, and `RELEASE_KEY_PASSWORD` repo secrets. R8/resource shrinking is off by default (see the comment in `app/build.gradle`); keep rules live in `android/app/proguard-rules.pro`.
- **Stable:** tag `vX.Y.Z` matching the pubspec version (e.g. `v0.10.5`).
- **Nightly:** tag `v<X.Y.Z>-nightly.YYYYMMDD.N` (e.g. `v0.10.5-nightly.20260630.1`) — published as a prerelease because the tag contains `nightly`; `N` increments per build that day.

`build.yml` (the upstream Fladder pipeline) is **disabled** — renamed to `build.yml.disabled`. It needed signing secrets this fork lacks and minted a rolling `nightly` tag that sorts out of order. Use `release.yml`.

`release.yml` does not currently pass `--dart-define=SENTRY_DSN=...`, so official GitHub release binaries ship with crash
reporting inert (the toggle exists but has nowhere to send to). To bake a DSN into a given platform's build step, add
`--dart-define=SENTRY_DSN=${{ secrets.SENTRY_DSN }}` to its `flutter build` line and set the `SENTRY_DSN` repo secret. Web
deployments (Docker/self-hosted) don't need this — see `SENTRY_DSN` in [INSTALL.md](INSTALL.md) for the runtime alternative.

## More docs

`DEVELOPEMENT.md` (full setup/run), `FORK.md` (what changed vs Fladder), `CONTRIBUTING.md`, `INSTALL.md`.

## Knowledge graph

`graphify-out/` (gitignored) holds a code graph: `GRAPH_REPORT.md`, `graph.html`, `graph.json`. Ask questions with `/graphify query "<q>"`; rebuild scoped with `/graphify lib`.
