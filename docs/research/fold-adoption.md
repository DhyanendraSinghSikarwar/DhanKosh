# Fold teardown: what DhanKosh adopts, adapts and skips

Date: 2026-10-26. Sources: the owner's two notes (`fold-copy-vs-skip-for-our-app.md`, `fold-app-feature-breakdown.md`). Fold is a US bitcoin-rewards banking app; DhanKosh is a free, offline, on-device finance tracker for India. Only ideas and UX patterns are taken. Fold's name, logo, artwork, wording and feature names are not used, and the notes give no brand colours, so the existing own palettes stay ([ADR-0010](../adr/0010-fold-ideas-adoption-rules.md)).

Gate (all four must hold): works without a backend; needs no bank, issuer, custodian or KYC partner; costs nothing to run; sends no user data off the phone.

## Decisions

| Fold idea | Verdict | Where it lands |
|---|---|---|
| Home answers "what do I own / spent / need attention" | Adopt | [17](../../memory/17_dashboard_home.md): net-worth card, "Needs attention" block, month pill opens Insights, privacy badge, count-up |
| Bell and notification centre | Adopt | [22](../../memory/22_activity_log.md) becomes the Inbox: bell on Home with unread count |
| Unified timeline, filters, search, detail | Already built | [08](../../memory/08_transactions_ledger.md), [20](../../memory/20_search_filters.md); add source and amount-range filters |
| Review queue, duplicates, rules, transfer detection | Already built | [07](../../memory/07_dedup_review.md), [09](../../memory/09_categorization.md) |
| Insights hub: income by source, subscriptions, credit utilisation | Adopt | [18](../../memory/18_analytics.md) cards |
| Spend widget, other widgets | Partly built | [30](../../memory/30_home_widget.md) already has spend; more widgets deferred |
| Biometric lock, hide balances | Already built | [25](../../memory/25_security_privacy.md); add auto-lock timeout, lock now, block screenshots, failed-attempt alert, erase-all |
| Own PIN and recovery key | **Skip** | Device credential lock has no "forgot PIN" problem and stores no secret of ours; see ADR-0010 |
| Email/password login, KYC, SMS 2FA, QR web login, password reset | **Skip** | Needs a server |
| Statements/tax-document download | Adopt | [24](../../memory/24_backup_export.md): monthly/yearly PDF report, portfolio report; [19](../../memory/19_tax_centre.md): tax-year summary export |
| Encrypted backup and restore | Adopt (priority) | [24](../../memory/24_backup_export.md): the database key dies with the phone, so a passphrase-encrypted backup is the only recovery path |
| Auto-stack (scheduled buys) | Adapt | [12](../../memory/12_recurring_transactions.md): SIP tracker (detect, next date, total invested); no money moves |
| Round-ups | Adapt | New [36](../../memory/36_goals_roundups_salary_plan.md): virtual round-up tracker into a goal |
| Direct-to-bitcoin on paycheques | Adapt | [36](../../memory/36_goals_roundups_salary_plan.md): salary split plan versus actual |
| Frequency picker, stepped setup | Adopt | UI pattern for SIPs, goals, recurring items |
| Bitcoin tab layout | Adapt | [16](../../memory/16_portfolio.md): shortcuts (Import statement, Add holding, Add SIP), investment transactions list, "as of" dates |
| XIRR | **Defer** | Needs a cash-flow history we do not have; a number from partial data would mislead. Backlog in [34](../../memory/34_planned_insights_backlog.md) |
| Live prices | Adapt, optional | Public AMFI NAV file for mutual funds, user-enabled, download only, no user data sent |
| Credit tab | Adopt | [14](../../memory/14_credit_cards.md): this-cycle spend, statement history, late-payment flag, paid auto-verified by a matching debit |
| Pay-card button | **Skip** | Cannot pay; "Mark paid" exists |
| Share-to-app of emails/PDFs | Adopt | [05](../../memory/05_statement_import.md): Android share/open-with for PDF, CSV, XLSX |
| Weekly summary and local reminders | Adopt | [21](../../memory/21_alerts_reminders.md): weekly summary; no server push |
| Rewards, boosts, spin wheel, referrals, gift cards, bitcoin custody, Reserve, bill pay, glass nav, streaks/badges | **Skip** | Regulated, funded by a company, a sweepstakes risk, needs a server, or a gimmick against the objective |
| UI guidelines (cards, 8dp grid, one accent, empty-state actions, privacy badge, count-up, large text, ₹ grouping) | Adopt | Applied where touched; palettes unchanged |

Fold's own colours, logo, screens and copy are not copied: they are Fold's trademark and copyright, and the notes contain none.
