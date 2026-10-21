# Hisaab (DhanKosh) Flutter Rebuild: Project Rules

Offline-first personal finance app for India. It builds one ledger from bank SMS, email, payment-app notifications and statements, recording each payment once.
Flutter rebuild (Android first) of the Kotlin app `hisaab_apk` v2.9.8; parity with it is the baseline, not a redesign.
All parsing and storage are on-device. Native code (SMS, notifications, Keystore, PDF text, widget) is Kotlin behind platform channels; everything else is Dart.

- Master plan (app-wide structure only): [plan.md](plan.md)
- Feature memory index: [memory/_index.md](memory/_index.md)
- Screen GIF index: [assets_reference/_screens_index.md](assets_reference/_screens_index.md)

## Status of the skeleton (unverified)

The Flutter SDK was not installed when the skeleton was authored, so nothing has been compiled. Treat the skeleton as unverified until `flutter pub get`, `flutter analyze` and `flutter test` have been run and pass. Fix what they report before building on it.

## Reference sources

- Android reference source: `../hisaab_apk` (READ-ONLY, never edit).
- Analysis of the existing app: [docs/analysis/existing_app_analysis.md](docs/analysis/existing_app_analysis.md).

## Memory Protocol (MANDATORY)

`memory/NN_<name>.md` is the single source of truth for each feature.

1. Before any work on a feature, read its memory file first (find it via `memory/_index.md`).
2. NEW feature: create `memory/NN_<name>.md` from `memory/_feature_template.md` (all 18 sections), register it in `memory/_index.md`, add exactly ONE row to the Feature Index (section 12) of `plan.md`. Change nothing else in `plan.md`.
3. CHANGE to an existing feature: edit only that feature's memory file and add a Change Log entry (date | change | reason). Update `Last Updated` and `Status`.
4. Never write feature details in `plan.md`, `CLAUDE.md`, or another feature's file. Link to the other feature's file instead.
5. `plan.md` changes only for app-wide structure (stack, architecture, folders, schema overview, navigation, roadmap, risks).
6. After every implementation, sync memory: requirements (FR-ids), data models, tables, rules, test cases and acceptance criteria must match the code.

Skills in `.claude/skills/` implement these workflows: `add-feature`, `update-feature`.

## Tech Stack

Flutter stable + Dart 3; Riverpod with codegen (`riverpod_annotation`); `go_router` (5-tab shell, deep links); Drift + SQLCipher (`sqlcipher_flutter_libs`); `freezed` + `json_serializable`; `workmanager`; Kotlin platform channels `sms`, `notifications`, `secure`, `pdf`, `widget`; `enough_mail`; `fl_chart`; `local_auth`, `flutter_secure_storage`; `very_good_analysis`; tests with `flutter_test`, `mocktail`, `integration_test`. Full table in plan.md section 2. Record pinned versions here once chosen (from `pubspec.lock`).

## Architecture Rules

- Clean Architecture, feature-first: `lib/features/<feature>/{data,domain,presentation}`.
- `domain` is pure Dart: no Flutter, Drift or platform-channel imports.
- `presentation` depends on `domain` only; `data` implements `domain` interfaces; wiring lives in `app/di`.
- Features never import another feature's `data` or `presentation`. Cross-feature use goes through `domain` interfaces or `shared`.
- Single ledger write path: the transaction repository (ingest, dedup, balance update in one DB transaction). Nothing else writes `transactions`.
- Money is integer minor units (paise). Never `double` for money. Format with en-IN grouping.
- Parsers are pure functions: `parse(source, sender, body, receivedAt) -> ParseResult`.

## Coding Conventions and Folder Rules

- Types `UpperCamelCase`, members `lowerCamelCase`, files `snake_case`; one public widget per file; suffixes `Screen`, `Sheet`, `Dialog`, `Notifier`, `Repository`, `Dao`.
- `very_good_analysis`, zero issues. `dart format` before finishing.
- Folders: `lib/app` (app, router, theme, DI), `lib/core` (db, channels, errors, utils, money), `lib/shared` (reusable widgets), `lib/features/...`. Kotlin in `android/app/src/main/kotlin/com/hisaab/`.
- Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`, `refactor:`, `chore:`); branches `feat/<feature-id>-<slug>`.
- UI copy: concise, no explanatory paragraphs.
- Traceability: code and tests reference FR-ids from the feature memory file (e.g. `// FR-06-12`).

## Commands

```
flutter pub get
flutter run
flutter build apk
flutter test
flutter analyze
dart run build_runner build -d
dart format .
```

## Definition of Done

- [ ] Feature memory file read before work and updated after (FR-ids, models, tables, rules, tests, acceptance criteria, Change Log, Last Updated).
- [ ] `dart run build_runner build -d` clean; `dart format .` applied.
- [ ] `flutter analyze` reports zero issues.
- [ ] `flutter test` passes; new rules have fixtures/tests; parser changes keep the parity gate green.
- [ ] Architecture rules respected (no cross-feature data/presentation imports, single ledger write path, paise only).
- [ ] No generated files hand-edited, no secrets, no unmasked real data.
- [ ] If UI changed: GIF captured (see `capture-screen-gif`) and `_screens_index.md` updated.

## Prohibited Actions

- No secrets (keys, passwords, tokens, keystores) in code, fixtures, logs or commits.
- Never send financial data off-device without explicit user consent. No analytics or remote logging.
- Never edit generated files (`*.g.dart`, `*.freezed.dart`); regenerate them.
- Never record real financial data in GIFs; dummy data only.
- No real SMS or emails in fixtures unless masked (names, account numbers, amounts, references, phone numbers, UPI ids).
- Never modify `../hisaab_apk`.
