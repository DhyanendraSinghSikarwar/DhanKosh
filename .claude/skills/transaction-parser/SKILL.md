---
name: transaction-parser
description: Use when adding or changing SMS, email or notification parsing (sender registry, bank parsers, rejection rules, merchant normalisation) or porting a Kotlin parser to Dart.
---

# Transaction parser work

Rules live in memory files; read them, do not duplicate them here:
- Engine, sender registry, bank parsers, rejection rules: `memory/06_transaction_parsing_engine.md`
- SMS source: `memory/02_sms_ingestion.md`; email: `memory/03_email_ingestion.md`; notifications: `memory/04_notification_ingestion.md`

Steps:
1. Read `memory/06_transaction_parsing_engine.md` and the source feature file (02/03/04). Locate the Kotlin reference in `../hisaab_apk/parser-core/` (read-only).
2. Keep the parser pure Dart: `parse(source, sender, body, receivedAt) -> ParseResult`. No Flutter, Drift or channel imports; amounts as integer paise.
3. Fixtures first: port the relevant corpus from `../hisaab_apk/parser-core/src/test/.../corpus` into `test/parser/fixtures/` (mask names, account numbers, references, phones, UPI ids). A rule change is not done until a fixture exists for it.
4. Implement the rule; run `flutter test test/parser`.
5. Parity gate: the Dart parser must reproduce the Kotlin parser's output on the shared corpus (337 tests, 940 field checks) before Phase 1 is accepted. Do not relax expectations to make a test pass; investigate divergence against the Kotlin source.
6. Add negative fixtures for rejection rules (OTP, promo, balance-only, failed payments).
7. Update `memory/06_transaction_parsing_engine.md` (FR-ids, rules, test cases, Change Log).
