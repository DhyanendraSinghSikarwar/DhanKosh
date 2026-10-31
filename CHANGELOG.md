# Changelog

User-visible changes, newest first. Each pull request adds one line under `Unreleased`. Format: Added / Changed / Fixed.

## [Unreleased]

### Changed
- Home no longer shows the Accounts card, the Goals card or the Income / Expenses / Saved row; the Book tag shows only for Business.

### Added
- Calendar in Transactions shows the month total, a small amount in each day and the selected day's total.

### Fixed
- Insights on Home and Analysis hide rupee figures when amounts are hidden.

## [0.0.6] - 2026-10-31

### Changed
- Every tab and page now follows the approved design: DhanKosh Mint dark theme by default, filled rounded cards, floating pill navigation bar, compact grouped lists in More, Home cards in the approved order, Transactions with a compact filter row and a filter sheet, Analysis and Portfolio with the approved charts and cards.
- Notifications keep only what needs action (new transaction with two category guesses and More…, card bill, statement password, low balance, insurance, budget used up); the rest is recorded in the Activity log.

### Added
- Change category sheet from the new-transaction notification (More…).

### Fixed
- Saved mobile number no longer loses its last two digits and gains 91 on reload; pasted +91 numbers keep all 10 digits.
- Test for the scan log no longer fails when a timestamp happens to contain the amount digits.

## [0.0.5] - 2026-10-31

### Changed
- New look across the tabs: coloured icons, mint accent, pill-style bottom bar.
- Book (Personal, Business, All books) is chosen once in More and applies to every tab; a small tag shows when it is not Personal.
- Home: eye to hide all numbers, refresh with a progress sheet for SMS and email, Upcoming with a month calendar, Credit cards card (replaces Net worth) with card detail and editable statement values, Spend by category with sub-category drill-down.
- Transactions: single dropdowns for source and view.
- Analysis: sub-tabs Spend, Trends, Cash flow, Forecast.
- Portfolio: news button, asset classes (Stocks, Mutual funds, NPS, EPFO, Sukanya Samriddhi, PPF, FD/RD, Gold) with allocation and class filter.
- More: options grouped into sections; Accounts lists all accounts, wallets and cards; heart for Support on Profile.

## [0.0.4] - 2026-10-27

### Changed
- Total expense is now on a cash basis: account spends plus credit-card bill payments, never card purchases (ADR-0011). Transactions, categories and budgets still list card purchases, tagged Card or Account, with All/Accounts/Cards filters.

### Added
- Book and period scope bars, untracked-payment gaps, split and compare, account merge and personalisation, per-account charts.
- Charts: category donut drill-down, stacked 12-month bars, forecast fan, Sankey, savings-rate series, compare bars, heatmap; Category detail screen.
- Home sections with edit mode and presets, greeting header, spent trend, upcoming, insights; Portfolio split, allocation and loans sections.
- Email: code verification, multiple mailboxes, history window, sender lists, Welcome email sign-in; profile photo crop; occupation and alternate names.
- Alert actions (paid, snooze, category), screenshot OCR add, loan merge and EMI bars, tax share as PNG/PDF, brand logos and category icons, reduce-motion and backdrop settings.

## [0.0.3] - 2026-10-26

### Added
- Feature catalogue (`docs/FEATURES.md`) covering every feature of the original DhanKosh v2.9.8 with build status, a charts catalogue and a prioritised parity backlog.

## [0.0.2] - 2026-10-26

### Added
- Encrypted full backup and restore (passphrase, AES-256-GCM), monthly/yearly and portfolio PDF reports, tax-year summary export.
- Security: auto-lock timeout, lock now, block screenshots, failed-attempt delay, erase all data.
- Share a PDF, CSV or XLSX statement from another app into DhanKosh.
- Home: net worth card, Needs attention block, Inbox bell with unread count, goals card, privacy badge.
- Insights: income by source, subscriptions, credit utilisation. Filters: source and amount range.
- SIP tracker, optional MF NAV refresh (AMFI file, off by default), investment transactions list, card cycle spend and statement history.
- Savings goals, virtual round-ups and salary split plan.
- Weekly summary notification (off by default).
- In-app update: Check for updates, release history, verified download and install, Home notice, update notification and What's new sheet.

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
