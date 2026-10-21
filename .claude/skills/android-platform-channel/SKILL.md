---
name: android-platform-channel
description: Use when adding or changing Kotlin native code and its Dart bridge for SMS, notifications, Keystore secrets, PDF text or the home widget.
---

# Android platform channel

1. Read the owning feature file: sms -> 02, notifications -> 04, secure -> 25, pdf -> 05, widget -> 30. Permissions are listed in plan.md section 7.
2. Channels (fixed names): `sms`, `notifications`, `secure`, `pdf`, `widget`. Kotlin code lives in `android/app/src/main/kotlin/com/hisaab/`. Do not add new channel names without a plan.md update (app-wide structure).
3. Define the contract first in the feature memory file section 11 (method names, argument and result maps, error codes, event streams). Amounts cross the channel as integer paise.
4. Dart side: a thin source class in `features/<f>/data` (or `core/channels`) wrapping `MethodChannel`/`EventChannel`; expose through a `domain` interface so the rest of the app never sees a channel. Map `PlatformException` to domain errors.
5. Live SMS and notifications run via a Kotlin receiver/listener that starts a headless Dart entrypoint; keep that entrypoint minimal and route into the same ingest path.
6. Android manifest: declare only needed permissions (READ_SMS, RECEIVE_SMS, notification listener service, POST_NOTIFICATIONS, USE_BIOMETRIC); `allowBackup=false`.
7. Secrets: Keystore-backed via the `secure` channel / `flutter_secure_storage`; never log message bodies or passwords.
8. Tests: mock the channel in Dart (`TestDefaultBinaryMessengerBinding` / mocktail on the domain interface); native behaviour is covered by Android instrumented tests.
9. Update the feature memory file (section 11, Change Log).
