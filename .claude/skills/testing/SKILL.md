---
name: testing
description: Use when writing, running or reviewing tests in Hisaab (unit, widget/golden, integration, parser parity gate, coverage).
---

# Testing

1. Read the feature memory file section 15 (test cases) and section 16 (acceptance). Tag tests with FR-ids, e.g. `test('FR-06-12 rejects OTP', ...)`.
2. Unit tests first for domain: parser, dedup, balances, recurring detection, tax rules, CSV. Pure Dart, no device. Money asserted as integer paise.
3. Parser fixtures are ported from `../hisaab_apk/parser-core/src/test/.../corpus` (337 tests, 940 field checks), masked. A rule change is not done without a fixture. Parity gate: Dart output must match Kotlin on the shared corpus before Phase 1 acceptance.
4. Use `mocktail` for repositories and channels; Riverpod via `ProviderContainer(overrides: ...)`; Drift via in-memory DB.
5. Widget/golden tests for key screens and sheets in light and dark; goldens use dummy data only.
6. Integration (`integration_test`): ingest SMS -> ledger -> Home totals; statement import; app lock. Native channels mocked in Dart tests; Kotlin covered by Android instrumented tests.
7. Coverage targets: 90% for `domain` and parsers, 70% overall (`flutter test --coverage`).
8. Fixtures must contain no real SMS/emails/statements unmasked.
9. Run `flutter test` and `flutter analyze`; update memory section 15 if cases changed.
