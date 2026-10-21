# Feature Audit: Coverage Matrix

Audit Gate (Prompt 2, Part A), 2026-10-19. Independent re-scan of `hisaab_apk` v2.9.8 (Kotlin, Room v15) against the specs in `memory/`. Row-level detail (every capability with file:line) is in the scan files; this file holds the totals, every gap, and the reverse checks.

| Scan file | Angle | Rows | Full | Partial | Missing |
|---|---|---|---|---|---|
| [scan_1_ui.md](scan_1_ui.md) | Routes, navigation, workers, integrations (earlier, ungraded) | ~60 | n/a | n/a | n/a |
| [scan_2_sources_parsing.md](scan_2_sources_parsing.md) | Data sources, parsers, rules | 67 | 61 | 5 | 1 |
| [scan_3_database.md](scan_3_database.md) | Tables, columns, queries, triggers, migrations, non-Room stores | 49 | 44 | 5 | 0 |
| [scan_4_settings_permissions_background.md](scan_4_settings_permissions_background.md) | Settings, permissions, background work | 95 | 84 | 3 | 8 (7 distinct) |
| [scan_5_outputs_strings_integrations.md](scan_5_outputs_strings_integrations.md) | Outputs, strings, integrations | 44 | 33 | 9 | 2 |
| [scan_6_screens_components.md](scan_6_screens_components.md) | Screens, dialogs, sheets, menus | 53 | 49 | 4 | 0 |
| **Total (graded)** | | **308** | **271** | **26** | **11** |

Counts are as reported by each scan and overlap slightly (the same gap can appear in two angles). Distinct gaps after de-duplication are listed below. No ingestion source, table, permission or screen in the Kotlin app lacks a spec; the gaps are depth gaps inside existing files plus three areas that belong in new files.

## Gap matrix (every Partial / Missing item)

| # | Capability found in existing app | Where found (file / screen) | Memory file | Coverage | Action |
|---|---|---|---|---|---|
| 1 | Holding-identity rules (name-word stop lists, plan/payout markers, AMC words, EPF id normalisation, preferred id, aggregate coverage) | shared/repo/HoldingMatch.kt | 16 | Missing | Expand file 16 (FR-16-09 was wrong) |
| 2 | MF order and NPS contribution side effects on holdings; holdings dedupe on every app start | HoldingRepository.record/dedupe/recordMfOrder; HisaabApplication.kt:65-66 | 16 | Partial | Expand file 16 |
| 3 | NPS contributions: holding update, generated INVESTMENT transaction, `nps-contributions` prefs (applied set, cap 500) | NpsContributions.kt:29,72-81 | 16, 26 | Missing | Expand 16 and 26 |
| 4 | MF order email parser patterns and fallbacks | MfOrderParser | 05 | Partial | Expand file 05 |
| 5 | INDmoney portfolio-summary email detection and figure reading | PortfolioSummary | 05 | Partial | Expand file 05 |
| 6 | Release pipeline: asset naming, sha256 notes line, commit-bullet release notes, apksigner v3 rotation, CI | .github/workflows/release.yml, ci.yml | none | Missing | Create new file 32 (Existing) |
| 7 | Upgrade continuity from the Kotlin app: applicationId, signing lineage, Room-to-Drift carry-over, sealed secrets loss, one-time flags reparse_v1 / app_rows_v1 / cardbill_v1, 14 migrations | HisaabApplication.kt:42-98; shared/schemas | 26 (open question only) | Missing | Create new file 33 (Proposed) |
| 8 | Planned or removed features: bank-charges leakage, card utilisation over 30%, EPF missing month, commerce enrichment, "Safe to spend today", goals/split/credit score/Outlook OAuth; unused dependencies not to port | doc/SPEC_NOTES.md; keys.json; Gradle files | 17 (one mention) | Partial | Create new file 34 (Proposed); note in 17 |
| 9 | `deleted_messages` table has no table block | shared db | 07 / 08 | Partial | Expand 08 (table), link from 07 |
| 10 | Analytics SQL (categoryTotalsFor, monthlyFor, dailyFor, topMerchantsFor, monthlyForAccount) and personal/business rule; chart components (FanChart, HeatGrid, ProgressRing, Sankey; StackedArea is dead) | DAO; ProtoCharts.kt | 18 | Partial | Expand file 18 |
| 11 | `cardFlowSince` filters | DAO | 14 | Partial | Expand file 14 |
| 12 | Tax share cache dir and legacy `tax_overrides` cleanup | Tax code | 19 | Partial | Expand file 19 |
| 13 | MessageView: Copy text, Show all / Show less / Show full email, "original text wasn't kept" state; transactions calendar captions and colour by kind | MessageView.kt:82-140 | 08 | Partial | Expand file 08 |
| 14 | LogoPaths vector logos | LogoPaths | 09 | Partial | Expand file 09 |
| 15 | `gmail_settings` keys (read_pdf, history_id, last_sync, last_result, imap_synced_at); `mf-orders` prefs | Gmail settings | 26 (03 partly) | Partial | Expand file 26 |
| 16 | Negative platform facts (no boot receiver, no AlarmManager, no foreground service), supportsRtl, target SDK 36, WorkManager custom initialiser, adjustResize, splash theme | AndroidManifest.xml, MainActivity | 26 / 01 | Missing | Expand 26 section 11 (and 01) |
| 17 | More hub live subtitles and footer; InfoButton (i) dialogs | MoreScreen.kt:197-337 | 26 / 17 | Partial | Expand file 26 |
| 18 | SPEC_NOTES design tokens versus code palette | doc/SPEC_NOTES.md | 28 | Partial | Expand file 28 |

## Spec errors found (fixed in the same pass)

| Where | Error | Fix |
|---|---|---|
| 10 | Says `budgets` was added in migration 7-8 (none creates it); puts `needsReview = 0` in a query that has no such filter | Correct from the Kotlin source |
| 01 / 17 / 26 | Settings key-value table has three different names | Use the name 26 owns |
| 02 | "16 lender parsers", "~55 listed banks" | 17 lenders, 51 banks |
| 06 | Prose says 50 banks (own table has 51); says subcategory regexes are not enumerated (they are in 09) | Fix prose, link to 09 |
| 29 | 1456 keys | 1455 |
| 16 | FR-16-09 "upsert by identifier" and "MF orders create transactions not holdings" contradict the source | Correct |
| plan.md section 6 | Owner of `transaction_sources` and `deleted_messages` mislabelled; Flutter-only tables not listed | Fix owner column; list the extra tables |

## Reverse checks

1. **Screens to features:** all 64 rows of `assets_reference/_screens_index.md` map to a feature file (0 unmapped). Files 02, 04, 06, 11 have no dedicated screen, as expected. (scan_6)
2. **DB tables to features:** all 13 Room tables are owned by a feature: transactions 08, transaction_sources 08 (definition) / 07, processed_emails 03, accounts 13, budgets 10, deleted_messages 08 / 07, statements 05, holdings 16, merchant_rules 09, recurring 12, custom_categories 09, custom_subcategories 09, forex_rates 23. Both triggers are in 23. 12 of 13 fully documented; `deleted_messages` was the only partial (gap 9). (scan_3)
3. **Permissions to features:** 27 manifest items checked; every permission, intent filter, deep link, FileProvider, receiver and widget provider maps to a feature (READ/RECEIVE_SMS 02, notification listener 04, POST_NOTIFICATIONS 21, USE_BIOMETRIC 25, INTERNET 03/31, REQUEST_INSTALL_PACKAGES 31, widget 30). The only gaps are the negative platform facts (gap 16). (scan_4)

## Decisions flagged for the owner

- The Android database is plain, unencrypted Room. SQLCipher in `plan.md` is a new decision, not parity.
- Upgrade continuity (gap 7) is unresolved; see Open Questions in file 33.
