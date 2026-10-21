---
name: statement-parser
description: Use when adding or changing statement import (PDF, Excel, CSV), password unlock, or per-bank statement layouts.
---

# Statement parser work

Rules live in memory files; read them, do not duplicate them here:
- Statement import, passwords, screens: `memory/05_statement_import.md`
- Shared parsing rules and normalisation: `memory/06_transaction_parsing_engine.md`
- Related ingestion paths: `memory/02_sms_ingestion.md`, `memory/03_email_ingestion.md` (statement attachments), `memory/04_notification_ingestion.md` ("needs a password" alert)

Steps:
1. Read `memory/05_statement_import.md` and `memory/06_transaction_parsing_engine.md`. Check the Kotlin reference in `../hisaab_apk` (read-only).
2. PDF text comes from the native `pdf` channel (PdfBox-Android, password support); see `android-platform-channel`. Layout parsing over the extracted text is pure Dart. Excel/CSV use the `excel` and `csv` packages.
3. Build the candidate-password list from the Profile (feature 27) in domain code; never log or persist passwords in plain text (sealed via the `secure` channel).
4. Scanned/image PDFs are reported as unsupported, not parsed.
5. Rows go through the normal ingest path (dedup, categorisation, single ledger write path); never write `transactions` directly.
6. Fixtures: use synthetic or masked statement text in `test/statement/fixtures/`; never commit real statements.
7. Run `flutter test`, then update `memory/05_statement_import.md` (FR-ids, rules, tests, Change Log).
