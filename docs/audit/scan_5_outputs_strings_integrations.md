# Scan 5: Outputs, strings/resources, integrations

Angle: what the Kotlin app 2.9.8 PRODUCES, what its string/resource files reveal, and what it talks to. Paths are relative to `hisaab_apk/` unless noted; `A/` = `app/src/main/kotlin/com/hisaab/app/`. Memory = `hisaab_flutter/memory/`. Line numbers approximate.

Overall: the specs are unusually complete on this angle. 44 items checked: 33 Full, 9 Partial, 2 Missing. Real gaps are in release/upgrade continuity and a few planned or removed items, not in user-visible behaviour.

## 1. Outputs

| # | Capability | Where found | Memory file | Coverage | Action | Notes |
|---|---|---|---|---|---|---|
| 1 | Channel `new_transactions` (LOW), notif id 10000+txId, up to 3 category buttons, "Saved as" confirmation (4 s) | A/notify/NewTransactionNotifier.kt:60-146 | 21 s2.1-2.2 | Full | None | Ids, request codes, alternatives algorithm all spelled out |
| 2 | Balance-updated notification id 9000, InboxStyle, once per account per IST day | A/notify/BalanceNotifications.kt:30-91 | 21 s2.3, 13 | Full | None | |
| 3 | Channel `budgets_bills` (DEFAULT): budget, low-balance bill, insurance renewal, untracked change | A/notify/Alerts.kt:40-180 | 21 s2.4-2.6 | Full | None | Texts verbatim; hashCode id collision noted in s17 |
| 4 | Card bill reminder id 30000+cardId*3, Mark paid / Remind tomorrow via CardDueActionReceiver | A/notify/CardDueReminders.kt:158-184 | 21 s2.7, 14 | Full | None | |
| 5 | Channel `statements` id 4000+id, "statement detected", opens unlock | A/notify/StatementNotifications.kt:20-72 | 21 s2.8, 05 | Full | None | |
| 6 | Daily `daily-alerts` worker; nightly 02:30 `nightly-sync`; `gmail-sync-periodic` / `gmail-sync-now`; `sms-scan` one-time | A/notify/Alerts.kt:203; A/sync/NightlySync.kt:21-45; email/.../GmailSyncWorker.kt:88-102; A/sms/SmsScanScheduler.kt | 21 s2.9, 02, 03 s151, 26 s348 | Full | None | Work names, policies, constraints present |
| 7 | `hisaab://` deep links (statements, budgets, bills, transaction, account) + manifest filters | AndroidManifest.xml:36-51 | 21 FR-21-15, 17, 12, 14, 15 | Full | None | No category/loan/tax link exists; none expected |
| 8 | Home-screen widget "DhanKosh spend" (Glance 3x2, 30 min period, refresh on tx change) | A/widget/SpendWidget.kt; res/xml/spend_widget_info.xml | 30 | Full | None | `widget_name`/`widget_description` strings ("Today's and this month's spending") not confirmed verbatim; trivial |
| 9 | Tax estimate share: PNG 1440 px and A4 PDF (vector text, footer "Page n of total"), cache `shared/`, ACTION_SEND chooser, real-amount confirm | A/ui/more/TaxReport.kt:32-105, TaxShare.kt:138-146 | 19 FR-19-10, s11 | Full | None | |
| 10 | CSV export (`CreateDocument text/csv`, 15 columns) and import (OpenDocument, hash dedupe) | A/csv/CsvTransfer.kt; A/ui/more/SecurityScreen.kt:64-95 | 24 | Full | None | Only user-facing backup; no cloud backup |
| 11 | Support: `upi://pay` chooser with amount 100/200/500/custom, QR bitmap (`support_qr.webp`, QrCode.kt), UPI id never shown | A/ui/more/SupportScreen.kt:60-150, QrCode.kt | 31 s53-54, FR-31-12 | Full | None | VPA masked in spec (complies with CLAUDE.md) |
| 12 | In-app update: GitHub latest release, APK download, SHA-256 check, FileProvider `${applicationId}.updates`, REQUEST_INSTALL_PACKAGES, daily gate | A/update/Updater.kt; update_paths.xml | 31 s63-64, FR-31-16/17, 26 `check_updates` | Full | None | Producer side of the contract is a gap, see row 38 |
| 13 | What's new sheet: GitHub notes cleaned (12 lines) else bundled changelog (`bundledChangelog`) | A/ui/more/WhatsNew.kt | 31 s79-80, FR-31-23 | Full | None | |
| 14 | Market news: 4 tabs, 14 RSS URLs, 10 min cache, dedupe, cap 200, open in browser | A/ui/news/NewsScreen.kt:90-150 | 31 s21-35 | Full | None | |
| 15 | Language pack download/remove (`raw.githubusercontent.com/.../lang/<code>.json`, tmp+rename) | A/i18n/I18n.kt:95-140 | 29 s46-53, FR-29-07/15 | Full | None | Pack has no checksum; spec records this |
| 16 | Charts: donut, grouped bars, area/net-worth line, Sparkline, ProgressRing, StackedMonthBars, Sankey, FanChart, HeatGrid, DivergingRow | A/ui/charts/Charts.kt, ProtoCharts.kt | 18, 17, 11, 28 | Partial | Expand 18 | Custom painters implied, not listed as one chart inventory with the widget-to-chart map. `StackedArea` (ProtoCharts.kt:144) is never called: dead code, do not port |
| 17 | Insight cards (Heads up / Good news / Pattern; See transactions / See bills / Dismiss; max 5) | A/ui/home/HomeWidgets.kt:359-387 | 10, 12 s99, 17 | Full | None | |
| 18 | Calendar views: Transactions month grid (value per kind) and Bills calendar | A/ui/transactions/TransactionViews.kt; A/ui/plan/BillsScreen.kt | 08 s26, FR-08-03, 12 | Partial | Expand 08 | Per-kind captions ("Daily spend/income/transfers/investments", "Flagged amounts by day") and colour switch (pos for income) not stated; trivial |
| 19 | Budget bullet bars with limit marker and "Today's pace" key | A/ui/analytics/AnalyticsBudgets.kt:140-165 | 10 FR-10-15 | Full | None | Legend string not cited |
| 20 | Photo crop output (circular, rotate, move and scale) | A/ui/profile/PhotoCrop.kt | 27 | Full | None | |
| 21 | Screenshot to transaction (ML Kit OCR, on-device) | A/ui/add/AddTransactionScreen.kt:266 | 08, 25 | Full | None | |
| 22 | Clipboard: "Copy text" on message view; Paste into app-password field | A/ui/components/MessageView.kt:60-82; A/ui/settings/EmailConnect.kt:186 | 25 s149 (paste only); 07 mentions MessageView | Partial | Expand 07 | "Copy text" on the original message is not stated as a requirement |
| 23 | Share intents other than tax | grep ACTION_SEND | n/a | Full | None | None exist (confirmed absent) |
| 24 | Launcher shortcuts, quick-add widget action, widget config | AndroidManifest.xml, res/xml | 30 | Full | None | Spec states tap only opens app |
| 25 | Parser bench screen (debug, unreachable) | A/ui/bench/ParserBenchScreen.kt:77 | 06 s429, 29 | Full | None | Listed as dev-only |

## 2. Strings, resources and docs (hidden, dev-only, removed, planned)

`lang/keys.json` has 1455 entries (not 1456); Memory 29 says 1455, consistent. All 1455 were read and clustered. Every cluster maps to a spec, except those flagged below.

| # | Capability / cluster | Where found | Memory file | Coverage | Action | Notes |
|---|---|---|---|---|---|---|
| 26 | Category and sub-category names (about 150 keys: Kirana, Quick commerce, PG & hostel, EV charging, Lab tests...) | keys.json 137-1217 | 06 s280-292, 09 | Full | None | |
| 27 | Palette names (20+): Rose Quartz, Lavender Bloom, Interstellar Dust, Vibranium, Iron Throne... Eye care | keys.json | 28 s29, FR-28-13 | Full | None | Spec notes FEATURES.md omits two palettes |
| 28 | Tax strings (80C, 80D, 24(b), 80CCD, HRA, slab, cess, disclaimers) | keys.json | 19 | Full | None | |
| 29 | Email verify, app-password guides ("Step 1: {step}", provider links), "checks every hour" text | keys.json 1355; A/ui/settings/AppPasswordGuide.kt; email/.../MailServers.kt | 03 s66-90, 22, 26 | Full | None | Stale "every hour" copy vs daily 02:30 is recorded as an inconsistency |
| 30 | Notification, alert, reminder strings (about 60) | keys.json | 21 | Full | None | |
| 31 | "Safe to spend today" and "Cash balance" Home block (removed from Home in 2.9.0 but code and keys live) | keys.json 979-980; HomeWidgets.kt:264-287 | 17 | Partial | Expand 17 | Confirm whether Safe to spend stays as a hideable section or is dropped; spec has one hit only |
| 32 | `SPEC_NOTES.md` "Ideas not built yet": bank-charges leakage insight, card utilisation over 30%, EPF missing-month insight, statement reconciliation tick, commerce enrichment, FTS search | doc/SPEC_NOTES.md:last section | 05 s614 (tick), 20 s85 (FTS) | Partial | Expand 18 (or plan.md roadmap row) | Leakage, utilisation, EPF-gap and commerce-enrichment are in no spec, not even as "out of scope". Add to Open Questions or Roadmap so they are not silently dropped |
| 33 | Scope exclusions (goals, split and lend, credit score, manual assets, market prices, Account Aggregator, Microsoft/Outlook OAuth) | FEATURES.md "Limits and known gaps"; SPEC_NOTES.md; PLAN.md:21 | 01, 03, 18, 20 | Partial | Expand plan.md risks row only | Outlook two-step note present in 03; a single consolidated "not in app" list is missing |
| 34 | SPEC_NOTES design tokens (bg #F7F7F5, accent #2F5BEA, 16dp cards, motion 200-400 ms) | doc/SPEC_NOTES.md | 28 | Partial | None | Source says these came from the v2 prototype; real palette is in `ui/theme`. 28 uses the code palette; no action unless parity with prototype is wanted |
| 35 | PLAN.md unfinished items: `[~]` language packs "text extraction + translations pending", GitHub wiki not pushed, BalanceGaps | doc/PLAN.md:30,91,198 | 29, 13 | Full | None | Packs now complete (1455 keys x 7) |
| 36 | doc/wiki (Getting started, FAQ, Forex, Privacy) | doc/wiki/*.md | 23, 03, 25 | Full | None | Wiki is stale (mentions History tab, month switcher); do not treat as source |

## 3. Integrations and absences

| # | Capability | Where found | Memory file | Coverage | Action | Notes |
|---|---|---|---|---|---|---|
| 37 | Network endpoints: IMAP/SMTP TLS, Gmail API (`gmail.readonly`, revoke), GitHub API + raw lang packs, 14 RSS feeds, UPI intent; cleartext off | email/.../GmailApi.kt:34, GmailAuthManager.kt:121-128, network_security_config.xml | 03, 25, 29, 31 | Full | None | |
| 38 | Release pipeline (producer of Updater contract): `release.yml` signs with apksigner v3 rotation lineage, names `DhanKosh-<ver>.apk`, writes `sha256:` line and "- " feature lines from commit bodies; `ci.yml` runs 4 test modules | .github/workflows/release.yml:95-135, ci.yml:34; AGENTS.md "Release" | 31 (consumer only) | Missing | Expand 31 + plan.md risk row | Flutter updater needs the same asset naming, `sha256:` line and a signing key that Android accepts as an upgrade. Nothing in memory describes the workflow, secrets list or notes format |
| 39 | Upgrade continuity: applicationId `com.hisaab.app`, signing lineage, Room-to-Drift data carry-over, Keystore alias reuse, `maintenance` one-time flags | AndroidManifest.xml, release.yml:104, A/HisaabApplication.kt:78-96 | 26 s330, s448 (open question only) | Missing | Expand 26 + 31 (or Create new file "upgrade_migration") | Nothing decides whether Flutter ships as an in-place update of the Kotlin app (same id and key, needs Room import and sealed-secret migration, which 26 says cannot migrate) or as a fresh install with CSV import (24). Highest-risk gap |
| 40 | Libraries with user-visible effect: ML Kit text, PdfBox-Android, JExcelApi (xls), custom XLSX zip parser (no POI), OpenCSV, Jsoup, Jakarta Mail, Credential Manager + Play auth, Glance, BiometricPrompt, WorkManager | app/ and email/ build.gradle.kts, libs.versions.toml | 05 s98-99, 03 s437, 08, 24, 25 | Full | None | Spec correctly says no POI |
| 41 | Unused or dev-only dependencies: haze, coil, colorpicker, compose-charts, jetbrains-markdown, ktor (Gmail only), profileinstaller / baseline profile | libs.versions.toml, app/build.gradle.kts:103-109 | none | Partial | None (optional note in plan.md) | No source use found for haze, coil, colorpicker; do not port. Baseline profile (startup perf) has no Flutter equivalent or NFR; add a startup target to plan.md if wanted |
| 42 | ML Kit datatransport uploader removed from manifest (no telemetry leaves device) | AndroidManifest.xml:96-106 | 25 | Full | None | |
| 43 | Absent: analytics, ads, crash reporting, remote logging, cloud backup | FEATURES.md, AGENTS.md, data_extraction_rules.xml, allowBackup=false | 25, 24, 01 s143 | Full | None | Stated |
| 44 | Logo assets (140 webp, offline) and LogoPaths (simpleicons-derived vector paths) | app/src/main/assets/logos; A/ui/components/LogoPaths.kt:4 | 09 s340, AC-09-07 | Partial | Expand 09 | Vector `LogoPaths` (card networks e.g. Discover) are a second logo source with simpleicons attribution; spec lists only the webp files |

## Gaps list

1. MISSING, highest risk: in-place upgrade or data carry-over from the Kotlin app (applicationId, signing lineage, Room to Drift import, sealed-secret loss, one-time repair flags). Only an open question in 26. Decide and write it into 26 and 31, plus a plan.md risk row.
2. MISSING: release pipeline contract. Updater consumer is fully specified in 31, but the producer (`release.yml`: asset `DhanKosh-<ver>.apk`, `sha256:` notes line, commit-body "- " bullets as release notes, v3 rotation signing) and CI (`ci.yml`) are not. Add to 31 and the plan.md Roadmap/Risks.
3. PARTIAL: planned insights from SPEC_NOTES (bank-charges leakage, card utilisation over 30%, EPF missing month, commerce enrichment) appear in no spec. Record as out of scope or proposed in 18.
4. PARTIAL: Home "Safe to spend today" block still in code and keys although removed in 2.9.0 (17 has one mention). Confirm dropped or hideable.
5. PARTIAL: chart inventory (18): no single list of chart types and which screens use them; mark `StackedArea` dead.
6. PARTIAL: Copy text on message view (07/08), Transactions calendar captions and colour by kind (08), `LogoPaths` vector logos (09). Low impact.
7. NOTE: dead or unused dependencies (haze, coil, colorpicker, compose-charts, markdown) and the unreachable bench screen should be named as "do not port".
8. NOTE: stale copy in keys ("then checks every hour", wiki "History tab") contradicts daily 02:30 sync; specs already flag the hourly text, so port with corrected copy.
9. NOTE: key count is 1455, not 1456.
