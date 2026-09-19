# Dependency migration status and original audit

Updated: 2026-09-19.

## Implementation status

Flutter **3.47.5 / Dart 3.13.4** is installed and pinned through FVM. The migration used `flutter pub upgrade --major-versions`, followed by compatibility fixes, stable-version selection, `build_runner`, Pigeon and localization generation. The lockfile records the resolved versions. Unused `custom_lint` and `drift_sync` were removed.

Application changes cover Riverpod 3 lifecycle/imports, AutoRoute, FilePicker 13 import/export, local_auth 3 cancellation/options, dynamic color palette conversion, updated Flutter reorder/settings widgets, and regenerated API/model/native bridges. Settings JSON and database schema version remain unchanged. Added auth, palette and backup-export regression coverage. CI now uses Flutter's bundled Dart; iOS minimum is 15; Android compilation targets Java 17, Kotlin/Compose 2.4.20 and desugaring 2.1.5.

The final `flutter pub outdated --json` reports these direct/dev exceptions:

| Dependency | Resolved | Latest observed | Reason |
| --- | --- | --- | --- |
| Freezed | 4.0.1 | 4.0.2 | Analyzer 14 conflicts with AutoRoute/Chopper generators |
| material_color_utilities | 0.13.0 | 0.13.1 | Flutter SDK pin |
| media_kit | 1.2.2 fork | 1.2.6 | Preserve native playback changes pending device validation |
| media_kit_video | 2.0.0 fork | 2.0.1 | Same coherent playback fork |
| pip | 0.0.3 fork | 0.0.4 | Preserve native PiP changes pending device validation |

All nine playback overrides now use immutable commit SHAs. Remaining newer transitive packages are constrained by the compatible graph; no forced overrides were added.

Native/platform work is **not fully complete**: AGP/Gradle, Android playback libraries, packaging dependencies and unrelated CI actions retain their existing versions. Android SDK, Apple tooling and Windows tooling are unavailable on this Linux host. JDK 17 was installed to satisfy the Linux JNI build requirement. Android/iOS/macOS/Windows builds, Apple Pod resolution, UIScene lifecycle migration, existing real-user database validation and device playback smoke tests remain required before release. The inventory below retains the follow-up plan and historical versions; it does not describe the current lockfile.

## Verification

- Full unit/widget suite: **1,604 passed, 3 skipped**, zero failures (`flutter test --no-pub --concurrency=2`).
- Static analysis of `lib` and `test`: **no issues**.
- Changed Dart files formatted with Dart 3.13.4 at 120 columns.
- All 38 translation files pass completeness checks.
- Web release build: **passed** on the final application source. Linux release build: **passed** after installing JDK 17 and correcting the local CMake cache. The Linux bundle now copies package native assets (including SQLite), matching the current Flutter template.
- Build runner, all eight Pigeon bridges and localizations regenerated successfully. Generators emit trailing whitespace/blank lines in some Kotlin and Dart outputs; `git diff --check` reports these generated-file findings. Generated files were not hand-edited.

## Original audit (before implementation)

Audit date: 2026-09-19. Scope: latest stable Flutter, direct/dev Dart packages, native build dependencies, CI and distribution tooling. The remaining sections preserve the original assessment and migration plan.

## Assessment

Flutter is pinned to **3.35.7 / Dart 3.9.2**, roughly eleven months old and four stable release families behind 3.47 (3.38, 3.41, 3.44, 3.47). The live Flutter stable branch and tag **3.47.5** both resolve to `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`. Target that release and its bundled Dart SDK; do not install Dart independently. The locally installed 3.47.4 includes Dart 3.13.3; the exact bundled patch for 3.47.5 still needs checking after installation. [Official hotfix changelog](https://github.com/flutter/flutter/blob/3.47.5/CHANGELOG.md).

There are **103 non-SDK direct/dev packages: 99 hosted and four Git-overridden**. Of the hosted packages, **69 (70%) are behind**, **30 are current**, and **17 need a major-version increase**. Pre-1.0 minor releases may also break APIs. The current SDK/constraints permit 34 direct/dev package upgrades according to `flutter pub outdated`. Declared lower bounds are not installed versions: this report compares `pubspec.lock` with live pub.dev metadata.

The current outdated report flags discontinued transitive packages `build_resolvers`, `build_runner_core`, and `js`. It reports no affected advisory among returned packages; that is not a complete security audit. Several already-current small UI libraries have old releases; age alone does not justify replacement.

## Confirmed blockers and decisions

| Blocker | Evidence | Recommended decision |
| --- | --- | --- |
| Generator ecosystem cannot use every latest release together | Freezed 4.0.2 requires Analyzer >=14 <15; AutoRoute generator 10.6.0 and Chopper generator 8.7.0 require <14 | Temporarily pin Freezed **4.0.1** exactly. It supports Analyzer 13. Update to 4.0.2 once both other generators support 14. Do not force Analyzer with an override. |
| Custom lint prevents modern generators | custom_lint 0.8.1 requires Analyzer ^8; modern Riverpod, Drift, Pigeon and mapper generators require >=13 | Remove custom_lint and its analyzer plugin entry. Repository search found no custom lint rules/package using it. Retain regular Dart/Flutter analysis. |
| Chromecast and latest drift_sync conflict | drift_sync >=0.14.2 brings grpc 5 / protobuf 6; cast_plus 2.2.0 requires protobuf 3 | Search found drift_sync only in pubspec, with no application/test imports. Confirm unused and remove it. If needed, temporarily use 0.14.1 until cast_plus is migrated. Do not force protobuf 6 under old generated messages. |
| Playback version numbers hide forks | Nine Git overrides, eight pointing to one media-kit revision | Audit fork differences before replacing with pub.dev releases. Keep all media-kit native packages coherent and pin retained Git dependencies to immutable SHAs. |
| Latest native tools exceed Flutter's verified combination | Latest AGP/Gradle/Kotlin differ from Flutter 3.47's tested matrix | First establish a green Android build using the documented matrix, then independently validate latest native versions. A temporary compatibility pin is unfinished upgrade work, not “everything current.” |

Package constraints were fetched from the [pub.dev API](https://pub.dev/help/api). See [Freezed's changelog](https://pub.dev/packages/freezed/changelog) and [AutoRoute generator's changelog](https://pub.dev/packages/auto_route_generator/changelog).

**Dependency experiment:** In an isolated temporary directory, using Flutter 3.47.4 / Dart 3.13.3, exact latest direct/dev package versions plus the existing Git overrides failed on the drift_sync/cast_plus conflict after removing custom_lint and selecting Freezed 4.0.1. Selecting drift_sync 0.14.1 then resolved successfully with Analyzer 13.3.0. The resulting graph has 330 packages and still reports 25 with newer incompatible versions. This proves a candidate dependency graph exists, not that the application compiles or runs. Repeat on 3.47.5 with unused drift_sync removed before implementation. The app's pubspec and lockfile were not changed.

## Migration sequence

### 1. Establish the baseline and update Flutter (estimate: 1–2 developer days)

Capture analyze/test/build results on 3.35.7 and preserve the old lockfiles. Install 3.47.5 through FVM; update `.fvmrc`, SDK constraints, toolchain documentation and any hardcoded SDK paths together. Set the Dart minimum to 3.13.0 and Flutter minimum to 3.47.0 for the proposed package set. Existing `>=3.1.3` is misleading: the current lockfile already needs Dart >=3.9.0.

Remove the separate `dart-lang/setup-dart` step from `.github/workflows/checks.yaml`; formatting, generation and tests must use Flutter's bundled Dart. Both checks and release workflows already derive Flutter from `.fvmrc`.

Try the old graph on the new SDK first, then apply the minimum necessary compatible package updates. SDK-pinned dependencies may require lockfile changes. Review the 3.38–3.47 breaking-change guides and use `dart fix --dry-run` before selective fixes. Keep broad formatter churn in a separate commit. Do not regenerate whole native project directories over the customized runners.

The [Flutter 3.47 release notes](https://flutter.dev/blog/whats-new-in-flutter-3-47) raise the iOS minimum to 15 and Android default minimum to API 24. The repository currently has iOS 14 and delegates Android minSdk to Flutter. Record these device-support changes. macOS is already set to 12. Inspect and migrate the custom `ios/Runner/AppDelegate.swift` for UIScene lifecycle compatibility, preserving background work and notification registration. Verify Podfiles, Xcode project targets and plugin deployment requirements together.

Exit: new SDK resolves, baseline issues are distinguished from migration failures, and CI uses one SDK consistently.

### 2. Migrate generators, Riverpod and database (estimate: 2–4 developer days)

Upgrade the coupled generator set in one dependency resolution: Riverpod runtime/annotations/generator, build_runner, Chopper/Swagger, JSON, Freezed, Drift and Dart Mappable, plus AutoRoute/runtime generator and Pigeon. Their major numbers do not need to match: Riverpod runtime 3.4.3 pairs with annotation 4.0.7/generator 4.0.9; AutoRoute 11.1.0 pairs with generator 10.6.0. Use the documented temporary Freezed pin and remove unused custom_lint/drift_sync.

There are 96 handwritten Dart files mentioning StateProvider or StateNotifierProvider. Use Riverpod's supported legacy imports initially rather than rewriting every notifier. Migrate Ref/provider APIs, overrides, observers and generated families where required. Test disposed-ref handling after awaits, provider equality, default retry behavior, and out-of-view pausing; playback/download services must survive navigation. [Riverpod migration guide](https://riverpod.dev/docs/3.0_migration).

Regenerate build_runner outputs from sources, including Jellyfin and Seerr clients; inspect endpoint serialization, auth headers and null/enum handling. Regenerate every changed Pigeon bridge in Dart and native languages together. Preserve the `io_github_hamadtheironside_driftfin` channel prefix. Do not hand-edit generated files.

Upgrade Drift runtime/dev/Flutter adapter together. Open a real pre-upgrade database copy and verify downloaded items, per-user isolation and pending sync data. Current schemaVersion is 1; a dependency bump alone must not trigger database deletion or an invented schema migration.

Exit: generation succeeds reproducibly; analyze is clean; unit/widget tests pass; old database opens without data loss; navigation/login and API contract tests pass.

### 3. Update application packages and playback (estimate: 2–4 developer days)

Apply remaining hosted targets in small functional groups: network/storage; UI/navigation; auth/files/sharing; background tasks/notifications; playback. Explicitly unpin volume_controller 3.4.1. Add focused unit and widget tests for changed behavior, extending existing tests rather than creating a new framework.

`lib/util/auth_service.dart` currently uses AuthenticationOptions and catches PlatformException. local_auth 3 replaces options with named parameters and most failures with LocalAuthException; preserve cancellation, background-resume and failed-auth behavior. [local_auth changelog](https://pub.dev/packages/local_auth/changelog).

Audit notification initialization/scheduling, Workmanager callbacks and Apple task registration; FilePicker and SharePlus API changes; AutoRoute guards, nested navigation and back handling; TypeAhead controls; renamed icons and image cache behavior. Flutter 3.47 introduces standalone Material/Cupertino libraries; evaluate migration when the upgraded UI packages require it, including localization delegates and compatibility bridges. It is not necessary to force an unrelated UI rewrite merely to change the SDK.

Compare DonutWare/media-kit commit `cb56b5a6149f1e51086eba473c7e48041c54ab12` and DonutWare/pip commit `3eaa141d09dbd7fca995bf6c535c055aa173dba8` with current upstream packages. Prefer removing overrides only when equivalent behavior is demonstrated. Otherwise port required fixes and pin a maintained fork. Validate native binary provenance and Android 16 KB page compatibility. A pub.dev version number is not proof that the fork's changes exist upstream.

Exit: libmpv, FVP and Android-TV native playback work; seeking, subtitles, audio tracks, hardware decode, PiP, background controls, downloads, casting and DLNA pass device smoke tests. Keep schema and user settings compatible with rollback.

### 4. Update native toolchains and distribution (estimate: 2–4 developer days)

For Android, start with Flutter 3.47's verified AGP 9.1.0 / Gradle 9.3.1 / Kotlin 2.4.0 and JDK 17 minimum, then test latest candidates below. Migrate built-in Kotlin and AGP DSL as documented; inspect the permission_handler subproject Kotlin workaround and old Compose compiler option. Keep Java/Kotlin bytecode targets aligned. Do not lower the app's current compileSdk/targetSdk 37 to Flutter's defaults mechanically. [Built-in Kotlin migration](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin), [AGP compatibility table](https://developer.android.com/build/releases/about-agp).

Upgrade Compose, Activity, Coil and MaterialKolor separately from Media3. The project shares `1.8.0+1` between Media3 and Jellyfin's FFmpeg decoder; upstream Media3 1.11.1 is not automatically a compatible replacement. Resolve a matching decoder release and ASS renderer, inspect Gradle's dependency graph, then test codecs/subtitles. The Jellyfin decoder metadata endpoint returned 404 during this audit; its latest compatible version remains unverified.

On Apple runners, verify latest stable Xcode support, migrate lifecycle code, and update native dependencies through Flutter plugins and CocoaPods resolution. Do not independently force transitive Pod versions beyond plugin constraints. Keep CocoaPods until every used plugin/fork works with SwiftPM. Verify Intel and Apple Silicon distribution requirements before changing architectures.

Update active CI actions and confirm the self-hosted Blacksmith runner supports their Node runtime. Review active packaging manifests, Docker image tags/digests, Linux dependencies, Flatpak runtime/codec extension alignment and AppImage inputs. Treat disabled `build.yml.disabled` as historical. Native platform dependencies require platform builds, not just Dart tests.

The separate Jellyfin server plugin currently targets net8.0 and Jellyfin.Controller 10.10.*. Its target framework and package version must match the deployed server ABI. A latest-server migration is a separate compatibility change: inspect current server version before selecting Jellyfin.Controller 12.1.0 or a newer .NET target. Upgrade test tooling separately.

Exit: every advertised platform builds in CI; package installation and startup pass; native toolchain exceptions are documented with an unblock condition.

### 5. Verify and release (estimate: 1–2 developer days plus device soak)

Run the following with the selected FVM SDK after every substantial migration group:

```bash
FLUTTER=~/fvm/versions/3.47.5/bin/flutter
DART=~/fvm/versions/3.47.5/bin/dart
"$FLUTTER" pub get
"$FLUTTER" gen-l10n
"$DART" run build_runner build --delete-conflicting-outputs
# Run dart run pigeon --input for each affected pigeons/*.dart source.
"$DART" format --line-length 120 --output=none --set-exit-if-changed lib test
"$FLUTTER" analyze lib/ --fatal-infos
"$FLUTTER" test --coverage
"$DART" run tool/check_translations.dart
"$FLUTTER" pub outdated --json
```

Run the existing changed-line coverage gate. Build Android release/debug APKs and app bundle, iOS, macOS, Windows, Linux and web using repository flavors/settings. Run server-plugin tests if changed. Device QA must cover Android phone/TV, iOS, each desktop target and web: login/account switching, browse/search, all playback backends, casting/discovery, resume/download/background work and settings retention. Compare startup, seek latency, dropped frames and memory against the baseline. Never count credential-skipped integration tests as verified integrations.

Publish a nightly only during the implementation/release task, retain the last known-good release, and soak on representative devices before stable. Roll back application/toolchain/lockfiles together. Re-run the inventory immediately before release; every remaining newer package needs a recorded constraint, owner and follow-up trigger. Do not force all transitive packages to latest with overrides.

**Planning estimate:** 8–16 developer days plus device soak, assuming native devices/runners are available. Fork maintenance and a server ABI migration can extend this. This is an estimate, not a measured delivery commitment.

## Full direct/dev package inventory

“Latest” means the stable version returned by pub.dev during this audit. SDK packages are supplied by Flutter. Git rows compare embedded versions with pub.dev for context only; these are different source histories. The proposed graph is not an application compatibility guarantee.

| Package | Locked | Latest stable | Action |
| --- | --- | --- | --- |
| [cupertino_icons](https://pub.dev/packages/cupertino_icons) | 1.0.8 | 1.0.9 | Upgrade and validate |
| [iconsax_plus](https://pub.dev/packages/iconsax_plus) | 1.0.0 | 1.0.0 | Keep |
| [chopper](https://pub.dev/packages/chopper) | 8.4.0 | 8.7.0 | Upgrade and validate |
| [cached_network_image](https://pub.dev/packages/cached_network_image) | 3.4.1 | 4.0.0 | Major migration |
| [http](https://pub.dev/packages/http) | 1.6.0 | 1.6.0 | Keep |
| [web_socket_channel](https://pub.dev/packages/web_socket_channel) | 3.0.3 | 3.0.3 | Keep |
| [flutter_cache_manager](https://pub.dev/packages/flutter_cache_manager) | 3.4.1 | 3.4.5 | Upgrade and validate |
| [connectivity_plus](https://pub.dev/packages/connectivity_plus) | 7.0.0 | 7.3.1 | Upgrade and validate |
| [punycoder](https://pub.dev/packages/punycoder) | 0.2.2 | 0.3.0 | Pre-1.0 breaking-change review |
| [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) | 2.6.1 | 3.4.3 | Major migration |
| [riverpod_annotation](https://pub.dev/packages/riverpod_annotation) | 2.6.1 | 4.0.7 | Major migration |
| [json_annotation](https://pub.dev/packages/json_annotation) | 4.9.0 | 4.12.0 | Upgrade and validate |
| [freezed_annotation](https://pub.dev/packages/freezed_annotation) | 3.1.0 | 3.1.0 | Keep |
| [logging](https://pub.dev/packages/logging) | 1.3.0 | 1.3.0 | Keep |
| [meta](https://pub.dev/packages/meta) | 1.16.0 | 1.19.0 | Upgrade and validate |
| [sentry_flutter](https://pub.dev/packages/sentry_flutter) | 9.22.0 | 9.30.0 | Upgrade and validate |
| [intl](https://pub.dev/packages/intl) | 0.20.2 | 0.20.3 | Upgrade and validate |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | 2.5.3 | 2.5.5 | Upgrade and validate |
| [path_provider](https://pub.dev/packages/path_provider) | 2.1.5 | 2.1.6 | Upgrade and validate |
| [media_kit](https://pub.dev/packages/media_kit) | 1.2.2 | 1.2.6 | Audit fork before switching source |
| [media_kit_video](https://pub.dev/packages/media_kit_video) | 2.0.0 | 2.0.1 | Audit fork before switching source |
| [media_kit_libs_video](https://pub.dev/packages/media_kit_libs_video) | 1.0.7 | 1.0.7 | Audit fork before switching source |
| [audio_service](https://pub.dev/packages/audio_service) | 0.18.18 | 0.18.19 | Upgrade and validate |
| [audio_service_mpris](https://pub.dev/packages/audio_service_mpris) | 0.2.0 | 0.2.1 | Upgrade and validate |
| [audio_session](https://pub.dev/packages/audio_session) | 0.2.4 | 0.2.4 | Keep |
| [fvp](https://pub.dev/packages/fvp) | 0.35.0 | 0.38.1 | Pre-1.0 breaking-change review |
| [pip](https://pub.dev/packages/pip) | 0.0.3 | 0.0.4 | Audit fork before switching source |
| [video_player](https://pub.dev/packages/video_player) | 2.10.1 | 2.14.0 | Upgrade and validate |
| [cast_plus](https://pub.dev/packages/cast_plus) | 2.2.0 | 2.2.0 | Keep |
| [dlna_dart](https://pub.dev/packages/dlna_dart) | 0.1.1 | 0.1.1 | Keep |
| [image](https://pub.dev/packages/image) | 4.5.4 | 4.10.1 | Upgrade and validate |
| [dynamic_color](https://pub.dev/packages/dynamic_color) | 1.8.1 | 2.1.0 | Major migration |
| [flutter_svg](https://pub.dev/packages/flutter_svg) | 2.2.2 | 2.3.0 | Upgrade and validate |
| [animations](https://pub.dev/packages/animations) | 2.1.1 | 3.0.0 | Major migration |
| [automatic_animated_list](https://pub.dev/packages/automatic_animated_list) | 1.1.0 | 1.1.0 | Keep |
| [page_transition](https://pub.dev/packages/page_transition) | 2.2.1 | 2.2.2 | Upgrade and validate |
| [sticky_headers](https://pub.dev/packages/sticky_headers) | 0.3.0+2 | 0.3.0+2 | Keep |
| [flutter_staggered_grid_view](https://pub.dev/packages/flutter_staggered_grid_view) | 0.7.0 | 0.7.0 | Keep |
| [sliver_tools](https://pub.dev/packages/sliver_tools) | 0.2.12 | 0.2.12 | Keep |
| [square_progress_indicator](https://pub.dev/packages/square_progress_indicator) | 0.0.8 | 0.0.8 | Keep |
| [flutter_blurhash](https://pub.dev/packages/flutter_blurhash) | 0.9.1 | 0.9.1 | Keep |
| [extended_image](https://pub.dev/packages/extended_image) | 10.0.1 | 10.1.0 | Upgrade and validate |
| [flutter_widget_from_html](https://pub.dev/packages/flutter_widget_from_html) | 0.17.1 | 0.17.4 | Upgrade and validate |
| [font_awesome_flutter](https://pub.dev/packages/font_awesome_flutter) | 10.12.0 | 11.0.0 | Major migration |
| [reorderable_grid](https://pub.dev/packages/reorderable_grid) | 1.0.12 | 1.0.13 | Upgrade and validate |
| [overflow_view](https://pub.dev/packages/overflow_view) | 0.5.0 | 0.5.0 | Keep |
| [flutter_sticky_header](https://pub.dev/packages/flutter_sticky_header) | 0.8.0 | 0.8.0 | Keep |
| [markdown_widget](https://pub.dev/packages/markdown_widget) | 2.3.2+8 | 2.3.2+8 | Keep |
| [palette_generator_master](https://pub.dev/packages/palette_generator_master) | 1.0.1 | 1.1.0 | Upgrade and validate |
| [auto_route](https://pub.dev/packages/auto_route) | 10.2.2 | 11.1.0 | Major migration |
| [url_launcher](https://pub.dev/packages/url_launcher) | 6.3.2 | 6.3.2 | Keep |
| [flutter_custom_tabs](https://pub.dev/packages/flutter_custom_tabs) | 2.4.0 | 2.6.0 | Upgrade and validate |
| [path](https://pub.dev/packages/path) | 1.9.1 | 1.9.1 | Keep |
| [file_picker](https://pub.dev/packages/file_picker) | 10.3.6 | 13.1.0 | Major migration |
| [transparent_image](https://pub.dev/packages/transparent_image) | 2.0.1 | 2.0.1 | Keep |
| [universal_html](https://pub.dev/packages/universal_html) | 2.3.0 | 2.3.0 | Keep |
| [collection](https://pub.dev/packages/collection) | 1.19.1 | 1.19.1 | Keep |
| [local_auth](https://pub.dev/packages/local_auth) | 2.3.0 | 3.0.2 | Major migration |
| [package_info_plus](https://pub.dev/packages/package_info_plus) | 9.0.0 | 10.2.1 | Major migration |
| [wakelock_plus](https://pub.dev/packages/wakelock_plus) | 1.4.0 | 1.8.0 | Upgrade and validate |
| [screen_brightness](https://pub.dev/packages/screen_brightness) | 2.1.7 | 2.1.11 | Upgrade and validate |
| [volume_controller](https://pub.dev/packages/volume_controller) | 3.4.1 | 3.7.1 | Upgrade and validate |
| [window_manager](https://pub.dev/packages/window_manager) | 0.5.1 | 0.5.2 | Upgrade and validate |
| [smtc_windows](https://pub.dev/packages/smtc_windows) | 1.1.0 | 1.1.0 | Keep |
| [background_downloader](https://pub.dev/packages/background_downloader) | 9.3.0 | 9.6.2 | Upgrade and validate |
| [screen_retriever](https://pub.dev/packages/screen_retriever) | 0.2.0 | 0.2.2 | Upgrade and validate |
| [desktop_multi_window](https://pub.dev/packages/desktop_multi_window) | 0.3.0 | 0.3.1 | Upgrade and validate |
| [workmanager](https://pub.dev/packages/workmanager) | 0.9.0+3 | 0.10.10 | Pre-1.0 breaking-change review |
| [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) | 20.1.0 | 22.3.1 | Major migration |
| [permission_handler](https://pub.dev/packages/permission_handler) | 13.0.1 | 13.0.2 | Upgrade and validate |
| [drift](https://pub.dev/packages/drift) | 2.28.2 | 2.35.0 | Upgrade and validate |
| [drift_flutter](https://pub.dev/packages/drift_flutter) | 0.2.7 | 0.3.1 | Pre-1.0 breaking-change review |
| [drift_sync](https://pub.dev/packages/drift_sync) | 0.14.0 | 0.14.3 | Remove if confirmed unused; see blockers |
| [drift_db_viewer](https://pub.dev/packages/drift_db_viewer) | 2.1.0 | 2.1.0 | Keep |
| [async](https://pub.dev/packages/async) | 2.13.0 | 2.13.1 | Upgrade and validate |
| [xid](https://pub.dev/packages/xid) | 1.2.1 | 1.2.1 | Keep |
| [desktop_drop](https://pub.dev/packages/desktop_drop) | 0.6.1 | 0.8.4 | Pre-1.0 breaking-change review |
| [flexible_scrollbar](https://pub.dev/packages/flexible_scrollbar) | 0.1.3 | 0.1.3 | Keep |
| [flutter_typeahead](https://pub.dev/packages/flutter_typeahead) | 5.2.0 | 6.0.0 | Major migration |
| [share_plus](https://pub.dev/packages/share_plus) | 12.0.1 | 13.3.0 | Major migration |
| [pretty_qr_code](https://pub.dev/packages/pretty_qr_code) | 3.6.0 | 3.6.0 | Keep |
| [archive](https://pub.dev/packages/archive) | 4.0.7 | 4.3.0 | Upgrade and validate |
| [dart_mappable](https://pub.dev/packages/dart_mappable) | 4.6.1 | 4.10.0 | Upgrade and validate |
| [flutter_native_splash](https://pub.dev/packages/flutter_native_splash) | 2.4.7 | 2.4.8 | Upgrade and validate |
| [macos_window_utils](https://pub.dev/packages/macos_window_utils) | 1.9.0 | 1.9.1 | Upgrade and validate |
| [chinese_font_library](https://pub.dev/packages/chinese_font_library) | 1.2.0 | 1.3.0 | Upgrade and validate |
| [path_provider_platform_interface](https://pub.dev/packages/path_provider_platform_interface) | 2.1.2 | 2.1.3 | Upgrade and validate |
| [wakelock_plus_platform_interface](https://pub.dev/packages/wakelock_plus_platform_interface) | 1.3.0 | 1.7.0 | Upgrade and validate |
| [plugin_platform_interface](https://pub.dev/packages/plugin_platform_interface) | 2.1.8 | 2.1.8 | Keep |
| [drift_dev](https://pub.dev/packages/drift_dev) | 2.28.0 | 2.35.0 | Upgrade and validate |
| [flutter_lints](https://pub.dev/packages/flutter_lints) | 6.0.0 | 6.0.0 | Keep |
| [fake_async](https://pub.dev/packages/fake_async) | 1.3.3 | 1.3.3 | Keep |
| [build_runner](https://pub.dev/packages/build_runner) | 2.5.4 | 2.16.1 | Upgrade and validate |
| [chopper_generator](https://pub.dev/packages/chopper_generator) | 8.2.0 | 8.7.0 | Upgrade and validate |
| [json_serializable](https://pub.dev/packages/json_serializable) | 6.9.5 | 6.14.1 | Upgrade and validate |
| [custom_lint](https://pub.dev/packages/custom_lint) | 0.7.6 | 0.8.1 | Remove if confirmed unused; see blockers |
| [freezed](https://pub.dev/packages/freezed) | 3.1.0 | 4.0.2 | Use 4.0.1 until Analyzer 14 supported across generators |
| [swagger_dart_code_generator](https://pub.dev/packages/swagger_dart_code_generator) | 3.0.3 | 4.1.1 | Major migration |
| [riverpod_generator](https://pub.dev/packages/riverpod_generator) | 2.6.5 | 4.0.9 | Major migration |
| [dart_mappable_builder](https://pub.dev/packages/dart_mappable_builder) | 4.5.0 | 4.10.0 | Upgrade and validate |
| [auto_route_generator](https://pub.dev/packages/auto_route_generator) | 10.2.3 | 10.6.0 | Upgrade and validate |
| [icons_launcher](https://pub.dev/packages/icons_launcher) | 3.0.3 | 3.1.0 | Upgrade and validate |
| [pigeon](https://pub.dev/packages/pigeon) | 26.1.0 | 29.0.2 | Major migration |

## Native and build inventory

Versions below are published stable candidates, not a tested combination. Maven values were read from the publishers' metadata; NuGet values from its package API; action tags from each repository's latest release API.

| Component | Current | Latest observed / decision |
| --- | --- | --- |
| Flutter | 3.35.7 | 3.47.5; use bundled Dart |
| AGP | 8.12.2 | 9.4.1; after Flutter-verified 9.1.0 checkpoint |
| Gradle | 8.13 | 9.7.1; validate with AGP; 9.4 requires at least Gradle 9.6 |
| Kotlin / Compose plugin | 2.1.0 | 2.4.20; coordinate built-in Kotlin and Compose |
| JDK used by Android CI | 17 | Keep a supported build JDK initially; latest JDK is not inherently compatible |
| Compose BOM | 2025.12.00 | 2026.09.00 |
| Activity Compose | 1.12.1 | 1.13.0 |
| Desugaring libraries | 2.1.4 | 2.1.5 |
| Media3 | 1.8.0+1 | Upstream 1.11.1; decoder compatibility unresolved |
| Jellyfin FFmpeg decoder | 1.8.0+1 | Latest unverified; migrate with Media3 |
| ASS media | 0.3.0 | 0.5.1; check Media3 compatibility |
| Iconsax Compose | 0.0.5 | 0.0.5 |
| Coil | 3.3.0 | 3.6.3 |
| MaterialKolor | 4.0.5 | 5.0.1 |
| Flatpak mpv | 0.39.0 | 0.41.0 |
| Flatpak libass | 0.17.3 | 0.17.5 |
| Jellyfin.Controller | 10.10.* | 12.1.0 published; deployed server ABI decides target |
| Microsoft.NET.Test.Sdk | 17.11.1 | 18.10.1 |
| xunit | 2.9.2 | 2.9.3 within this package; xUnit v3 is a separate migration |
| xunit.runner.visualstudio | 2.8.2 | 4.0.0; validate test discovery/framework compatibility |
| actions/checkout | v4 / v4.1.1 | v7.0.1 |
| actions/setup-java | v4 | v6.0.1 |
| actions/upload-artifact | v4 | v7.0.1 |
| actions/download-artifact | v4 | v8.0.1 |
| subosito/flutter-action | v2 / v2.16.0 | v2.23.0 |
| actions/setup-dotnet | v4 | v6.0.0 |
| softprops/action-gh-release | v2 | v3.0.3 |
| peaceiris/actions-gh-pages | v4 | v4.1.0 |

Current additional packaging pins: GNOME runtime 48, FFmpeg extension 24.08, nv-codec-headers n13.0.19.0, libplacebo v7.349.0, uchardet 0.0.8 and zenity 4.0.3. Exact latest compatible replacements, Xcode/CocoaPods, NDK, OS build packages, container digests and remaining CI helpers were not exhaustively verified. Refresh these on the actual packaging runners in phase 4; do not label the whole repository fully current before doing so. Apple Pod lockfiles contain plugin-controlled transitive dependencies and must be re-resolved on macOS.

Native sources: [Google Maven](https://dl.google.com/dl/android/maven2/com/android/tools/build/gradle/maven-metadata.xml), [Gradle releases](https://docs.gradle.org/current/release-notes.html), [Kotlin Maven metadata](https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/kotlin-gradle-plugin/maven-metadata.xml), [NuGet Jellyfin.Controller](https://api.nuget.org/v3-flatcontainer/jellyfin.controller/index.json), [mpv releases](https://github.com/mpv-player/mpv/releases), [libass releases](https://github.com/libass/libass/releases).

## Original audit limitations

Only dependency resolution was exercised on the candidate graph, using 3.47.4 in a temporary directory. No application source was migrated, no candidate code generation/analyze/tests/native builds were run, and no release was published. The 3.47.5 target was verified against the live official stable ref and tag; Flutter's downloadable JSON manifest returned 404 during this audit. Recheck the target's bundled Dart and package graph after installing it.
