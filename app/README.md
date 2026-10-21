# Hisaab Flutter app (hand-written skeleton)

Nothing here has been compiled, analysed or tested: Flutter was not installed
when this skeleton was written. Dependency versions are unresolved guesses.

## Bring it up

From this directory (`app/`):

1. `flutter create --org com.hisaab --platforms android,ios .`
   (generates `android/` and `ios/`; it does not overwrite `lib/` or `pubspec.yaml`,
   but check `git status` afterwards and discard any generated `test/widget_test.dart`
   or `lib/main.dart` changes.)
2. Copy `android_stubs/MainActivity.kt` to
   `android/app/src/main/kotlin/com/hisaab/MainActivity.kt` (replace the generated one),
   and merge `android_stubs/AndroidManifest.permissions.xml` into
   `android/app/src/main/AndroidManifest.xml`. `SmsReceiver` and
   `HisaabNotificationListener` classes still need to be written.
3. `flutter pub upgrade` (re-resolve versions), then `flutter pub get`
4. `dart run build_runner build -d` (generates `app_database.g.dart`)
5. `flutter analyze`
6. `flutter test`

Known TODOs: SQLCipher wiring in `lib/core/db/app_database.dart`; platform
channel methods are stubs; very_good_analysis may flag style issues to fix.
