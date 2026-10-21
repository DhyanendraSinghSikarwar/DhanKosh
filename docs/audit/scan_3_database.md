# Scan 3: Database angle (Room v15, DataStore, prefs, files)

Sources read (read-only): `hisaab_apk/shared/src/main/kotlin/com/hisaab/shared/db/{HisaabDatabase,Entities,Categories,Forex,Investments,Recurring,TransferLegs,Daos}.kt`, `shared/di/SharedModule.kt`, `shared/schemas/com.hisaab.shared.db.HisaabDatabase/1..15.json` (exist; 15 files), `grep` over all modules for DataStore, SharedPreferences, `filesDir`, `cacheDir`. Specs checked: `memory/*.md` section 9 of owners plus grep across memory.

Key facts
- Latest schema version: **15** (`HisaabDatabase.VERSION = 15`, `exportSchema = true`, migrations 1-2 ... 14-15, all hand-written `Migration`s, no auto-migrations, no destructive fallback).
- 13 entities, 13 DAO interfaces (12 table DAOs + `ReconcileDao`), 0 `@TypeConverter` (enums stored by Room's default enum-name text), 0 Room `@View`, 0 `@DatabaseView`.
- Driver: Room with `BundledSQLiteDriver`, plain file `hisaab.db`. **No SQLCipher / no encryption** in the existing app. CLAUDE.md and plan.md say Drift + SQLCipher (new behaviour, not parity); only 25_security_privacy Open Question 1 mentions it.
- plan.md section 6 lists all 13 tables correctly (grouping custom_categories + custom_subcategories in one row). It omits every Flutter-only table the feature files introduce: `NetWorthPoints` (16), `PayeeAccounts` (04), `ActivityEntries` (22), settings key-value table (01 `AppSettingsEntries`, 17 `AppSettingsTable`, 26 `app_settings`), `LoanLinkRows`, `LoanDismissalRows` (15), `CardDueNotices`, `CardOverrides` (14), `AlertedKeys`, `CardDueReminderState`, `BalanceNoticeDays` (21). plan.md also says transaction_sources is owned by 07 and deleted_messages by 08, but the column definitions live in 08 and 07 respectively (reversed).

## 1. Room tables

Column lists verified against `Entities.kt` etc. "Columns missing" is empty when every column is named in the owner file's Drift block or prose.

| # | Table / store | Columns missing from specs | Owner memory file | Coverage | Action | Notes |
|---|---|---|---|---|---|---|
| 1 | `transactions` (id, amountMinor, currency, type, bankName, accountLast4, accountKind, accountId FK SET NULL, merchant, upiId, referenceNumber, channel, balanceMinor, availableLimitMinor, timestamp, hasExplicitTime, category, transactionHash UNIQUE, confidence, needsReview, duplicateOfId, reviewReason, note, createdAt, subcategory, customCategoryId, inrMinor) | none (27 of 27 in 08 section 9) | 08_transactions_ledger | Full | None | 6 non-unique indexes + unique hash documented in 08. `duplicateOfId` documented as "no FK", correct. |
| 2 | `transaction_sources` (id, transactionId FK CASCADE, source, sourceMessageId, sender, parsedHash, rawText, receivedAt, subject) | none | 08 (definition), 07 (usage) | Full | None (fix plan.md owner label) | UNIQUE(source, sourceMessageId), idx transactionId, idx parsedHash all in 08. Special source-id prefixes (`xfer-out:`, `xfer-in:`, `stmt:`) in 07/08. |
| 3 | `processed_emails` (messageId PK, processedAt, outcome, transactionId) | none | 03_email_ingestion | Full | None | Outcome set mismatch noted in 03 (Room doc says PARSED/REJECTED/DUPLICATE/ERROR; sync engine writes SKIPPED). Query `existing(ids)`, `observeCount`, `clear` are covered in 03. |
| 4 | `accounts` (id, bankName, last4, kind, nickname, colorArgb, latestBalanceMinor, availableLimitMinor, balanceUpdatedAt, createdAt, manualBalanceMinor, manualBalanceAt, accountType, cardNetwork, linkedAccountId, hidden, usage, maturityDay, maturityAction, forexMarkupBps, loanPrincipalMinor, loanRateBps, loanTenureMonths, loanStartDay, mergedIntoId) | none (25 of 25 in 13 section 9) | 13_accounts_management | Full | None | UNIQUE(bankName, last4). `linkedAccountId` and `mergedIntoId` have no FK in Room; spec says soft ref, correct. Minor: 13 says migration "9-10 colorArgb context"; `colorArgb` is not added by any migration (it is in v1). Cosmetic. |
| 5 | `budgets` (category PK, monthlyLimitMinor) | none | 10_expense_tracking | Full | None | 10 says "table added in migration 7-8 era"; false, no migration creates it (present in v1). Cosmetic fix in 10. |
| 6 | `deleted_messages` (source, messageId, deletedAt; composite PK) | none (columns named in 07 prose) | 07_dedup_review (prose), plan.md names 08 | Partial (structure only) | Expand file | No Drift `class DeletedMessages extends Table` anywhere in memory, unlike every other table. Add the table block to 08 (owner per plan.md) or fix plan.md to 07. Tombstone chunk size 900 and `exists` lookup covered. |
| 7 | `statements` (id, key UNIQUE, source, sender, subject, fileName, receivedAt, status, transactionCount, holdingCount, filePath, bankName, last4, processedAt, kind, totalDueMinor, minDueMinor, dueEpochDay, creditLimitMinor, statementEpochDay, openingMinor, closingMinor, debitsMinor, creditsMinor, availableMinor, emailText) | none (26 of 26 in 05 section 9) | 05_statement_import | Full | None | Overloaded `kind` rows (CARD_OVERRIDE, CARD_PAYMENT, PROTECTED) are documented in 05 and split into `CardDueNotices`/`CardOverrides` in 14. 05 lists `source` as EMAIL/FILE/SMS/MANUAL; Room code comment says EMAIL or FILE only (harmless widening). |
| 8 | `holdings` (id, kind, name, identifier UNIQUE, units REAL, valueMinor, investedMinor, asOf, source, note, updatedAt, previousValueMinor, previousAsOf) | none | 16_portfolio | Full | None | Also mirrored in 05. |
| 9 | `merchant_rules` (merchantKey PK, category, updatedAt, matchType, subcategory, customCategoryId, manual) | none | 09_categorization | Full | None | Pick order (manual exact > manual contains longest > learned) and LIKE escaping covered. |
| 10 | `recurring` (id, name, amountMinor, income, frequency, dayOfMonth, month, category, accountId, createdAt) | none | 12_recurring_transactions | Full | None | Renamed `RecurringItems` in Drift, noted. `referenceCount` covered in 12/13. |
| 11 | `custom_categories` (id, name, icon, colorArgb, createdAt) | none | 09_categorization | Full | None | |
| 12 | `custom_subcategories` (id, parent, name, icon, createdAt; UNIQUE(parent, name)) | none | 09_categorization | Full | None | `parent` = enum name or `custom:<id>`, documented. |
| 13 | `forex_rates` (currency, day, inrPerUnit REAL; PK(currency, day)) | none | 23_forex_rates | Full | None | Triggers and `recompute` covered (see section 3). |

Tables: 13 total, Full 12, Partial 1 (`deleted_messages`), Missing 0.

## 2. DAO query families

| # | DAO / family | Queries | Spec location | Coverage | Action | Notes |
|---|---|---|---|---|---|---|
| D1 | `TransactionDao` write/lookup (insert IGNORE returning -1, update, delete, deleteAll, getById, findByReference, findByHash UNION on parsedHash, findPotentialDuplicates, findInRange, setCategory(For), setNote, setAccount, pageAfter, orphansAfter, idsForAccount, getAll, count) | 07, 08, 09, 13 | Full | None | `findInRange` (rounded-amount window) covered by 07 `byAmountRangeWindow`. |
| D2 | `TransactionDao.observe(search, accountId incl. merged children, category, type, source, from, to, limit)` | 08, 20 | Full | None | Amount-prefix search on whole rupees documented. |
| D3 | `TransactionDao` simple aggregates (observeTotal/total by types, observeCategoryTotals, observeTopMerchants, observeBetween/Since/Recent, observeReviewCount, observeNeedsReview, firstTimestamp) | 10, 17, 18, 08 | Full | None | Discrepancy: 10 section 9 prescribes `needsReview = 0` in `observeCategoryTotals`; the Kotlin query does NOT filter `needsReview`, and `observeTotal`/`observeBetween` do not either (10 flags this as open). Decide parity vs intent. |
| D4 | `TransactionDao` analytics with filters: `categoryTotalsFor`, `monthlyFor`, `dailyFor`, `topMerchantsFor` (scope ALL/PERSONAL/BUSINESS where no-account counts as personal, kind ALL/ACCOUNT/CARD), `observeMonthly`, `observeDailySpend` (UTC offset day buckets, `strftime('%Y-%m')`), `monthlyForAccount` (account + linked debit cards + merged children), `firstTimestampFor` | 18 (logic only) | Partial | Expand file | No file names these SQL shapes, the "no account counts as personal" rule, or the per-account monthly rollup that includes linked debit cards and merged accounts. 18 section 9 says "no schema change" and computes in Dart from `observeBetween`. Add a short "scope/kind filter semantics" bullet list to 18 (or 20) so the Dart aggregation matches. |
| D5 | `TransactionDao.cardFlowSince` (card timeline: DEBIT/CREDIT/TRANSFER, `duplicateOfId IS NULL`) | 14 (card dues logic) | Partial | Expand file | The `duplicateOfId IS NULL` filter and `inrMinor IS NOT NULL` filter are not named. Add to 14. |
| D6 | `TransactionDao.observeLoanPayments` (type != CREDIT, needsReview = 0, category EMI_LOAN or account type LOAN) | 15 | Full | None | |
| D7 | `TransactionDao.observeForStatement`, `observeMatchedForStatement` (LIKE `stmt:<key>:%` joins) | 05 | Full | None | Verified `stmt:<key>:<row>` naming in 05/07. |
| D8 | `TransactionDao.categoryUsage(type, from)` | 21 | Full | None | |
| D9 | `TransactionSourceDao` (insert IGNORE, exists, forTransaction(s), sourcesOf, idsWithPrefix, transactionIdFor, reassign, move, getById) | 07, 08 | Full | None | |
| D10 | `ProcessedEmailDao` + `statementStatusSince` | 03, 22 | Full | None | `statementStatusSince` lives in the processed-email DAO in Room; spec places it in 22. OK. |
| D11 | `AccountDao` balance/meta writers (updateBalance only-newer rule, setLimitFromStatement, rename, setType, setUsage, setHidden, setMaturity, closeMatured, setForexMarkup, setLoanTerms, link, setManualBalance, setMergedInto, repointMerged, unmergeChildren, referenceCount, cardLast4s, delete) | 13, 05, 16 | Full | None | |
| D12 | `AccountDao.observeWithActivity` (derived `monthSpent`, `transactionCount`, `changeSinceManual`, `changeSinceReported`, `TransferLegs.SIGNED_SQL`, merged/linked rollup, hides merged children) | 13 | Full | None | `SIGNED_SQL` (xfer-out/xfer-in prefix and "Credit card bill" note => signed value) is named in 08/13. |
| D13 | `ReconcileDao.netChange` (net + unclear count) | 13 | Full | None | |
| D14 | `BudgetDao`, `MerchantRuleDao` (applyToPast, observeMatchCount, applyToUncategorised, manualRules), `CategoryDao` (custom CRUD, releaseCustom, deleteSubsOf, setSubcategory, setCustomCategory, observeCustomTotals, observeSpendIn), `ForexDao`, `RecurringDao`, `StatementDao` (billsFor, locked), `HoldingDao`, `DeletedMessageDao` | 10, 09, 23, 12, 05, 16, 07 | Full | None | `CategoryDao.observeCustomTotals` and `observeSpendIn` (Home custom-category totals and sub-category drill-down) only implied in 09/17; low risk. |

## 3. Triggers, migrations, indexes

| # | Item | Documented in | Coverage | Action | Notes |
|---|---|---|---|---|---|
| T1 | Trigger `transactions_inr_insert` AFTER INSERT ON transactions | 23, 08, 13 | Full | None | Created by `ForexSql.install` in migration 11-12 AND in `RoomDatabase.Callback.onOpen` every open (`IF NOT EXISTS`). Not in schema JSON. |
| T2 | Trigger `transactions_inr_update` AFTER UPDATE OF amountMinor, currency, accountId, timestamp | 23, 08 | Full | None | Does not fire on `forex_rates` or `forexMarkupBps` changes; `ForexDao.recompute()` covers that, documented in 23. |
| T3 | Migrations 1-2 ... 14-15 (15 schema JSONs) | 13 (accounts subset), 05 (statements), 09 (rules/custom), 08 (stated "history applies to import path") | Partial | Expand file | No single table of all 14 migrations and what each does (e.g. 9-10 created custom tables and added statements totals; 11-12 backfilled `inrMinor = amountMinor` for INR and created `forex_rates` and triggers; 12-13 rule columns). 08 and 26 treat import from Room v15 as Open Question 6. If import path stays open, add a migration table (can live in 08 section 9 or 24 backup). |
| T4 | Migration backfill `UPDATE transactions SET inrMinor = amountMinor WHERE currency = 'INR'` | 23 (implicit via trigger) | Partial | Expand file | Needed only for an import path. |
| T5 | Indexes: transactions(transactionHash UNIQUE; amountMinor+accountLast4+timestamp; referenceNumber; timestamp; accountId; needsReview), transaction_sources(source+sourceMessageId UNIQUE; transactionId; parsedHash), accounts(bankName+last4 UNIQUE), statements(key UNIQUE), holdings(identifier UNIQUE), custom_subcategories(parent+name UNIQUE) | 08, 07, 13, 05, 16, 09 | Full | None | |
| T6 | Foreign keys: only `transactions.accountId -> accounts.id SET NULL` and `transaction_sources.transactionId -> transactions.id CASCADE` | 08 | Full | None | Everything else is a soft reference; documented. |
| T7 | Room views / TypeConverters | n/a | n/a | None | None exist. |

## 4. Non-Room stores

All DataStore names and key names below were extracted from source; "Spec" is where the memory files document them.

| # | Store (file) | Keys / content | Spec | Coverage | Action | Notes |
|---|---|---|---|---|---|---|
| N1 | DataStore `app_settings` | app_lock, theme, theme_palette, pure_black, text_scale, sms_enabled, sms_cursor, last_sms_scan, last_sms_result, sms_prompt_dismissed, app_notifications, notifications_asked, budget_alert_percent, alerted_keys, transaction_notifications, card_due_reminders, hide_amounts, check_updates, display_name, profile_email/phone/occupation/photo, profile_prompt_dismissed, last_update_check | 26, 01, 02, 27, 28, 21, 31, 17 | Full | None | Naming of the Flutter KV table is inconsistent: 01 `AppSettingsEntries`, 17 `AppSettingsTable`, 26 `app_settings`. Pick one name (owner 26) and have 01/17 link to it. |
| N2 | DataStore `gmail_settings` | enabled, account, lookback_days, senders, read_pdf, history_id, last_sync, needs_reauth, last_result, connection, imap_synced_at (+ per-email `imap_synced_at:<email>`) | 03, 26 | Full | None | `read_pdf` and per-email IMAP sync position verified by grep. |
| N3 | DataStore `gmail_tokens` (token sealed, expires_at) | | 03, 25 | Full | None | |
| N4 | DataStore `mail_account` (accounts string set, legacy email/password) | | 03 | Full | None | |
| N5 | DataStore `statement_passwords` (entries, account_details, identity; sealed) | | 05, 13, 25, 01 | Full | None | |
| N6 | DataStore `activity_log` (`entries` JSON: src, at, read, rel, add, mrg, rev ...) | | 22 | Full | None | Drift `ActivityEntries` replaces it. |
| N7 | DataStore `language` (`language`), files `filesDir/lang/<code>.json(.tmp)` | | 29 | Full | None | |
| N8 | DataStore `tab_layout` (order_<tab>, hidden, home_v2_seeded, home_spent_added, home_networth_left, analytics_when_last) | | 17, 18, 28, 16 | Full | None | |
| N9 | DataStore `net_worth_prefs` (excluded_classes, excluded_liabilities, excluded_accounts) | | 16 | Full | None | |
| N10 | DataStore `local_lists` (`worth` JSON array {day,a,l}) | | 16 | Full | None | Becomes `NetWorthPoints`. |
| N11 | DataStore `card_due_reminders` (sent, paid, snoozed) | | 21, 14 | Full | None | |
| N12 | DataStore `untracked_gaps` (dismissed, notified, choices) | | 08, 13 | Full | None | |
| N13 | DataStore `loan_links` (tx, payee, manual), `loan_dismissals` (payees) | | 15 | Full | None | |
| N14 | DataStore `view_filter` (`book`) | | 08, 10, 20 | Full | None | |
| N15 | SharedPreferences `payee_accounts` (payee key -> accountId long) | | 04, 08, 13, 26 | Full | None | |
| N16 | SharedPreferences `maintenance` (reparse_v1, app_rows_v1, cardbill_v1 one-time flags) | | 26 | Full | None | Not needed for a fresh DB. |
| N17 | SharedPreferences `balance-updates` (account key -> last notified epoch day) | | 13, 21, 26 | Full | None | |
| N18 | SharedPreferences `mf-orders` (max 500 keys), `nps-contributions` (max 500 keys) | | 05, 16 | Full | None | |
| N19 | Files: `noBackupFilesDir/statements/`, `.../locked-statements/`, `<sha>.holdings` sidecar; `filesDir/profile-<ms>.jpg`; `cacheDir/updates/` (APK download), `cacheDir/shared/` (tax report share); legacy `filesDir/datastore/tax_overrides.preferences_pb` deleted by TaxScreen reset | | 05, 27, 31, 19 | Partial | Expand file | `cacheDir/shared/` (tax report export temp) and the legacy `tax_overrides` store deletion were not found by name in 19_tax_centre; add one line each. Others covered. |
| N20 | Secrets: Keystore aliases `hisaab.mail.password`, `hisaab.gmail.token`, `hisaab.statement.passwords` | | 25, 03 | Full | None | |

## 5. Counts and summary

- Room tables: 13. Full 12, Partial 1, Missing 0.
- DAO query families listed: 14. Full 12, Partial 2 (D4 analytics scope/kind SQL family, D5 `cardFlowSince` filters).
- Triggers: 2, both Full. Migrations: 14 hops, documented per table but no consolidated list (Partial; only matters if a Room v15 import path is kept).
- Non-Room stores: 14 DataStore files, 5 SharedPreferences files, 6 file/dir locations; all documented except two small file-system items under N19.
- No table is Missing from the specs. No new feature file is needed. All actions are "Expand file" or doc hygiene.

## 6. Recommended actions (ordered)

1. 08 (or 07): add `DeletedMessages` Drift table block; make plan.md section 6 owner labels for `transaction_sources` (08) and `deleted_messages` consistent (plan.md is an app-wide structure doc, so this is allowed).
2. plan.md section 6: add rows for Flutter-only tables (settings KV, NetWorthPoints, PayeeAccounts, ActivityEntries, loan link/dismissal rows, card due notices/overrides, alert state tables) or state "Flutter-only tables: see feature files".
3. 18: add scope/kind filter semantics (personal = no account or PERSONAL account; per-account rollup includes linked debit cards and merged accounts).
4. 14: note `cardFlowSince` filters (`duplicateOfId IS NULL`, `inrMinor IS NOT NULL`).
5. 10: correct "budgets table added migration 7-8"; resolve `needsReview` filter parity in `observeCategoryTotals`.
6. 19: add `cacheDir/shared` temp export and legacy `tax_overrides` store cleanup.
7. Unify the settings KV table name across 01, 17, 26.
8. Decide Room v15 import path (08/26 Open Question); if kept, add a migration table and the INR backfill.
9. Record that the original DB is not encrypted; SQLCipher in Flutter is a new decision (25 Open Question 1) and the file import path would need decrypt/encrypt handling.
