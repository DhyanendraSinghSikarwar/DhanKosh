# Kotlin parity gap backlog

Audit date: 2026-10-27. Source: Kotlin app v2.9.8 (`FEATURES.md`, wiki, source) against `app/lib` and `app/test`. Catalogue with per-feature status: [../FEATURES.md](../FEATURES.md).

Effort: S under 1 day, M 1 to 3 days, L over 3 days. Priority order inside each group is the recommended build order. FR ids below are the existing ids in each memory file; where an id is not stated the memory file's section 5 owns the requirement.

Totals: 48 Partial and 45 Missing rows in the catalogue (93), merged here into 40 backlog items. Not possible: Gmail sign-in (needs the owner's Google OAuth client) and scanned PDFs.

## A) Correctness and data integrity

| ID | Item | Memory file, FRs | Why it matters | Effort | Dependencies and risk | Order |
|---|---|---|---|---|---|---|
| A1 | Global Book (Personal, Business, All) store, chips, sheet; Book rule applied in every query | [20](../../memory/20_search_filters.md) FR-20-01, FR-20-02, FR-20-09 | Totals differ from Kotlin for anyone with Business accounts; every tab reads one filter | L | Touches Home, Analysis, Transactions, budgets; do first so later work reads one store | 1 |
| A2 | Shared Period store with custom range and chip row | [20](../../memory/20_search_filters.md) FR-20-01, FR-20-03..05 | Home, Analysis and Transactions disagree on period | M | Pairs with A1 | 2 |
| A3 | Mark account Personal or Business in UI, Business badge | [13](../../memory/13_accounts_management.md) FR-13-04, FR-13-06 | Book filter is useless without it | S | A1 | 3 |
| A4 | Untracked-payment gap detection and card (Add, Assign, Ignore) | [13](../../memory/13_accounts_management.md), [21](../../memory/21_alerts_reminders.md) | The documented known gap; ledger silently misses cash movements | L | Balance history per account; ledger write path only via repository | 4 |
| A5 | Split a merged transaction; Compare view for duplicates | [07](../../memory/07_dedup_review.md) | A wrong manual merge cannot be undone | M | Repository change in single write path | 5 |
| A6 | Net worth history estimate from transactions (36 month-ends) | [16](../../memory/16_portfolio.md) FR-16-05 | New installs show an empty or flat history | M | Account balance reconstruction | 6 |
| A7 | History window 7 to 365 days UI and re-read on change | [26](../../memory/26_settings_data_sources.md), [03](../../memory/03_email_ingestion.md) | Users cannot control how far back data is read | M | Re-read must be idempotent via dedup | 7 |
| A8 | Change account on a transaction with Remember for this payee | [08](../../memory/08_transactions_ledger.md), [13](../../memory/13_accounts_management.md) | Wrong account assignment cannot be corrected | S | Payee-account memory (see notification repair job in 04) | 8 |
| A9 | Merge accounts UI, Unmerge, Restore missing accounts | [13](../../memory/13_accounts_management.md) | Duplicate accounts inflate lists; hidden accounts unrecoverable | M | Repository merge exists | 9 |
| A10 | Email 6-digit verification code | [03](../../memory/03_email_ingestion.md) | Ownership proof before saving a login | M | Needs a send path; decide design offline (SMTP via same login) | 10 |
| A11 | Multiple mailboxes | [03](../../memory/03_email_ingestion.md) | Users with two addresses lose alert mail | M | Secret storage per account; sync loop | 11 |
| A12 | Card bill reminders and alert posting (budget, new transaction, low balance) with action buttons | [21](../../memory/21_alerts_reminders.md), [14](../../memory/14_credit_cards.md) | Missed card due dates cost money | L | Kotlin `alerts` channel unverified on device | 12 |
| A13 | Foreign-currency rupee value on detail, forex markup UI | [23](../../memory/23_forex_rates.md), [14](../../memory/14_credit_cards.md) | Foreign spends look wrong without the rupee value | S | Rates store done | 13 |

## B) Charts and visuals

Spec for all chart items: [37](../../memory/37_charts_catalogue.md).

| ID | Item (chart id) | Memory file, FRs | Why it matters | Effort | Dependencies and risk | Order |
|---|---|---|---|---|---|---|
| B1 | Donut selection, cross-filter and sub-category drill-down (C1) | [18](../../memory/18_analytics.md) FR-18-20, [37](../../memory/37_charts_catalogue.md) | Core Analysis interaction | M | Category detail (B3) | 1 |
| B2 | Stacked 12-month bars with average line (C4) | [18](../../memory/18_analytics.md) FR-18-05 | Shows Essentials against Lifestyle | S | `fl_chart` stacked rods | 2 |
| B3 | Category detail screen with sub-category donut (C3) | [09](../../memory/09_categorization.md), [37](../../memory/37_charts_catalogue.md) | Drill target from many charts | M | Sub-category taxonomy | 3 |
| B4 | Home spent running line this vs last month (C19) | [17](../../memory/17_dashboard_home.md) FR-17-06 | Headline Home visual | S | Cumulative daily query | 4 |
| B5 | Home category donut (C2) | [17](../../memory/17_dashboard_home.md) FR-17-11 | Parity of Home | S | Reuse C1 widget | 5 |
| B6 | Account detail spend and income lines 6M / 1Y / All (C18) | [13](../../memory/13_accounts_management.md) FR-13-17 | Per-account insight | M | Monthly totals query | 6 |
| B7 | Net worth split-by-account bar with legend (C15) and Home net worth line (C14) | [16](../../memory/16_portfolio.md), [17](../../memory/17_dashboard_home.md) | Explains where net worth sits | M | A6 for history | 7 |
| B8 | Asset allocation donut with class filter (C16) | [16](../../memory/16_portfolio.md) | Visual parity | S | | 8 |
| B9 | Forecast fan chart (C11) | [18](../../memory/18_analytics.md) | Month-end projection is only text | M | CustomPainter; no fl_chart equivalent | 9 |
| B10 | Cash-flow Sankey (C9) | [18](../../memory/18_analytics.md), [11](../../memory/11_income_tracking.md) | Income-to-spend flow | M | CustomPainter; accept bars if cost high | 10 |
| B11 | Savings-rate series (C10), compare diverging bars (C13) | [11](../../memory/11_income_tracking.md), [18](../../memory/18_analytics.md) | Trend and category change at a glance | S | | 11 |
| B12 | Heatmap cell tap (C5), Home cash-flow split bar (C20) | [18](../../memory/18_analytics.md), [17](../../memory/17_dashboard_home.md) | Interaction parity | S | | 12 |
| B13 | Holding sparklines (C17), loan EMI stacked bars (C21) | [16](../../memory/16_portfolio.md), [15](../../memory/15_loans.md) | Low-use detail charts | S | Needs previous-value history for holdings | 13 |

## C) Workflow features

| ID | Item | Memory file, FRs | Why it matters | Effort | Dependencies and risk | Order |
|---|---|---|---|---|---|---|
| C1 | Home section customise, reorder, hide, presets; same for Analysis and Portfolio | [28](../../memory/28_theming_customisation.md) FR-28-15..19, [17](../../memory/17_dashboard_home.md) FR-17-05 | Core personalisation | M | Layout store; open question on presets (28 section 17) | 1 |
| C2 | Home Upcoming and Insights cards; greeting header, sync pill, add button | [17](../../memory/17_dashboard_home.md) FR-17-01, FR-17-09, FR-17-10, FR-17-17, FR-17-18 | Home parity | M | Sync pill needs sync state stream | 2 |
| C3 | Screenshot add via on-device OCR | [08](../../memory/08_transactions_ledger.md) | Fast manual entry | L | ML Kit via platform channel or `google_mlkit_text_recognition`; APK size | 3 |
| C4 | Nightly email sync scheduler | [03](../../memory/03_email_ingestion.md) | Mail is only read when the user syncs | S | Runner exists; WorkManager | 4 |
| C5 | Editable SMS sender list | [26](../../memory/26_settings_data_sources.md) | Unknown senders cannot be added | S | Registry override store | 5 |
| C6 | Tax share as HD image and system share sheet | [19](../../memory/19_tax_centre.md) | Parity of sharing | M | `share_plus` or channel; RepaintBoundary render | 6 |
| C7 | Loan merge, unmerge and duplicates UI | [15](../../memory/15_loans.md) | Duplicate loans distort liabilities | M | | 7 |
| C8 | Debit card link UI, colour picker, card network logo | [13](../../memory/13_accounts_management.md) | Account personalisation | M | Logo assets (D1) | 8 |
| C9 | Own-transfer entry form | [08](../../memory/08_transactions_ledger.md) | Manual transfers | S | | 9 |
| C10 | Loans section on Portfolio; Portfolio MF-order and NPS email-body steps | [16](../../memory/16_portfolio.md), [05](../../memory/05_statement_import.md) | Portfolio parity | M | | 10 |
| C11 | Analysis filters: Book, account or card, custom range | [18](../../memory/18_analytics.md), [20](../../memory/20_search_filters.md) | Filter parity | M | A1, A2 | 11 |
| C12 | Per-provider app-password guides | [03](../../memory/03_email_ingestion.md) | Fewer failed email setups | S | Copy only | 12 |
| C13 | Verified first-run sign-in by email or phone | [01](../../memory/01_onboarding_permissions.md) | Seeds profile for statement passwords | M | Needs A10 | 13 |

## D) Polish

| ID | Item | Memory file, FRs | Why it matters | Effort | Dependencies and risk | Order |
|---|---|---|---|---|---|---|
| D1 | Bundled brand logos (about 140) and logo widget | [09](../../memory/09_categorization.md) | Recognisable ledger rows | L | Asset licensing; offline | 1 |
| D2 | Profile photo with crop, zoom, rotate; occupation field | [27](../../memory/27_profile.md) | Identity, header avatar | M | `image_picker` plus cropper | 2 |
| D3 | Sub-category icons and custom category icon picker | [09](../../memory/09_categorization.md) | Taxonomy parity | M | | 3 |
| D4 | String conversion to `t()`, verify pack removal | [29](../../memory/29_localization.md) | 7 languages only partly effective | L | Build-time key check | 4 |
| D5 | Backdrop, reduce-motion | [28](../../memory/28_theming_customisation.md) | Visual parity | M | | 5 |
| D6 | Restore card network, colour, limit and merge links from backup | [24](../../memory/24_backup_export.md) | Restore loses account personalisation | S | Depends on C8 fields | 6 |
| D7 | Activity log entries for notifications and statements | [22](../../memory/22_activity_log.md) | Explains skipped payments | S | | 7 |
| D8 | Device verification of Kotlin code (SMS, notifications, PDF, widget, biometrics, installer) | [32](../../memory/32_release_pipeline.md), [25](../../memory/25_security_privacy.md) | Nothing has run on a phone | M | Needs a device; blocks trust in many Done rows | 0 (do early) |

## Not possible without owner action

| Item | Reason |
|---|---|
| Gmail sign-in ([03](../../memory/03_email_ingestion.md)) | Needs a Google OAuth client registered by the owner and the `gmail.readonly` verification; use IMAP with a Gmail app password meanwhile |
| Scanned (image-only) statements ([05](../../memory/05_statement_import.md)) | No text layer; OCR out of scope |
