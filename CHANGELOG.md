# Changelog

User-visible changes, newest first. Each pull request adds one line under `Unreleased`. Format: Added / Changed / Fixed.

## [Unreleased]

### Added
- Encrypted full backup and restore (passphrase, AES-256-GCM), monthly/yearly and portfolio PDF reports, tax-year summary export.
- Security: auto-lock timeout, lock now, block screenshots, failed-attempt delay, erase all data.
- Share a PDF, CSV or XLSX statement from another app into DhanKosh.
- Home: net worth card, Needs attention block, Inbox bell with unread count, goals card, privacy badge.
- Insights: income by source, subscriptions, credit utilisation. Filters: source and amount range.
- SIP tracker, optional MF NAV refresh (AMFI file, off by default), investment transactions list, card cycle spend and statement history.
- Savings goals, virtual round-ups and salary split plan.
- Weekly summary notification (off by default).

## [0.0.1] - 2026-10-26

### Changed
- App name is DhanKosh with the original shield-and-rupee logo (launcher icon, welcome and about screens).

### Added
- Diagnostic log (More): on-device log of events and counts only, never messages or amounts; view, export as .txt, copy or clear.
- Capture: MF order mails, NPS contribution SMS, FD/RD/PPF and loan status messages are now recorded; capture coverage matrix and 77 end-to-end tests.
- Hardening: own-account transfer and card-bill pairing (no double counting), Calendar and By-merchant views, bulk actions, Rules screen, statement balances/limits/detail/email attachments, app lock no longer re-prompts around permission and file flows, Home SMS card.
- Phase 5: app lock, activity log, CSV backup/import, 22 themes and text size, language packs, home-screen widget, update check, support and about, signed-release workflow.
- Phase 5: home-screen spend widget, market news, Support (UPI hand-off), About and update check, signed release workflow.
- Phase 4: budgets, income and cash flow, bills calendar, loans, analytics, tax centre, alert notifications, manual forex rates.
- Phase 3: statement import (PDF/Excel/CSV, passwords), credit cards with due tracking, portfolio and net worth, profile; card-due and EPFO/NPS SMS recognised.
- Phase 2: payment-app notification ingestion, email ingestion over IMAP (app password), live SMS while the app is closed, nightly scan and email sync.
- Phase 1 core: bank-SMS parser (Kotlin parity, 940/940 corpus fields), encrypted ledger with dedup, accounts, categories, onboarding, Home, transactions, search, review, settings, sample data.
- Project structure: AGENTS.md, ADRs, research notes, CI (analyze, test, debug APK), memory and architecture checks.
