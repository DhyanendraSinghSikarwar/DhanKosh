# Development

## Prerequisites

- Flutter stable (3.47.x tested) with Dart 3, JDK 17, Android SDK (API 34+).
- Python 3.10+ for `tools/`.
- Reference sources (optional): `../hisaab_apk`, read-only.

## Setup

```
cd app
flutter pub get
dart run build_runner build -d      # generates *.g.dart / *.freezed.dart (git-ignored)
```

## Checks

From the repo root: `python3 tools/check_memory.py` and `python3 tools/check_architecture.py`.
From `app/`: `dart format .`, `flutter analyze`, `flutter test`. CI runs all of them.

## Run on your phone

**Option A, no local SDK (recommended to start).** Push your branch. In GitHub, Actions, open the latest "CI" run, download the artifact `hisaab-debug-apk`, unzip, copy `app-debug.apk` to the phone and install it. Allow "install unknown apps" for your file manager or browser. The APK is debug-signed, so it installs alongside nothing else and is for testing only.

**Option B, USB.** Enable Developer options and USB debugging, connect, then:

```
cd app
flutter devices
flutter run
```

SMS and notification access need the real device. On Android 13+ a sideloaded app is subject to "restricted settings": open App info, three-dot menu, Allow restricted settings, then grant SMS and notification access (feature [01](../memory/01_onboarding_permissions.md)).

## CI

`.github/workflows/ci.yml` jobs: **Docs and structure** (memory and architecture checks), **Analyse and test** (format, analyze, test), **Debug APK** (builds and uploads the artifact). No signing secrets are used. Release signing is the manual Release workflow below ([feature 32](../memory/32_release_pipeline.md)).

## Pinned versions

Flutter 3.47.7 (stable), Dart 3.x. Packages: `app/pubspec.lock`. The first build downloads the SQLCipher library through the `sqlite3` build hook.

## Releasing (F-32)

Direct-merge flow, no pull request: on `main`, run Actions, Release, Run workflow (optional `version` X.Y.Z). It runs the checks, bumps `app/pubspec.yaml` and `CHANGELOG.md` (`tools/prepare_release.py`), builds a signed APK, pushes one `chore(release)` commit and creates the GitHub Release (tag `v<version>`, asset `DhanKosh-<version>.apk`, notes ending in `sha256: <hex>`). Without `app/android/key.properties` local release builds fall back to debug signing.

Repository secrets (names only; never commit keys):

- `HISAAB_RELEASE_KEYSTORE`: base64 of the release keystore.
- `HISAAB_KEYSTORE_PASSWORD`: store and key password.
- `HISAAB_KEY_ALIAS` (optional, default `hisaab`).
- `SUPPORT_UPI_ID` (optional): donation UPI id passed as `--dart-define`; empty hides Support.

## Releasing (Android)

Actions -> Release -> Run workflow on `main`, with the new version (for example `3.0.0`; the Flutter app continues the Kotlin app's numbering, build number above 33). It checks, bumps, builds, commits the bump to `main`, tags and publishes `DhanKosh.apk` + sha256 to the release.
Signing: run `tools/make_keystore.sh` once on your computer, add the three secrets it prints, keep the `.jks` safe. Without those secrets the APK is signed with a throw-away key: it installs, but the next release cannot update it in place (uninstall first).
