# iOS CI and TestFlight

Driftfin's production iOS bundle identifier is `app.driftfin.79758DD3NW`.
The GitHub Actions workflow at `.github/workflows/release.yml` contains the
manual TestFlight path alongside the cross-platform release jobs. The iOS job
builds the `production` flavor once with Xcode 26.6 on a macOS runner, signs it when
TestFlight is selected, and stores the IPA as an artifact. The TestFlight job
downloads that artifact and uploads it to App Store Connect.

## One-time Apple setup

1. In App Store Connect, create an iOS app named **Driftfin** using the
   existing Bundle ID `app.driftfin.79758DD3NW`, English (U.S.) as the primary
   language, and an internal SKU such as `driftfin`.
2. In App Store Connect → Users and Access → Integrations → App Store Connect
   API, create an API key with the **App Manager** role. Download the `.p8`
   file immediately; Apple only provides it once.
3. Create or reuse an iOS App Store provisioning profile named
   `AppStore app.driftfin.79758DD3NW`.
4. Export the Apple distribution certificate and private key as a password-
   protected `.p12` file. Never commit the `.p12`, `.p8`, or their passwords.
5. Create an internal TestFlight group in App Store Connect and add the
   intended testers after the first build has finished processing.

## GitHub Actions configuration

Create an environment named `testflight` in
`Ironside-Software/Driftfin`. Add these environment variables:

| Kind | Name | Value |
| --- | --- | --- |
| variable | `APPSTORE_ISSUER_ID` | App Store Connect Issuer ID |
| variable | `APPSTORE_API_KEY_ID` | API key ID for the downloaded `.p8` |

Add these environment secrets:

| Name | Value |
| --- | --- |
| `APPSTORE_API_PRIVATE_KEY` | Complete contents of `AuthKey_<id>.p8` |
| `APPSTORE_CERTIFICATES_FILE_BASE64` | Base64-encoded distribution `.p12` |
| `APPSTORE_CERTIFICATES_PASSWORD` | Password used when exporting the `.p12` |

The workflow does not print these values. Keep the `testflight` environment
protected if signing and uploads should require approval. Both the iOS signing
job and the TestFlight upload job use this environment.

## Running it

Run **Release Driftfin** manually from the Actions tab, set `testflight` to
`true`, and use `ref=develop` for a proof build. The ref applies to **every
platform** and is resolved to a single commit before any builds start. Leave it
blank to build the branch selected in Actions. The iOS job produces a signed IPA
instead of also compiling an unsigned copy. Other platform builds still run.
The upload job depends only on iOS, so unrelated platform failures do not block
TestFlight. Re-running a failed upload reuses the same IPA.

Tag pushes build unsigned iOS alongside the other platforms. GitHub Releases
require every platform to succeed; missing APKs and artifacts fail the build.
Pages downloads the Web artifact and adjusts its base URL to `/Driftfin/app/`
without recompiling. Android release and debug builds run in parallel. Manual
runs never publish GitHub Releases or Pages, even when dispatched on a tag.
TestFlight runs are serialized and are not cancelled by newer dispatches. The
TestFlight path does not submit the build for App Review or release it to the
App Store.

An upload is not the final acceptance check: wait for Apple processing, assign
the build to the internal group, install it through TestFlight, and exercise
login, server discovery, playback, downloads, and any iOS-specific flows.
