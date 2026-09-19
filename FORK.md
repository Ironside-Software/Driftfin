# Maintaining Driftfin (fork of Fladder)

Driftfin is a fork of [Fladder](https://github.com/DonutWare/Fladder) by DonutWare,
under GPL-3.0. (Branding/license credit lives in `README.md`.)

Upstream updates are merged explicitly when requested. Preserve Driftfin features,
branding, and release workflows; regenerate bindings and run analysis and tests
after resolving conflicts. For release steps, see **Releases** in `CLAUDE.md`.

## What the fork changes

The rebrand is in two buckets:

1. **Visible branding** (~11 files, rarely conflicts) — app name "Driftfin", icons,
   bundle IDs `app.driftfin`, deep-link scheme `driftfin://`, README, pubspec `name`.
2. **Internal Dart package rename** (~480 files) — `package:fladder/` → `package:driftfin/`.
   This is invisible to users but is the reason upstream merges need a re-apply step:
   upstream keeps writing `package:fladder/` in new/changed files.

The rename is re-applied mechanically by [`tool/rebrand.sh`](tool/rebrand.sh).

## Syncing upstream into the fork

```bash
git fetch upstream
git checkout develop
git merge upstream/develop        # resolve conflicts (mostly import lines)
tool/rebrand.sh                   # re-rename any new package:fladder/ imports
fvm flutter pub get
fvm flutter analyze               # must be clean before committing
git add -A && git commit          # finish the merge
git push origin develop
```

Tips that make merges painless:

- **Enable rerere once** so Git remembers how you resolved the recurring import
  conflicts and auto-applies them next time:
  ```bash
  git config rerere.enabled true
  ```
- If a merge conflict is *only* `package:fladder/` vs `package:driftfin/`, you can
  take **either** side and then run `tool/rebrand.sh` — it normalizes everything to
  `driftfin` regardless.
- Always use **`fvm flutter`** (pinned 3.47.5 via `.fvmrc`), not a system `flutter`.

## Releasing

Releases are built by [`.github/workflows/release.yml`](.github/workflows/release.yml)
on any pushed `v*` tag. **See the "Releases" section in `CLAUDE.md` for the current
tag scheme** (stable `vX.Y.Z` matching the pubspec version; nightly
`v<X.Y.Z>-nightly.YYYYMMDD.N`). The old `v<upstream>-driftfin.N` scheme is retired now
that the fork no longer tracks an upstream base version.

### The inherited upstream pipeline (disabled)

`.github/workflows/build.yml` is Fladder's full multi-platform pipeline (Android,
macOS, Linux/flatpak, Play Console, web deploy). It is **disabled** — it needs secrets
this fork doesn't have (Android keystore, Play Console, a `FLADDER_BOT` GitHub App) and
is retained only as a reference. Driftfin uses
`release.yml` instead. If you ever want Android or the full set, re-enable it (rename
`build.yml.disabled` → `build.yml`) and wire up those secrets.

## Known fork leftovers (cosmetic / deferred)

- **App icon & splash art** still use Fladder's image (`icons/production/fladder_icon.png`,
  referenced by `flutter_native_splash` + `icons_launcher`). Replace with a Driftfin logo
  PNG, then regenerate icons to fully rebrand the visuals.
- **l10n help text** in some translations still mentions `fladder:///login` (instructional
  strings only — functionally the scheme is `driftfin://`).
- **`ColorThemes.fladder`** — an internal color-theme enum value is still named `fladder`;
  left as-is because renaming it would break users' persisted theme preference.
- **Android / macOS / Linux** configs are not rebranded (not target platforms).
- **DonutWare's copyright** is intentionally preserved (correct under GPL-3.0).
