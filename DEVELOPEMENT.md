# 🚀 Driftfin Dev Setup

## 🔧 Requirements

Ensure the following tools are installed:

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (latest stable)
- [Android Studio](https://developer.android.com/studio) (for Android development and emulators)
- [VS Code](https://code.visualstudio.com/) with:
  - Flutter extension
  - Dart extension

Verify your Flutter setup with:

```bash
flutter doctor
```

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/HamadTheIronside/Driftfin.git
cd Driftfin

# Install dependencies
flutter pub get
```

## 🐧 Linux Dependencies

If you're on **Linux**, install the `mpv` and build dependencies:

```bash
sudo apt install libmpv-dev clang cmake ninja-build pkg-config libgtk-3-dev libcurl4-openssl-dev openjdk-17-jdk-headless
```

## 🛠️ Running the App

1. **Connect a device** or launch an emulator.
2. In VS Code:
   - Select the target device (bottom right corner).
   - Press `F5` or go to **Run > Start Debugging**.
   - If prompted, select **"Run Anyway"**.

## ⚙️ Code Generation

Generate build files (e.g., for `json_serializable`, `freezed`, etc.):

```bash
flutter pub run build_runner build
```

> Tip: Use `watch` for continuous builds during development:
```bash
flutter pub run build_runner watch
```
Update localization definitions:
```bash
flutter gen-l10n
```
Format files to spec:
```bash
dart format --line-length 120 ./lib/
```

## 📦 Building a release APK (Android)

Debug builds run Dart in the JIT debug VM and feel sluggish. Release builds are
AOT-compiled and fast. To build a release APK:

```bash
flutter build apk --release --split-per-abi --flavor production
```

Output lands in `build/app/outputs/flutter-apk/app-<abi>-production-release.apk`
(one per ABI: `armeabi-v7a`, `arm64-v8a`, `x86_64`). Install the one matching your
device. This works with **no extra setup** — without a keystore the release build
is signed with the debug key (installable for personal use, just not publishable to
the Play Store).

### Signing with your own key (optional)

A keystore is a free, offline, self-signed file — no account or payment needed. Create
one once with the JDK's `keytool` (bundled with Android Studio / any JDK):

```bash
keytool -genkey -v -keystore android/app/keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias driftfin
```

Then create `android/app/key.properties` (both files are gitignored — never commit
them, and back up the keystore: updates must reuse the same key):

```properties
storePassword=<the store password you set>
keyPassword=<the key password you set>
keyAlias=driftfin
```

With those present, `flutter build apk --release` signs with your key automatically.
For CI signing, see the `KEYSTORE_BASE_64` secrets in [CLAUDE.md](CLAUDE.md) → Releases.

> R8/resource shrinking is disabled by default (see `android/app/build.gradle`) — the
> speedup is from AOT, not minification. To shrink the APK, flip `minifyEnabled` and
> `shrinkResources` to `true` and test on-device; keep rules live in
> `android/app/proguard-rules.pro`.

## 🐞 Crash Reporting (optional)

Driftfin ships with opt-in [Sentry](https://sentry.io) crash reporting, off by default. It stays fully inert — no SDK
init, no network calls — unless **both**:

1. The app was built with a DSN: `flutter build <target> --dart-define=SENTRY_DSN=https://examplePublicKey@o0.ingest.sentry.io/0`
   (Web deployments can instead set the `SENTRY_DSN` env var at container runtime — see [INSTALL.md](INSTALL.md) — so a
   single Web build can serve multiple Sentry projects.)
2. The user flips **Settings → Advanced → Send crash reports** in the app themselves.

See `lib/bootstrap/app_bootstrap.dart` (`sentryDsn`, `resolvedSentryDsn`) and `lib/main.dart` for how the two are combined.

## 🌐 Using a demo Server
You can use a fake server from Jellyfin.
https://demo.jellyfin.org/stable/web/