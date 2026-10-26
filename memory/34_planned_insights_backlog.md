# Planned Insights and Features Backlog (Not in the Existing App)

| Field | Value |
|---|---|
| Feature ID | F-34 |
| Status | Proposed |
| Priority | P2 |
| Phase | 5 |
| Last Updated | 2026-10-19 |

## 1. Description

This file is a holding area for ideas that the current DhanKosh app does not do, but that its own notes either plan or hint at. Examples are warning the user about bank charges they keep paying, flagging a credit card that is more than 30 percent used, spotting a missing monthly provident fund credit, and matching shopping order emails to payments. It also records features the developer deliberately dropped (goals, split and lend, credit score), a block that was removed from the Home screen but still exists in the code, and a list of software libraries that are installed but never used and should not be copied into the new app. Nothing in this file describes how the app works today; it is a list of possible future work.

## 2. What This Feature Will Do

- Keeps one clearly separated list of proposed items, each with where the idea came from.
- Gives each item a short requirement stub so it can be promoted into a real feature file when chosen.
- Records which items conflict with the app's stated scope rule, so they are not built by accident.
- Names the unused libraries that must not be ported.

Nothing in this file is built or promised. An item moves out of this file only when it gets its own `memory/NN_<name>.md` through the add-feature workflow.

### 2.1 Inputs

- Notes from the existing app: `doc/SPEC_NOTES.md`, `doc/PLAN.md`, `FEATURES.md`, the Gradle files and the Home screen code.
- The audit findings in `docs/audit/scan_5_outputs_strings_integrations.md`.
- Existing Flutter feature files that touch each idea.

### 2.2 Processing

1. List each idea with its source and current status in the old app.
2. Check whether the app's scope rule (only data that SMS, email, statements or notifications can fill) allows it.
3. Write a requirement stub (FR-34-xx) marked Proposed.
4. List the unused libraries after checking the build files and source.

### 2.3 Outputs

- The backlog table in section 3 and the stubs in section 5.
- A "do not port" dependency list (section 3.3).

### 2.4 Out of Scope

- Any behaviour that exists in the old app (those live in their own feature files).
- Building any item here.
- Account Aggregator, manual assets, live market prices and manual tax inputs: named as out of scope by the old app's scope rule (`doc/SPEC_NOTES.md:4-5`, `doc/PLAN.md:42`) and not proposed here.
- Dead code and dev-only screens other than those named in section 3.3 (see [Transaction parsing engine](06_transaction_parsing_engine.md) for the parser bench).

## 3. Behaviour in Existing App

This section records what the existing app does today about each idea: none of these ideas is implemented unless stated. Paths relative to `hisaab_apk/`.

Scope rule in force (`doc/SPEC_NOTES.md:3-5`): "build only what SMS, email, mailed statements or app notifications can fill"; out of scope there: goals, split and lend, credit score, manual assets, market prices, Account Aggregator. Dropped on 2026-10-06 (`doc/PLAN.md:42`): goals, split and lend, credit score, manual tax inputs. `FEATURES.md:220`: "Goals, split and lend, credit score and manual tax inputs are not part of the app."

### 3.1 Ideas the notes plan or hint at

"Ideas not built yet (tracked-data only)" (`doc/SPEC_NOTES.md:41-43`): bank-charges leakage insight, card utilisation over 30 percent insight, EPF missing-month insight, statement balance reconciliation tick, commerce enrichment (order email to UPI debit), full-text search.

| # | Idea | Existing-app status | Source | Related Flutter file |
|---|---|---|---|---|
| 1 | Bank-charges "leakage" insight | Not built; no code or spec | `doc/SPEC_NOTES.md:41-43`; scan 5 row 32 | [18 Analytics](18_analytics.md), [10 Expense tracking](10_expense_tracking.md) |
| 2 | Card utilisation over 30 percent insight | Not built | `doc/SPEC_NOTES.md:41-43` | [14 Credit cards](14_credit_cards.md) |
| 3 | EPF missing-month insight | Not built | `doc/SPEC_NOTES.md:41-43` | [16 Portfolio](16_portfolio.md), [11 Income tracking](11_income_tracking.md) |
| 4 | Commerce enrichment (order email linked to the UPI debit) | Not built | `doc/SPEC_NOTES.md:41-43` | [03 Email ingestion](03_email_ingestion.md), [07 Dedup and review](07_dedup_review.md) |
| 5 | Statement balance reconciliation tick | Not built (noted in 05, scan 5 row 32) | `doc/SPEC_NOTES.md:41-43` | [05 Statement import](05_statement_import.md) |
| 6 | Full-text search | Not built (noted in 20, scan 5 row 32) | `doc/SPEC_NOTES.md:41-43` | [20 Search and filters](20_search_filters.md) |
| 7 | Goals | Dropped by scope rule | `doc/SPEC_NOTES.md:5`; `doc/PLAN.md:42`; `FEATURES.md:220` | none |
| 8 | Split and lend | Dropped by scope rule | same | none |
| 9 | Credit score | Dropped by scope rule | same | none |
| 10 | Outlook (Microsoft) sign-in | Not built; guide asks for two-step verification first; OAuth needs an Azure app registration | `doc/PLAN.md:21` (item marked partial); `FEATURES.md:216` | [03 Email ingestion](03_email_ingestion.md) |
| 11 | Home "Safe to spend today" block | Removed from the default Home in 2.9.0 but code and text keys remain | `ui/home/HomeWidgets.kt:256-287`; `ui/home/HomeScreen.kt:223` (key `safe`); `lang/keys.json:979-980`; scan 5 row 31 | [17 Dashboard home](17_dashboard_home.md) |
| 12 | XIRR (annualised return per holding) | Not built. Needs dated cash-flow history (every buy, redemption and dividend per holding), which is not stored; not implemented ([ADR-0010](../docs/adr/0010-fold-ideas-adoption-rules.md)) | Fold adoption | [16 Portfolio](16_portfolio.md) |

Details of items found in the code:

- Item 11: `SafeWidget` is still wired to section key `"safe"` in `HomeScreen.kt:223` but `safe` is not a default section, and the maths remains in `HomeViewModel.build`. It shows "Safe to spend" with the line "Safe to spend today" for the current month, or "Daily spend" and "Average spent per day" for other periods (`HomeWidgets.kt:264,276`). Rule recorded in [17](17_dashboard_home.md) line 116: current month `max(0, base - spent - reservedBills) / daysLeft`, `base` = sum of budgets else income, `reserved` = non-income upcoming items due in the month, `daysLeft = monthLength - today.day + 1`. [17](17_dashboard_home.md) Open Question 4 (line 505) asks whether to keep the maths for a future widget or drop it.
- Item 10: `doc/PLAN.md:21` marks Outlook as partial: the guide says to turn on two-step verification first because app passwords are hidden until then; Microsoft sign-in is not built.
- Items 7 to 9 are listed here only because the audit asked for a consolidated "not in app" list (scan 5 Gaps 3); they conflict with the scope rule unless that rule is revised.

### 3.2 Related behaviour already present (for context, not proposals)

- Insight cards exist on Home (Heads up, Good news, Pattern; max 5; `ui/home/HomeWidgets.kt:359-387`), see [17](17_dashboard_home.md) and [10](10_expense_tracking.md). New insights above would be added to this mechanism.
- Credit card limits and billed amounts are stored per card ([14](14_credit_cards.md)); EPF and NPS balances come from SMS, email and statements ([16](16_portfolio.md)); bank charges appear as ordinary debits.

### 3.3 Unused dependencies: do not port

Verified in the Gradle files and source (`gradle/libs.versions.toml`, `app/build.gradle.kts`, search of all `.kt`, `.kts`, `.toml`, `.pro` files). None has a source import.

| Library | Version | Declared at | Wired into a module | Source use |
|---|---|---|---|---|
| Haze (`dev.chrisbanes.haze:haze`, blur) | 1.7.1 | `libs.versions.toml:30,112` | Yes: `app/build.gradle.kts:103` `implementation(libs.haze)` | None found |
| Coil (`io.coil-kt:coil-compose`) | 2.7.0 | `libs.versions.toml:31,113` | No | None |
| ColorPicker (`com.github.skydoves:colorpicker-compose`) | 1.1.4 | `libs.versions.toml:32,114` | No | None |
| Compose Charts (`io.github.ehsannarmani:compose-charts`) | 0.2.5 | `libs.versions.toml:29,111` | No | None (charts are custom painters, scan 5 row 16) |
| JetBrains Markdown (`org.jetbrains:markdown`) | 0.7.3 | `libs.versions.toml:37,121` | No | None (the only "markdown" hit in source is a comment in `ui/more/WhatsNew.kt:86`) |

- The Flutter app uses `fl_chart` and custom painters instead; none of these has a Flutter counterpart to add. Release notes are cleaned by regex, not a Markdown parser ([31](31_news_support_updates.md) FR-31-24).
- Used and therefore not in this list: Glance (home widget, [30](30_home_widget.md)), OpenCSV ([24](24_backup_export.md)), ML Kit text recognition, `profileinstaller` (declared at `app/build.gradle.kts:109`, but no baseline profile file exists; see [32](32_release_pipeline.md) section 3.4).
- Other dead items noted by the audit: `StackedArea` chart (`ProtoCharts.kt:144`, never called) and the unreachable parser bench screen (scan 5 rows 16, 25).

## 4. User Stories

All Proposed.

- As a user, I want to be told when bank fees, penalties and charges add up so I can avoid them.
- As a card user, I want a warning when I use more than 30 percent of a card's limit.
- As a salaried user, I want to know when my employer's provident fund credit did not arrive for a month.
- As a shopper, I want a UPI debit shown with the items from the order email that matches it.
- As a user, I want to see how much I can safely spend per day for the rest of the month.
- As an Outlook user, I want to connect my mailbox without creating an app password.
- As a user, I want savings goals and shared-expense tracking (only if the scope rule is changed).

## 5. Functional Requirements (FR-34-01 ...)

All items are Proposed and none is committed. Each is a stub to be expanded in its own feature file when chosen.

- FR-34-01 (Proposed): Bank-charges insight. Add up debits categorised as bank charges, fees, penalties and interest over the selected period and show an insight card with the total and a link to the transactions when it exceeds a threshold (threshold open). Source: `doc/SPEC_NOTES.md:41-43`.
- FR-34-02 (Proposed): Card utilisation insight. For each credit card with a known limit and billed or outstanding amount, flag when utilisation (outstanding divided by limit) is above 30 percent. Source: `doc/SPEC_NOTES.md:41-43`.
- FR-34-03 (Proposed): EPF missing-month insight. When EPF credits are tracked from SMS or statements and a month has no credit while neighbouring months do, show an insight naming the month. Source: `doc/SPEC_NOTES.md:41-43`.
- FR-34-04 (Proposed): Commerce enrichment. Link an order or receipt email to the matching UPI or card debit (by amount and time window) and show order details on the transaction without creating a second transaction. Source: `doc/SPEC_NOTES.md:41-43`; must respect the single-record rule ([07](07_dedup_review.md)).
- FR-34-05 (Proposed): Statement reconciliation tick. When a statement's closing balance equals the ledger balance for that date, show a verified tick on the account or statement. Source: `doc/SPEC_NOTES.md:41-43`; see [05](05_statement_import.md) and [13](13_accounts_management.md).
- FR-34-06 (Proposed): Full-text search over merchant, note and message text. Source: `doc/SPEC_NOTES.md:41-43`; see [20](20_search_filters.md).
- FR-34-07 (Proposed, conflicts with scope rule): Goals. Source: dropped by `doc/PLAN.md:42`; goals are not fed by SMS, email, statements or notifications, so they require the scope rule to change.
- FR-34-08 (Proposed, conflicts with scope rule): Split and lend. Same source and conflict as FR-34-07.
- FR-34-09 (Proposed, conflicts with scope rule): Credit score. Same source and conflict as FR-34-07; would need an outside data source, which conflicts with the on-device-only principle.
- FR-34-10 (Proposed): Outlook sign-in through Microsoft OAuth as an alternative to the app password. Source: `doc/PLAN.md:21`, `FEATURES.md:216`; needs an Azure app registration; must keep the rule that no financial data leaves the device without consent ([03](03_email_ingestion.md), [25](25_security_privacy.md)).
- FR-34-11 (Proposed): Safe to spend today. Re-introduce the Home block as an optional, hideable section using the rule in section 3.1 (item 11), or drop it. Source: `ui/home/HomeWidgets.kt:256-287`, [17](17_dashboard_home.md) line 116 and Open Question 4.
- FR-34-12 (Proposed, negative requirement): The Flutter app does not add the unused libraries in section 3.3 (Haze, Coil, ColorPicker, Compose Charts, JetBrains Markdown) or their Flutter equivalents unless a feature needs them.

## 6. Non-Functional Requirements (performance, battery, privacy, offline)

- Every item must stay on-device, with no analytics or remote logging (CLAUDE.md prohibited actions).
- Insights must be computed from stored data without network access and without slowing the Home screen (computed in a background isolate, results cached).
- Any new insight must be dismissible and must not be repeated every day (same dedupe idea as the existing alert keys, [21](21_alerts_reminders.md)).
- No item is committed to a release until promoted to its own feature file.

## 7. UI / Screens & User Flow (screen list + flow diagram)

N/A - this is a backlog, not a feature with screens. Where an item would appear: insight cards on Home (items 1 to 3, 5), transaction detail (item 4), Home section (item 11), search bar (item 6), Data sources (item 10).

## 8. Data Models (Dart entities + fields + types)

N/A - no models are defined for a backlog. Candidate fields are listed per item in section 5; for example an insight reuses the existing insight card model in [17](17_dashboard_home.md).

## 9. Database Tables / Changes

N/A - no tables or migrations are defined here. Items 4 (order details), 5 (reconciliation flag) and 7 to 9 would need new tables or columns; those belong to the feature files created on promotion (see the `drift-database` skill).

## 10. Business Rules & Logic (regex, parsing rules, algorithms, thresholds)

N/A - no rules are decided. Only two have a source: the 30 percent card utilisation threshold (`doc/SPEC_NOTES.md:41-43`) and the safe-to-spend formula recorded in [17](17_dashboard_home.md) line 116 (section 3.1). Thresholds for bank charges and the EPF gap logic are Open Questions.

## 11. Platform / Native Requirements (permissions, channels, background work)

N/A - no native work for the backlog as a whole. Item 10 (Outlook OAuth) would need a browser or custom-tab sign-in and a redirect scheme; no other item needs new permissions.

## 12. Dependencies (other features → link to their memory file; packages)

Features: [Dashboard home](17_dashboard_home.md), [Analytics](18_analytics.md), [Expense tracking](10_expense_tracking.md), [Credit cards](14_credit_cards.md), [Portfolio](16_portfolio.md), [Income tracking](11_income_tracking.md), [Email ingestion](03_email_ingestion.md), [Statement import](05_statement_import.md), [Search and filters](20_search_filters.md), [Alerts and reminders](21_alerts_reminders.md), [Release Pipeline](32_release_pipeline.md).

Packages: none chosen. Item 10 would need an OAuth library; the existing app avoids one (IMAP app password).

## 13. Folder Location (lib/features/<name>/...)

N/A - no folder is created for a backlog. On promotion each item gets its own `lib/features/<name>/{data,domain,presentation}` following the architecture rules.

## 14. Edge Cases & Error Handling

N/A - nothing is built. Cases to consider when an item is promoted: insight spam (dedupe), missing card limit (no utilisation insight), EPF accounts with several employers, order emails that match more than one debit, safe-to-spend with no budgets and no income (shows zero).

## 15. Test Cases (unit / widget / integration + sample fixtures)

N/A - no tests until an item is promoted. Placeholder cases to carry into the future feature files:

- TC-34-01 (FR-34-02): card limit 1,00,000.00 and outstanding 31,000.00 gives an insight; 30,000.00 does not.
- TC-34-02 (FR-34-03): EPF credits in Jan, Feb, Apr give an insight for March.
- TC-34-03 (FR-34-11): budgets 30,000.00, spent 12,000.00, bills due 3,000.00, 10 days left gives 1,500.00 per day (`(30000 - 12000 - 3000) / 10`).
- TC-34-04 (FR-34-12): the Flutter `pubspec.yaml` contains none of the libraries in section 3.3.

## 16. Acceptance Criteria

- AC-34-01: Every idea in `doc/SPEC_NOTES.md:41-43`, every scope exclusion and the Home safe-to-spend block appear in section 3 with a source (checked against scan 5 rows 31 to 33 and 41).
- AC-34-02: Nothing in this file is described as existing behaviour; every requirement is marked Proposed.
- AC-34-03: The dependency list in section 3.3 matches the Gradle files (TC-34-04).
- AC-34-04: An item leaves this file only by getting its own memory file, registered in `memory/_index.md`.

## 17. Open Questions

1. Which items, if any, are promoted to real features, and in which phase? Candidates by cost and fit with the scope rule: 1, 2, 5, 6, 11 (use data already on device) then 3 and 4.
2. Bank charges: which categories and merchants count as charges, what threshold triggers the insight, and is it per month or per financial year?
3. Card utilisation: use billed amount, unbilled amount or both, and what if the limit is unknown or edited by hand ([14](14_credit_cards.md))?
4. EPF: how to treat gaps from job changes, voluntary contributions or passbooks that arrive late?
5. Commerce enrichment: which senders and email formats, what matching window, and how to show items without a second transaction ([07](07_dedup_review.md))?
6. Goals, split and lend, credit score: keep dropped, or revise the scope rule? Credit score needs outside data and would conflict with on-device-only.
7. Outlook OAuth: is an Azure app registration acceptable, and does a hosted sign-in conflict with the no-remote-services principle?
8. Safe to spend: restore as a hideable section, fold into budgets, or drop the maths ([17](17_dashboard_home.md) Open Question 4)?
9. Account Aggregator, manual assets and market prices are excluded by the old scope rule; confirm they stay excluded for Flutter.
10. Should `profileinstaller` and a Baseline Profile equivalent be a Flutter startup goal ([32](32_release_pipeline.md) Open Question 9)?
11. The scope rule file (`doc/SPEC_NOTES.md`) says design tokens came from a prototype; whether any prototype ideas beyond those listed belong here is unknown.

## 18. Implementation Notes

N/A - not built yet.

## 19. Change Log (date | change | reason)

| Date | Change | Reason |
|---|---|---|
| 2026-10-19 | Created | Audit Gate gap |
