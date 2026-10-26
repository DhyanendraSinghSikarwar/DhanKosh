# DhanKosh features

Feature catalogue for the DhanKosh Flutter rebuild, audited against the original Kotlin app v2.9.8 (`FEATURES.md`, wiki and source). Date of audit: 2026-10-27.

## How to read this

- **Spec** links to the feature memory file, the single source of truth for requirements.
- **Status** is verified against `app/lib` and `app/test`, not copied from memory Status lines.

| Status | Meaning |
|---|---|
| Done | Implemented in Dart or Kotlin with tests; behaviour matches the Kotlin app |
| Partial | Some of the capability exists; the Notes column says what is missing |
| Missing | Specified in memory but not implemented |
| Not possible | Cannot be delivered by the project alone (reason in Notes) |

- Kotlin code (SMS, notifications, PDF, widget, biometrics, installer) is compiled by CI only and has not been run on a device. Rows that depend on it are Done only where the Dart side and tests exist; the Notes column flags them.
- The gap backlog derived from this catalogue is [research/kotlin-parity-gap.md](research/kotlin-parity-gap.md).

## Overview

| Feature | Spec | Status | Notes |
|---|---|---|---|
| Offline-first, on-device parsing, no analytics or remote logging | [F-25](../memory/25_security_privacy.md) | Done | No analytics packages; network limited to email, updates, language packs, news, Support hand-off |
| Capture from bank SMS (rule-based) | [F-02](../memory/02_sms_ingestion.md), [F-06](../memory/06_transaction_parsing_engine.md) | Done | `parser_core` 598 tests; Kotlin receiver unverified on device |
| Capture from email (IMAP app password) | [F-03](../memory/03_email_ingestion.md) | Done | `enough_mail`; see Data sources for Gmail gaps |
| Capture from payment-app notifications | [F-04](../memory/04_notification_ingestion.md) | Done | Kotlin listener unverified on device; restricted-settings guidance in [F-01](../memory/01_onboarding_permissions.md) |
| Capture from statements (PDF, Excel, CSV) | [F-05](../memory/05_statement_import.md) | Done | Scanned PDFs excluded, see limits |
| Manual entry of transactions, accounts, cards, loans, holdings, recurring items | [F-08](../memory/08_transactions_ledger.md), [F-13](../memory/13_accounts_management.md), [F-15](../memory/15_loans.md), [F-16](../memory/16_portfolio.md), [F-12](../memory/12_recurring_transactions.md) | Done | Transactions, accounts, loans, holdings and recurring items have add/edit forms |
| Manual entry from a screenshot | [F-08](../memory/08_transactions_ledger.md) | Missing | No ML Kit text recognition; `add_transaction_screen.dart` notes OCR deferred |
| Each payment recorded once across sources | [F-07](../memory/07_dedup_review.md) | Done | Matcher in ingest path with tests; Compare and split UI missing, see Transactions |
| Bottom bar: Home, Transactions, Portfolio, Analysis, More | [F-17](../memory/17_dashboard_home.md) | Done | `app/router.dart` 5-tab shell |
| Global Book (Personal, Business, All) | [F-20](../memory/20_search_filters.md) | Missing | `AccountUsage` stored per account; no app-wide Book store, chip or sheet |
| Global Period filter across the app | [F-20](../memory/20_search_filters.md) | Partial | Home month and Analysis period exist separately; no shared store or chip row |

## Home

| Feature | Spec | Status | Notes |
|---|---|---|---|
| Greeting header with name, bell, sync and add buttons | [F-17](../memory/17_dashboard_home.md) | Partial | Inbox bell with unread badge done; no greeting header text, avatar, sync pill or add button on Home |
| Spent this month card (total, change vs previous, income/expenses/saved) | [F-17](../memory/17_dashboard_home.md), [F-10](../memory/10_expense_tracking.md) | Partial | `_SpentCard` shows spent and tiles; no previous-period change, no scope titles |
| Running line on the Spent card (this month vs last, cumulative) | [F-17](../memory/17_dashboard_home.md), [F-37](../memory/37_charts_catalogue.md) | Missing | No chart on `_SpentCard` |
| Foldable per-account and per-card list on the Spent card | [F-17](../memory/17_dashboard_home.md) | Partial | `HomeAccountsStrip` exists; not folded, no share of total |
| Credit card dues with Mark paid | [F-14](../memory/14_credit_cards.md), [F-17](../memory/17_dashboard_home.md) | Done | `cardsSection` on Home with Mark paid (`card_tile.dart`) |
| Cash flow card (income vs spend, savings rate) | [F-11](../memory/11_income_tracking.md), [F-17](../memory/17_dashboard_home.md) | Done | `HomeCashFlowCard`; no split bar |
| Upcoming (bills, EMIs, insurance, card dues) | [F-12](../memory/12_recurring_transactions.md), [F-17](../memory/17_dashboard_home.md) | Missing | Needs-attention block lists bills due; no Upcoming card |
| Insights carousel | [F-18](../memory/18_analytics.md), [F-17](../memory/17_dashboard_home.md) | Missing | Insights exist on Analysis only |
| Spend by category donut on Home | [F-17](../memory/17_dashboard_home.md), [F-37](../memory/37_charts_catalogue.md) | Missing | Donut only on Analysis |
| Recent transactions | [F-17](../memory/17_dashboard_home.md) | Done | `HomeRecentList` |
| Budgets rings (hidden by default) | [F-10](../memory/10_expense_tracking.md), [F-17](../memory/17_dashboard_home.md) | Partial | Rings done; not hidden by default because sections are not configurable |
| Show, hide and reorder Home sections | [F-28](../memory/28_theming_customisation.md), [F-17](../memory/17_dashboard_home.md) | Missing | No layout store or edit mode |
| Presets (Minimal, Spender, Investor, Business, Everything) | [F-28](../memory/28_theming_customisation.md) | Missing | The Kotlin `apply()` has no caller in 2.9.8 either; FEATURES.md still lists presets |
| Mask amounts | [F-25](../memory/25_security_privacy.md) | Done | `amount_masking.dart`, privacy badge |
| Net worth card, Needs attention block, goals card | [F-17](../memory/17_dashboard_home.md), [F-36](../memory/36_goals_roundups_salary_plan.md) | Done | Additions beyond Kotlin (Fold adoption) |

## Transactions

| Feature | Spec | Status | Notes |
|---|---|---|---|
| List view with day groups | [F-08](../memory/08_transactions_ledger.md) | Done | `transactions_ledger_screen.dart` |
| Calendar view | [F-08](../memory/08_transactions_ledger.md) | Done | `ledger_calendar_view.dart` |
| By merchant view | [F-08](../memory/08_transactions_ledger.md) | Done | `ledger_merchant_view.dart` |
| Summary strip Income, Expenses, Net | [F-08](../memory/08_transactions_ledger.md) | Done | `ledger_summary_strip.dart` |
| Filters: type, bank, source, category; search with match count | [F-20](../memory/20_search_filters.md) | Done | Source filter and amount range added 2026-10-26 |
| Review banner for transactions needing attention | [F-07](../memory/07_dedup_review.md), [F-17](../memory/17_dashboard_home.md) | Done | Needs-attention card and `/review` |
| Detail page (merchant, category, method, account, source messages, note) | [F-08](../memory/08_transactions_ledger.md) | Done | `transaction_detail_screen.dart` |
| Foreign-currency rupee value on detail | [F-23](../memory/23_forex_rates.md), [F-08](../memory/08_transactions_ledger.md) | Partial | Rate store done; detail row pending |
| Edit category and sub-category; learn rule on change | [F-09](../memory/09_categorization.md) | Partial | Category and rule learning done; sub-categories limited |
| Change account with Remember for this payee | [F-08](../memory/08_transactions_ledger.md), [F-13](../memory/13_accounts_management.md) | Missing | No account picker on detail |
| Merge two transactions by hand | [F-07](../memory/07_dedup_review.md), [F-08](../memory/08_transactions_ledger.md) | Done | Multi-select merge (`_bulkMerge`) |
| Split merged transactions again | [F-07](../memory/07_dedup_review.md), [F-08](../memory/08_transactions_ledger.md) | Missing | No split operation in repository |
| Compare view for possible duplicates | [F-07](../memory/07_dedup_review.md) | Partial | Review screen basic; Compare pending |
| Multi-select delete and bulk category | [F-08](../memory/08_transactions_ledger.md) | Done | |
| Add manually | [F-08](../memory/08_transactions_ledger.md) | Done | Transfer form deferred |
| Add from screenshot | [F-08](../memory/08_transactions_ledger.md) | Missing | See Overview |
| Brand logos (about 140 bundled files) | [F-09](../memory/09_categorization.md) | Missing | No logo assets or widget |
| Card bill payments and own transfers never counted as spend or income | [F-08](../memory/08_transactions_ledger.md), [F-10](../memory/10_expense_tracking.md) | Done | `transfer_pairing.dart`, ledger tests |
| Own-account transfer entry form | [F-08](../memory/08_transactions_ledger.md) | Missing | Pairing of detected transfers is done |

### Categories and rules

| Feature | Spec | Status | Notes |
|---|---|---|---|
| Taxonomy with sub-categories and icons, auto-filing of known merchants | [F-09](../memory/09_categorization.md), [F-06](../memory/06_transaction_parsing_engine.md) | Partial | Categories and merchant filing done; sub-category icons and catalogue pending |
| Custom categories and sub-categories with icon picker | [F-09](../memory/09_categorization.md) | Partial | Custom categories in `category_repository_impl.dart`; no icon picker |
| Rules screen: exact or text match, apply to past, overrides automatic | [F-09](../memory/09_categorization.md) | Done | `rules_screen.dart`, `rule_editor_sheet.dart` |
| Rules learned from edits | [F-09](../memory/09_categorization.md) | Done | `merchant_rule.dart` |
| Category detail screen with sub-category donut | [F-09](../memory/09_categorization.md), [F-37](../memory/37_charts_catalogue.md) | Missing | No category detail route |

## Accounts and cards

| Feature | Spec | Status | Notes |
|---|---|---|---|
| Accounts, credit and debit cards, deposits, loans created from messages | [F-13](../memory/13_accounts_management.md), [F-02](../memory/02_sms_ingestion.md) | Done | Phone numbers excluded by parser |
| Balances recomputed from every source; newer stated balance wins | [F-13](../memory/13_accounts_management.md) | Done | Account repository with tests |
| User-set balance carried forward | [F-13](../memory/13_accounts_management.md) | Done | `manualBalanceMinor` |
| Personal or Business marking | [F-13](../memory/13_accounts_management.md), [F-20](../memory/20_search_filters.md) | Partial | Field stored; no UI to set it, no Business badge |
| Nickname | [F-13](../memory/13_accounts_management.md) | Done | Rename action |
| Colour | [F-13](../memory/13_accounts_management.md) | Partial | `colorArgb` stored; no picker |
| Card network logo | [F-13](../memory/13_accounts_management.md) | Partial | `cardNetwork` stored; no logo assets |
| Link debit card to bank account | [F-13](../memory/13_accounts_management.md) | Partial | `linkedAccountId` stored; no linking UI |
| Account detail with 6M / 1Y / all spend and income lines | [F-13](../memory/13_accounts_management.md), [F-37](../memory/37_charts_catalogue.md) | Missing | Detail shows recent activity only |
| Count tabs and Book filtering on the list | [F-13](../memory/13_accounts_management.md) | Missing | Accounts and Cards groups only |
| Merge duplicates into a display group and Unmerge | [F-13](../memory/13_accounts_management.md) | Partial | `mergedIntoId` and repository merge; no merge UI, no Unmerge |
| Restore missing accounts | [F-13](../memory/13_accounts_management.md) | Missing | |
| Hide (undoable) and delete (optionally with transactions) | [F-13](../memory/13_accounts_management.md) | Done | `account_actions.dart` |
| Bank unlock details per account, sealed, inherited from profile | [F-27](../memory/27_profile.md), [F-25](../memory/25_security_privacy.md) | Done | `bank_details_sheet.dart` |

### Credit cards

| Feature | Spec | Status | Notes |
|---|---|---|---|
| Outstanding, billed, minimum due, due date, unbilled, limit, limit left | [F-14](../memory/14_credit_cards.md) | Done | `/cards` |
| Estimated bill when no statement arrives | [F-14](../memory/14_credit_cards.md) | Done | |
| Edit amounts with calculated value and reset | [F-14](../memory/14_credit_cards.md) | Done | Edit amounts sheet |
| Mark paid | [F-14](../memory/14_credit_cards.md) | Done | |
| Reminders 5 days, 2 days and on due date; Remind tomorrow | [F-14](../memory/14_credit_cards.md), [F-21](../memory/21_alerts_reminders.md) | Missing | Rules exist; worker scheduling and action buttons pending |
| Only credit cards listed; unknown type counts with a limit in alerts | [F-14](../memory/14_credit_cards.md) | Done | |
| Forex markup per card | [F-14](../memory/14_credit_cards.md), [F-23](../memory/23_forex_rates.md) | Partial | `forexMarkupBps` column and maths; no UI |

## Payment tracking

| Feature | Spec | Status | Notes |
|---|---|---|---|
| UPI and payment-app notification layouts; unreadable reasons in Activity | [F-04](../memory/04_notification_ingestion.md), [F-22](../memory/22_activity_log.md) | Partial | Notification entries not recorded in the log |
| Notification access warning | [F-04](../memory/04_notification_ingestion.md), [F-01](../memory/01_onboarding_permissions.md) | Done | `NotificationAccessCard` |
| Payment-app notification never creates an account | [F-04](../memory/04_notification_ingestion.md) | Done | |
| Deduplication across SMS, email, notification, card alert; 30-minute rule for equal amounts | [F-07](../memory/07_dedup_review.md) | Done | Matcher tests |
| Balances and limits applied once per payment | [F-07](../memory/07_dedup_review.md), [F-13](../memory/13_accounts_management.md) | Done | |
| Untracked payments: detect from next stated balance, Add / Assign / Ignore | [F-13](../memory/13_accounts_management.md), [F-21](../memory/21_alerts_reminders.md) | Missing | Alert rule only; no gap detection or card |
| Transfers between own accounts record both legs; transfer to card is a card payment | [F-08](../memory/08_transactions_ledger.md), [F-14](../memory/14_credit_cards.md) | Done | |
| Card bill payments (SMS, UPI, NEFT, CRED, app) never spend or income | [F-06](../memory/06_transaction_parsing_engine.md), [F-08](../memory/08_transactions_ledger.md) | Done | |
| Promotional and balance lines not read as amount; OTP rejected | [F-06](../memory/06_transaction_parsing_engine.md) | Done | Parity gate |

## Portfolio

| Feature | Spec | Status | Notes |
|---|---|---|---|
| Portfolio value and gain | [F-16](../memory/16_portfolio.md) | Done | |
| Net worth card with 1M, 6M, 1Y, 3Y, All ranges | [F-16](../memory/16_portfolio.md), [F-37](../memory/37_charts_catalogue.md) | Done | `portfolio_screen.dart`, `net_worth_chart.dart` |
| Split by account with legend | [F-16](../memory/16_portfolio.md), [F-37](../memory/37_charts_catalogue.md) | Missing | |
| Assets and liabilities breakdown | [F-16](../memory/16_portfolio.md) | Done | |
| Daily history recorded; earlier dates estimated from transactions | [F-16](../memory/16_portfolio.md) | Partial | Daily points done; history estimate pending |
| Customise what counts in net worth | [F-16](../memory/16_portfolio.md) | Done | `exclusions_sheet.dart`; cards listed, not counted |
| Asset allocation by class | [F-16](../memory/16_portfolio.md), [F-37](../memory/37_charts_catalogue.md) | Partial | Proportion bar with list; not a donut, no class filter |
| Holdings by class with invested, gain, return; add/edit | [F-16](../memory/16_portfolio.md) | Done | |
| Per-holding sparkline | [F-16](../memory/16_portfolio.md), [F-37](../memory/37_charts_catalogue.md) | Missing | |
| Maturity calendar, next 12 months, with maturity instruction | [F-16](../memory/16_portfolio.md) | Done | |
| Loans section on Portfolio | [F-16](../memory/16_portfolio.md), [F-15](../memory/15_loans.md) | Missing | Loans card pending |
| Hide and reorder Portfolio sections | [F-28](../memory/28_theming_customisation.md) | Missing | |
| SIP list, MF orders, NPS contributions | [F-12](../memory/12_recurring_transactions.md), [F-16](../memory/16_portfolio.md) | Done | Beyond Kotlin FEATURES.md |

### Statements and holdings sources

| Feature | Spec | Status | Notes |
|---|---|---|---|
| Statements page with matched rows, totals, Read again | [F-05](../memory/05_statement_import.md) | Done | `/statements` |
| Card, bank, CAS and broker statements (PDF, Excel, CSV) | [F-05](../memory/05_statement_import.md) | Done | Kotlin PdfBox bridge unverified on device |
| CAS, NPS and EPF statements and SMS | [F-05](../memory/05_statement_import.md), [F-06](../memory/06_transaction_parsing_engine.md) | Done | |
| Groww-style fund and SIP emails update holdings | [F-05](../memory/05_statement_import.md), [F-03](../memory/03_email_ingestion.md) | Partial | MF-order and NPS email-body steps pending |
| Holdings files from Groww, Zerodha, Kuvera, INDmoney | [F-05](../memory/05_statement_import.md) | Done | Column-name reader |
| Statement updates card limits and balances; mismatch notification | [F-05](../memory/05_statement_import.md) | Done | |
| Foreign-currency totals from Forex rates | [F-23](../memory/23_forex_rates.md) | Done | |
| Share-in of PDF, CSV, XLSX from other apps | [F-05](../memory/05_statement_import.md) | Done | Beyond Kotlin; Kotlin side unverified |

## Loans

| Feature | Spec | Status | Notes |
|---|---|---|---|
| Detection from lender messages and EMI debits; add by hand | [F-15](../memory/15_loans.md) | Done | |
| Detail: terms, paid, outstanding, interest, next EMIs, amortisation schedule | [F-15](../memory/15_loans.md) | Done | `loan_detail_screen.dart` |
| EMIs in Bills | [F-12](../memory/12_recurring_transactions.md), [F-15](../memory/15_loans.md) | Done | |
| Link a payment to a loan; Not a loan | [F-15](../memory/15_loans.md) | Done | |
| Merge duplicate loans and Unmerge | [F-15](../memory/15_loans.md) | Missing | Duplicates UI pending |
| Next-EMIs principal/interest bars | [F-15](../memory/15_loans.md), [F-37](../memory/37_charts_catalogue.md) | Missing | Detail shows list, no chart |

## Analysis

| Feature | Spec | Status | Notes |
|---|---|---|---|
| Spending: category donut | [F-18](../memory/18_analytics.md), [F-37](../memory/37_charts_catalogue.md) | Partial | Donut done; no cross-filtering, no sub-category drill-down |
| 12-month bars with average | [F-18](../memory/18_analytics.md), [F-37](../memory/37_charts_catalogue.md) | Partial | Single-series bars and average text; not stacked by Essentials, Lifestyle, Other |
| Top merchants | [F-18](../memory/18_analytics.md) | Done | List; follows category selection in Kotlin only |
| When-you-spend heatmap | [F-18](../memory/18_analytics.md), [F-37](../memory/37_charts_catalogue.md) | Partial | Grid and peak text; cells not tappable |
| Budgets (monthly limits, on-track, near-limit) | [F-10](../memory/10_expense_tracking.md) | Done | `/budgets`, Budgets card |
| Cash flow: income vs spend, savings rate | [F-11](../memory/11_income_tracking.md), [F-18](../memory/18_analytics.md) | Partial | Income flow bars and rate; no Sankey, no savings-rate series |
| Where income went | [F-18](../memory/18_analytics.md) | Partial | Flow bars, not Sankey |
| Forecast: month-end projection | [F-18](../memory/18_analytics.md), [F-37](../memory/37_charts_catalogue.md) | Partial | Figures only; no fan chart |
| 30-day cash balance | [F-18](../memory/18_analytics.md), [F-37](../memory/37_charts_catalogue.md) | Done | `CashProjectionCard` line |
| Compare current vs previous by category | [F-18](../memory/18_analytics.md), [F-37](../memory/37_charts_catalogue.md) | Partial | Percent figures; no diverging bars |
| Filters: period (this/last month, FY, all, custom), Book, accounts or cards | [F-20](../memory/20_search_filters.md), [F-18](../memory/18_analytics.md) | Partial | Period segments; no Book, account filter or custom range |
| Hide and reorder Analysis sections | [F-28](../memory/28_theming_customisation.md) | Missing | |
| Income by source, Subscriptions, Credit utilisation | [F-18](../memory/18_analytics.md) | Done | Beyond Kotlin |

## Tax centre

| Feature | Spec | Status | Notes |
|---|---|---|---|
| Period: this FY, last FY, last 12 months | [F-19](../memory/19_tax_centre.md) | Done | |
| Income from tracked credits; refunds and own transfers excluded; Estimated marker | [F-19](../memory/19_tax_centre.md) | Done | |
| New and old regime side by side with rebate, surcharge, cess, recommendation | [F-19](../memory/19_tax_centre.md) | Done | `tax_rules.dart` table-driven, FY 2024-25 to 2026-27 |
| Expandable slab breakdown; old-regime deductions found | [F-19](../memory/19_tax_centre.md) | Done | |
| What-if calculator (never saved) | [F-19](../memory/19_tax_centre.md) | Done | `tax_what_if_sheet.dart` |
| Share as PDF | [F-19](../memory/19_tax_centre.md) | Done | Hidden-amounts confirm |
| Share as HD image | [F-19](../memory/19_tax_centre.md) | Missing | No PNG rendering |
| Share sheet hand-off | [F-19](../memory/19_tax_centre.md) | Missing | PDF saved; no system share |

## Alerts and reminders

| Feature | Spec | Status | Notes |
|---|---|---|---|
| New-transaction notifications with category buttons | [F-21](../memory/21_alerts_reminders.md) | Partial | Rules and poster; action buttons pending, Kotlin unverified |
| Budget threshold alerts and used-up notice | [F-21](../memory/21_alerts_reminders.md), [F-10](../memory/10_expense_tracking.md) | Partial | Rules done; alert posting pending |
| Card bill reminders with Mark paid | [F-21](../memory/21_alerts_reminders.md), [F-14](../memory/14_credit_cards.md) | Missing | |
| Recurring items on a month calendar | [F-12](../memory/12_recurring_transactions.md) | Done | Bills screen |
| Low-balance alerts three days ahead | [F-21](../memory/21_alerts_reminders.md), [F-12](../memory/12_recurring_transactions.md) | Partial | Rule present; scheduling pending |
| Recurring detection after two repeats; add own, monthly or yearly | [F-12](../memory/12_recurring_transactions.md) | Done | |
| Notification and SMS access prompts with settings shortcuts | [F-01](../memory/01_onboarding_permissions.md) | Done | |
| Weekly summary | [F-21](../memory/21_alerts_reminders.md) | Done | Beyond Kotlin |

## Data sources and sync

| Feature | Spec | Status | Notes |
|---|---|---|---|
| SMS inbox scan, live receiver, 14-day catch-up | [F-02](../memory/02_sms_ingestion.md) | Done | Kotlin unverified on device |
| Email by app password with 6-digit verification code | [F-03](../memory/03_email_ingestion.md) | Partial | App password sync done; verification code not built |
| Gmail sign-in | [F-03](../memory/03_email_ingestion.md) | Not possible | Needs a Google OAuth client registered by the owner (ADR pending); IMAP with a Gmail app password works |
| Several mailboxes | [F-03](../memory/03_email_ingestion.md) | Missing | Single account; no loop over logins |
| Per-provider app-password guides | [F-03](../memory/03_email_ingestion.md) | Partial | Provider chips; guides not written |
| History window 7 to 365 days; change re-reads | [F-26](../memory/26_settings_data_sources.md), [F-03](../memory/03_email_ingestion.md) | Missing | Setting key only; no UI, no re-read |
| Payment-app notifications on or off | [F-04](../memory/04_notification_ingestion.md), [F-26](../memory/26_settings_data_sources.md) | Done | |
| Editable bank sender and mail-domain lists | [F-26](../memory/26_settings_data_sources.md), [F-03](../memory/03_email_ingestion.md) | Partial | Email sender list editable; SMS sender list not editable |
| Nightly email sync | [F-03](../memory/03_email_ingestion.md) | Missing | Runner exists; no scheduler |
| Nightly SMS catch-up | [F-02](../memory/02_sms_ingestion.md) | Done | WorkManager scan; unverified on device |
| Sync button with progress pill | [F-17](../memory/17_dashboard_home.md), [F-26](../memory/26_settings_data_sources.md) | Missing | |
| Activity log | [F-22](../memory/22_activity_log.md) | Done | `/activity`; notification and statement counts not logged |
| CSV import and export; duplicates skipped | [F-24](../memory/24_backup_export.md) | Done | Encrypted full backup also done |
| Market news (Today, Week, Month) | [F-31](../memory/31_news_support_updates.md) | Done | `/news` |
| Forex rates by date | [F-23](../memory/23_forex_rates.md) | Done | `/settings/forex` |

## Statements and passwords

| Feature | Spec | Status | Notes |
|---|---|---|---|
| Locked PDFs show the email they arrived with | [F-05](../memory/05_statement_import.md) | Done | |
| Saved passwords tried on every locked and new statement | [F-05](../memory/05_statement_import.md), [F-27](../memory/27_profile.md) | Done | |
| Candidate passwords from profile and per-account details | [F-27](../memory/27_profile.md), [F-05](../memory/05_statement_import.md) | Done | |
| Statement mails picked by sender and subject | [F-03](../memory/03_email_ingestion.md), [F-05](../memory/05_statement_import.md) | Done | |
| Scanned images | [F-05](../memory/05_statement_import.md) | Not possible | No OCR path; documented limit |

## Profile, themes and languages

| Feature | Spec | Status | Notes |
|---|---|---|---|
| Profile fields (name, email, phone, DOB, PAN, names and mobiles per bank) | [F-27](../memory/27_profile.md) | Done | `profile_screen.dart` |
| Occupation | [F-27](../memory/27_profile.md) | Missing | |
| Photo with crop, zoom, rotate | [F-27](../memory/27_profile.md) | Missing | No image picker or cropper |
| First-run sign-in by verified email or phone | [F-01](../memory/01_onboarding_permissions.md) | Partial | Welcome and permission UI done; verified sign-in pending |
| Palettes: DhanKosh, Fold, Classic, Emerald, Graphite, Indigo Night, Saffron, Ocean, plus Hero and Cinema groups (22 in all) | [F-28](../memory/28_theming_customisation.md) | Done | `palettes.dart` |
| Light, dark, pure-black dark mode | [F-28](../memory/28_theming_customisation.md) | Done | |
| Text size | [F-28](../memory/28_theming_customisation.md) | Done | |
| Languages: English plus 7 downloadable packs, removable | [F-29](../memory/29_localization.md) | Partial | Packs and download done; screens not yet converted to `t()`; verify removal |
| Customise tab sections (Home, Analysis, Portfolio) | [F-28](../memory/28_theming_customisation.md) | Missing | Appearance section only |
| Backdrop and reduce-motion | [F-28](../memory/28_theming_customisation.md) | Missing | |

## Security and backup

| Feature | Spec | Status | Notes |
|---|---|---|---|
| App lock with biometric or screen lock; screen kept after unlock | [F-25](../memory/25_security_privacy.md) | Partial | Dart gate done; native prompt unverified on device |
| Mask balances at open | [F-25](../memory/25_security_privacy.md) | Done | |
| Secrets sealed with Android Keystore | [F-25](../memory/25_security_privacy.md) | Partial | `flutter_secure_storage` (Keystore-backed); not the custom sealed channel |
| CSV export and import | [F-24](../memory/24_backup_export.md) | Done | |
| Encrypted full backup and restore | [F-24](../memory/24_backup_export.md) | Done | Beyond Kotlin; card network, colour, limit and merge links not restored |
| In-app updates from GitHub Releases, SHA-256, What's new | [F-31](../memory/31_news_support_updates.md) | Done | Installer hand-off unverified on device |
| Auto-lock timeout, block screenshots, erase all data | [F-25](../memory/25_security_privacy.md) | Done | Beyond Kotlin; FLAG_SECURE unverified |

## Support

| Feature | Spec | Status | Notes |
|---|---|---|---|
| Support page with 100, 200, 500 or custom amount and UPI hand-off | [F-31](../memory/31_news_support_updates.md) | Done | `/settings/support`; UPI ID not displayed |

## Supported banks, lenders and apps

| Feature | Spec | Status | Notes |
|---|---|---|---|
| Bank sender registry, mail domains, generic parser | [F-06](../memory/06_transaction_parsing_engine.md) | Done | Parity gate green |
| Card alerts including newer Axis layout and Axis statement SMS | [F-06](../memory/06_transaction_parsing_engine.md), [F-14](../memory/14_credit_cards.md) | Done | |
| Lender messages (banks, NBFCs) | [F-06](../memory/06_transaction_parsing_engine.md), [F-15](../memory/15_loans.md) | Done | |
| Payment apps via notifications; YONO SBI | [F-04](../memory/04_notification_ingestion.md) | Done | |
| Investment sources (CAS, NPS, EPFO, broker files) | [F-05](../memory/05_statement_import.md) | Done | |
| About 140 bundled brand logos | [F-09](../memory/09_categorization.md) | Missing | See Transactions |

## Charts and visualisations

Every chart in the Kotlin app was confirmed from `ui/charts/Charts.kt`, `ProtoCharts.kt` and the screens that call them. `AreaLineChart`, `GroupedBarChart` and `StackedArea` exist in the Kotlin code but have no callers in 2.9.8. Spec: [F-37](../memory/37_charts_catalogue.md).

| # | Chart (Kotlin screen) | Flutter screen and implementation | Status | Notes |
|---|---|---|---|---|
| C1 | Spend by category donut, cross-filters merchants and trend (Analysis) | Analysis, `CategoryDonutCard` (`fl_chart` PieChart) | Partial | No selection, no cross-filter, no sub-category drill-down |
| C2 | Spend by category donut, top 7 plus Others (Home) | None | Missing | |
| C3 | Sub-category donut (Category detail) | None | Missing | No Category detail screen |
| C4 | 12-month stacked bars Essentials, Lifestyle, Other with average (Analysis) | Analysis, `MonthlyTrendCard` (BarChart) | Partial | Single series; average shown as text |
| C5 | When-you-spend 7x8 heat grid with tap-to-read cell (Analysis) | Analysis, `HeatmapCard` (container grid) | Partial | No tap interaction |
| C6 | Top merchants (Analysis) | Analysis, `TopMerchantsCard` | Done | Ranked list |
| C7 | Budget rings (Home) | Home, `HomeBudgetsCard` (CircularProgressIndicator) | Done | |
| C8 | Budget progress (Analysis) | Analysis, `BudgetsCard` and `/budgets` | Done | Linear bars |
| C9 | Cash-flow Sankey income to spend groups (Analysis) | Analysis, `IncomeFlowCard` | Partial | Bars, not a Sankey |
| C10 | Savings-rate sparkline with average (Analysis) | Analysis, `SavingsRateCard` | Partial | Figures only |
| C11 | Forecast fan chart actual, expected, low/high, budget line (Analysis) | Analysis, `ForecastCard` | Partial | Text projection only |
| C12 | 30-day cash balance line (Analysis) | Analysis, `CashProjectionCard` (LineChart) | Done | |
| C13 | Compare current vs previous diverging rows (Analysis) | Analysis, `CompareCard` | Partial | Percent text, no bars |
| C14 | Net worth history line, 1M to All (Home card, Portfolio) | Portfolio, `NetWorthChart` (LineChart) | Partial | Portfolio only; Home card has no line; earlier history not estimated |
| C15 | Net worth split by account and class bar with legend (Portfolio) | None | Missing | |
| C16 | Asset allocation donut with class filter (Portfolio) | Portfolio, `_Allocation` | Partial | Proportion bar and list |
| C17 | Holding row sparkline (Portfolio) | None | Missing | |
| C18 | Account spend and income lines, 6M / 1Y / All (Account detail) | None | Missing | |
| C19 | Running line this vs last month cumulative (Home Spent card) | None | Missing | |
| C20 | Home cash-flow split bar income, spent, invested, saved (Home) | Home, `HomeCashFlowCard` | Partial | Figures; no split bar |
| C21 | Loan next-EMIs principal/interest stacked bars (Loan detail) | None | Missing | |
| C22 | Income vs spend bars (Income screen) | Income, `income_tracking_screen.dart` (BarChart) | Done | Flutter addition |

Result: 22 charts, 5 Done, 10 Partial, 7 Missing. The Kotlin "Safe to spend" ring (`HomeWidgets.kt`) is excluded by design (FR-17-23) and not in the Kotlin FEATURES.md.

## Limits and known gaps

- Android only; no iOS or web version.
- The Kotlin code (SMS, notifications, PDF, widget, biometrics, installer) has been built by CI only. Nothing here has been run on a device; treat Done rows that depend on it as unverified.
- Global Book and Period are not yet one app-wide filter; Business accounts cannot be marked in the UI.
- Screenshot add, brand logos, profile photo, section customisation, untracked-payment detection, split and history-window controls are specified but not built.
- Gmail sign-in cannot ship until the owner registers a Google OAuth client; app-password IMAP covers Gmail meanwhile. Outlook needs two-step verification before an app password can be created; Microsoft sign-in is not built.
- Several Analysis charts are simplified (stacked bars, Sankey, fan chart, diverging bars, drill-down).
- A transaction with no SMS, email or notification is not seen until a later stated balance reveals the gap, and the gap card is not built yet.
- Scanned (image-only) statements cannot be read.
- Notification reading depends on Android's notification access, which some phones restrict for APK installs (Allow restricted settings).
- Banks without a template go through the generic parser and may need a category correction.
- Tax figures are an estimate from tracked data, not a filing.
- Not part of the app: split and lend, credit score, manual tax inputs beyond the what-if calculator (see [F-34](../memory/34_planned_insights_backlog.md)).
