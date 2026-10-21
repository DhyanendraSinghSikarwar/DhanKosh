# Scan 4: Settings, permissions, background work

Angle: every preference key, manifest entry and background job in `hisaab_apk` (v2.9.8), mapped to `memory/NN_*.md`. Kotlin refs relative to `hisaab_apk/`. Coverage is Full only where the spec states the behaviour and the default.

Overall: the specs are strong here. `26_settings_data_sources.md` section 2.5 holds a near-complete key inventory, `25_security_privacy.md` holds the manifest inventory, and the workers are in 02, 03, 21. Real gaps are small (see Gaps list).

## Table 1: Settings and preference keys

| # | Item | Where found (file:line) | Memory file | Coverage | Action | Notes |
|---|---|---|---|---|---|---|
| S1 | `app_lock` (false) | app/.../settings/AppSettings.kt:167 | 25, 26 | Full | None | Toggle in SecurityScreen.kt:75. |
| S2 | `theme` ThemeMode (SYSTEM) | AppSettings.kt:168 | 26, 28 | Full | None | |
| S3 | `theme_palette` (DHANKOSH, 22 palettes in 3 groups) | AppSettings.kt:21,169 | 26, 28 | Full | None | |
| S4 | `pure_black` (false) | AppSettings.kt:170; CustomizeTabsScreen.kt:137 | 26, 28 | Full | None | |
| S5 | `text_scale` (1.0; 0.9/1.0/1.1/1.2) | AppSettings.kt:37,171 | 26, 28 | Full | None | Snap rule within 0.05 stated. |
| S6 | `sms_enabled` (true) | AppSettings.kt:172 | 02, 26 | Full | None | Checked by live receiver. |
| S7 | `sms_cursor`, `last_sms_scan`, `last_sms_result` | AppSettings.kt:173-175 | 02, 26 | Full | None | Max-on-write, reset, result format stated. |
| S8 | `sms_prompt_dismissed` (false) | AppSettings.kt:176 | 01, 17, 26 | Full | None | |
| S9 | `app_notifications` (false, opt-in) | AppSettings.kt:177 | 04, 26 | Full | None | |
| S10 | `notifications_asked` (false) | AppSettings.kt:178; HomeScreen.kt:124-127 | 01, 17, 21, 26 | Full | None | Ask once, API 33+. |
| S11 | `budget_alert_percent` (90; UI 80/90/95) | AppSettings.kt:179; AlertsScreen.kt | 10, 21, 26 | Full | None | Default conflict (90 vs 80 fallback) already an open question in 26. |
| S12 | `alerted_keys` (empty, cap 300) | AppSettings.kt:161-164,180 | 21, 26 | Full | None | |
| S13 | `transaction_notifications` (true) | AppSettings.kt:181; AlertsScreen.kt:60 | 21, 26 | Full | None | Also gates untracked-gap and balance notifications. |
| S14 | `card_due_reminders` (true) | AppSettings.kt:182; AlertsScreen.kt:75 | 14, 21, 26 | Full | None | Stages 5d / 2d / due date. |
| S15 | `hide_amounts` (true) | AppSettings.kt:183; SecurityScreen.kt:79 | 25, 26 | Full | None | |
| S16 | `check_updates` (true), `last_update_check` | AppSettings.kt:184,191; update/Updater.kt:50 | 26, 31 | Full | None | No UI switch in old app; flagged in 26 open question 2. |
| S17 | `display_name`, `profile_email/phone/occupation/photo`, `profile_prompt_dismissed` | AppSettings.kt:185-190 | 26, 27 | Full | None | |
| S18 | DataStore `tab_layout`: `order_<tab>`, `hidden`, flags `home_v2_seeded`, `home_spent_added`, `home_networth_left`, `analytics_when_last` | settings/TabLayout.kt:142-149 | 26, 28, 17 | Full | None | Presets and defaults in 28. |
| S19 | DataStore `net_worth_prefs`: `excluded_classes/liabilities/accounts` | settings/NetWorthPrefs.kt:64-66 | 16, 26, 28 | Full | None | |
| S20 | DataStore `local_lists`: `worth` (1100 daily points) | settings/LocalLists.kt:64 | 16, 26 | Full | None | |
| S21 | DataStore `view_filter`: `book` (ALL); period not persisted | ui/ledger/Ledger.kt:103,135 | 20, 26 | Full | None | |
| S22 | DataStore `language` | i18n/I18n.kt:62,138 | 26, 29 | Full | None | |
| S23 | DataStore `activity_log`: `entries` (max 200) | log/ActivityLog.kt:85,146 | 22, 26 | Full | None | |
| S24 | DataStore `card_due_reminders`: `sent`, `paid`, `snoozed` | notify/CardDueReminders.kt:68-80 | 14, 21, 26 | Full | None | 120-day prune stated. |
| S25 | DataStore `untracked_gaps`: `dismissed`, `notified`, `choices` | ui/accounts/GapTracker.kt:23,36-38 | 13, 21, 26 | Full | None | |
| S26 | DataStore `loan_links` (`tx`, `payee`, `manual`), `loan_dismissals` (`payees`) | ui/loans/LoanLinkStore.kt:17-25; LoanDismissals.kt:15-21 | 15, 26 | Full | None | 26 only names the stores; 15 has the keys. |
| S27 | DataStore `gmail_settings`: `enabled`, `account`, `lookback_days` (90), `senders`, `read_pdf` (true), `history_id`, `last_sync`, `needs_reauth`, `last_result`, `connection`, `imap_synced_at[:email]` | email/.../sync/GmailSettings.kt:152-162 | 03, 26 | Partial | Expand file | 03 covers lookback, senders, readPdf, connection. 26 inventory lists only lookback, senders, enabled, needsReauth, connection. The `read_pdf` toggle default and where the UI exposes it, and per-address `imap_synced_at:<email>`, should be in the 26 inventory. |
| S28 | DataStore `gmail_tokens`: `token` (sealed), `expires_at` | email/.../auth/TokenStore.kt:50 | 25, 26, 03 | Full | None | |
| S29 | DataStore `mail_account`: `accounts`, `email`, `password` (sealed) | email/.../imap/MailAccountStore.kt:72-74 | 25, 26, 03 | Full | None | |
| S30 | DataStore `statement_passwords`: `entries`, `account_details`, `identity` (sealed) | email/.../statement/StatementPasswordStore.kt:152-154 | 05, 25, 26 | Full | None | |
| S31 | SharedPreferences `payee_accounts` (payee key to accountId) | HisaabApplication.kt:51-53 | 04, 08, 13, 26 | Full | None | |
| S32 | SharedPreferences `maintenance` flags `reparse_v1`, `app_rows_v1`, `cardbill_v1` | HisaabApplication.kt:55-97 | 07, 08, 26 | Full | None | 26 says not needed for a fresh DB. |
| S33 | SharedPreferences `balance-updates` (per-account last-notified day) | notify/BalanceNotifications.kt:36 | 21, 26 | Full | None | |
| S34 | SharedPreferences `mf-orders` (`ORDERS_KEY` set, trimmed) | email/.../statement/StatementProcessor.kt:89,150,176-180 | 05 | Partial | Expand file | Spec in 05:178,470 covers the dedupe key. Missing from the 26 inventory, and the cap size is not stated. |
| S35 | SharedPreferences `nps-contributions` (`applied` set, cap 500) | shared/.../repo/NpsContributions.kt:29,72-81 | none by store name | Missing | Expand file | 02 and 03 describe NPS contribution handling, but no file records the persisted applied-key set, its 500 cap or its role in dedupe. Add to 26 inventory and the owning ingest file. |
| S36 | Home SMS permission card state (blocked / rationale) | ui/components/SmsPermission.kt:50-83 | 01 | Full | None | |
| S37 | Photo crop slider (profile) | ui/profile/PhotoCrop.kt:242 | 27 | Full | None | UI control, not a stored key. |
| S38 | Export/import CSV pickers (settings > Security) | ui/more/SecurityScreen.kt:64-65 | 24, 25 | Full | None | |
| S39 | Dev route `bench` (ParserBench screen) | ui/nav/HisaabNavHost.kt:242; ui/bench/ParserBenchScreen.kt:87 | 06 | Full | None | Parser bench documented at 06:425. |
| S40 | Forex currency picker | ui/settings/ForexRatesScreen.kt:164 | 23 | Full | None | |
| S41 | Legacy `datastore/tax_overrides` deleted on start | TaxSource init | 26 | Full | None | |

## Table 2: Permissions, manifest entries and system integration

| # | Item | Where found (file:line) | Memory file | Coverage | Action | Notes |
|---|---|---|---|---|---|---|
| P1 | `READ_SMS` | app/src/main/AndroidManifest.xml:7; ui/components/SmsPermission.kt:77 | 01, 02, 26 | Full | None | Requested with RECEIVE_SMS via RequestMultiplePermissions; blocked path opens app details. |
| P2 | `RECEIVE_SMS` | AndroidManifest.xml:8 | 01, 02, 26 | Full | None | |
| P3 | `INTERNET` (app and email modules) | AndroidManifest.xml:10; email/AndroidManifest.xml:1 | 01, 25, 31 | Full | None | Gmail API, GitHub update check, news, packs. |
| P4 | `ACCESS_NETWORK_STATE` | AndroidManifest.xml:11 | 01, 03, 26 | Full | None | |
| P5 | `USE_BIOMETRIC` | AndroidManifest.xml:12 | 25 | Full | None | `local_auth`, FlutterFragmentActivity needed. |
| P6 | `POST_NOTIFICATIONS` (runtime, API 33+, ask once) | AndroidManifest.xml:14; HomeScreen.kt:124-127 | 01, 21, 26 | Full | None | |
| P7 | `REQUEST_INSTALL_PACKAGES` | AndroidManifest.xml:16 | 31 | Full | None | Installer hand-off after user taps Install. |
| P8 | `uses-feature telephony required=false` | AndroidManifest.xml:5 | 01, 26 | Full | None | |
| P9 | `MainActivity` exported; LAUNCHER filter; `adjustResize` | AndroidManifest.xml:31-55 | 01, 25 | Partial | Expand file | Exported status is in 25. `windowSoftInputMode=adjustResize` and the `Theme.Hisaab.Starting` splash theme (28 mentions splash hold) are not specified in the Android-native section. |
| P10 | Deep link `hisaab://statements` (unlock) | AndroidManifest.xml:41-45 | 05, 21 | Full | None | `hisaab://statements?unlock=<id>`. |
| P11 | Deep links `hisaab://budgets`, `bills`, `transaction`, `account` | AndroidManifest.xml:47-54 | 10, 12, 13, 14, 15, 17, 21 | Full | None | Table in 21. |
| P12 | `SmsReceiver` exported, `BROADCAST_SMS` guard, priority 999, `goAsync` | AndroidManifest.xml:57-64; sms/SmsReceiver.kt:27 | 02, 25 | Full | None | |
| P13 | `PaymentNotificationListener` (BIND_NOTIFICATION_LISTENER_SERVICE), 20 package ids, chat-app guard, ongoing and group-summary filter | AndroidManifest.xml:67-75; notify/PaymentNotificationListener.kt:31-120 | 04, 26 | Full | None | Restricted-settings hint present. |
| P14 | FileProvider `${applicationId}.updates`, `cache/updates/`, `cache/shared/` | AndroidManifest.xml:77-83; res/xml/update_paths.xml | 19, 31, 25 | Full | None | Share files for tax estimate documented in 19. |
| P15 | `CategoryActionReceiver`, `CardDueActionReceiver` (non-exported) | AndroidManifest.xml:86-87 | 09, 14, 21, 25 | Full | None | Actions `CARD_DUE_PAID`, `CARD_DUE_SNOOZE`, request-id offsets stated. |
| P16 | `SpendWidgetReceiver` (APPWIDGET_UPDATE), `spend_widget_info.xml` (180x110dp, 3x2, 30 min) | AndroidManifest.xml:89-99 | 30, 25 | Full | None | |
| P17 | Datatransport backend removal (ML Kit telemetry) | AndroidManifest.xml:105-111 | 25 | Full | None | Flutter equivalent (ML Kit plugin manifest merge) to be applied. |
| P18 | `WorkManagerInitializer` removed; custom init with Hilt worker factory | AndroidManifest.xml:113-123; HisaabApplication.kt:26-27 | none | Missing | Expand file | Not a user behaviour. Flutter needs the equivalent (workmanager plugin init, callback dispatcher). Add one line to 26 section 11 or plan.md risks. Low priority. |
| P19 | `allowBackup=false`, `fullBackupContent=false`, `data_extraction_rules` (exclude all) | AndroidManifest.xml:20-22; res/xml/data_extraction_rules.xml | 25, 26, 24 | Full | None | FR-26-20. |
| P20 | `network_security_config` (no cleartext, system CAs only) | AndroidManifest.xml:27; res/xml/network_security_config.xml | 25, 03 | Full | None | |
| P21 | `android:supportsRtl=true` | AndroidManifest.xml:26 | none | Missing | Expand file | Not stated in 29_localization or 28. Eight languages are LTR scripts, so low impact. Note in 29 section 11 if RTL is intended. |
| P22 | `tools:targetApi=36` (targetSdk behaviour) | AndroidManifest.xml:29 | none | Missing | Expand file | Target SDK level not recorded in plan.md or 01. Matters for POST_NOTIFICATIONS and notification-listener behaviour. Add to plan.md stack or 01 section 11. |
| P23 | Runtime pickers: PickVisualMedia (add-transaction screenshot, profile photo), OpenDocument (statements, CSV import), CreateDocument CSV, StartIntentSenderForResult (Google consent) | AddTransactionScreen.kt:266; ProfileScreen.kt:225,335; StatementsScreen.kt:182; SecurityScreen.kt:64-65; DataSourcesScreen.kt:168 | 08, 27, 05, 24, 26 | Full | None | |
| P24 | System intents `ACTION_NOTIFICATION_LISTENER_SETTINGS`, `ACTION_APP_NOTIFICATION_SETTINGS`, `ACTION_APPLICATION_DETAILS_SETTINGS` | DataSourcesScreen.kt:163; AlertsScreen.kt:50; SmsPermission.kt:50 | 26, 21, 01 | Full | None | App-lock skip flag before each launch stated (FR-26-09). |
| P25 | App lock re-arm on `onStop` unless `skipNextLock` or config change | MainActivity.kt:51-77; security/AppLockGate.kt | 25 | Full | None | |
| P26 | Notification channels `new_transactions` (LOW), `budgets_bills` (DEFAULT), `statements` (DEFAULT) | notify/NewTransactionNotifier.kt:101; Alerts.kt:177; StatementNotifications.kt:59; BalanceNotifications.kt:83 | 21 | Full | None | Card-due reminders reuse `budgets_bills`; stated. |
| P27 | No `BOOT_COMPLETED`, no `AlarmManager`, no foreground service, no wake-lock, no `SCHEDULE_EXACT_ALARM` | whole repo grep | none | Missing | Expand file | Negative facts, but a Flutter port needs them stated: all schedules rely on WorkManager persistence, and the widget relies on `updatePeriodMillis` plus `updateAll`. Add one line to 26 section 11. |

## Table 3: Background work, receivers, services, startup tasks

| # | Item | Where found (file:line) | Memory file | Coverage | Action | Notes |
|---|---|---|---|---|---|---|
| B1 | `SmsReceiver` live parse on SMS_RECEIVED (multipart join, sender filter, `sms_enabled` check, NPS branch) | sms/SmsReceiver.kt:27-80 | 02, 25 | Full | None | |
| B2 | `OptimizedSmsReaderWorker` unique `sms-scan` (KEEP default / REPLACE full and recent), input `full` or `recent_days`, progress `KEY_SCANNED`, 14-day recent scan | sms/SmsScanScheduler.kt:16-30; OptimizedSmsReaderWorker.kt:40 | 02, 26 | Full | None | |
| B3 | `NightlySyncWorker` `nightly-sync`, 1 day, delay to 02:30 local, `requiresBatteryNotLow`, KEEP | sync/NightlySync.kt:21-45 | 02, 26 | Full | None | Calls `scanIfPermitted`. |
| B4 | `GmailSyncWorker` periodic `gmail-sync-periodic` (1 day, 02:30, network, battery not low, UPDATE, exponential backoff 30 s) | email/.../GmailSyncWorker.kt:84-95 | 03, 22, 26 | Full | None | Hourly-text mismatch is open question in 26. |
| B5 | `GmailSyncWorker` one-time `gmail-sync-now` (REPLACE, network), `MAX_ATTEMPTS` 5 then failure; `cancel()` on disconnect | GmailSyncWorker.kt:60-102 | 03, 17 | Full | None | |
| B6 | `AlertsWorker` `daily-alerts` (1 day, KEEP, no constraints): card dues, upcoming payments, budgets, gaps; each wrapped in `runCatching` | notify/Alerts.kt:198-218 | 21, 10, 12, 13, 14 | Full | None | |
| B7 | `CardDueReminderChecker.check()` also run at app start | HisaabApplication.kt:42 | 14, 21 | Full | None | |
| B8 | `SmsScanScheduler.scanIfPermitted` at app start | HisaabApplication.kt:40 | 02, 26 | Full | None | |
| B9 | `AccountDao.closeMatured(today IST)` at start | HisaabApplication.kt:45 | 13, 16, 26 | Full | None | |
| B10 | `Updater.checkIfDue()` at start | HisaabApplication.kt:46; update/Updater.kt:50 | 26, 31 | Full | None | 24 h gate, `check_updates`. |
| B11 | `GmailScheduler.schedulePeriodic` at start if enabled | HisaabApplication.kt:47 | 03, 26 | Full | None | |
| B12 | `LanguageStore.restore()` at start | HisaabApplication.kt:37; i18n/I18n.kt:86 | 29, 26 | Full | None | |
| B13 | `reparseOnce` (flag `reparse_v1`) | HisaabApplication.kt:83-91 | 07, 08 | Full | None | |
| B14 | `reattributeAppRows` once (`app_rows_v1`) | HisaabApplication.kt:54-58 | 04, 07, 08 | Full | None | |
| B15 | `reclassifyCardBills` once (`cardbill_v1`) | HisaabApplication.kt:59-64 | 07, 08 | Full | None | |
| B16 | `HoldingRepository.dedupe()` at every start (folds the same investment from several statements) | HisaabApplication.kt:65-66 | none | Missing | Expand file | Grep of memory finds no spec of this startup fold or its rule. Add to 16_portfolio.md (rule: when two holdings are the same investment, merge) and to 26 section 2.7. |
| B17 | Own-number guard: collector of profile phone + statement identity phone/altPhone to `transactions.phoneLast4s` (>= 10 digits, last 4) | HisaabApplication.kt:67-76 | 01, 06, 13, 26, 27 | Full | None | |
| B18 | Payee-account memory wiring (load map at start, write on remember) | HisaabApplication.kt:50-53 | 04, 08, 13 | Full | None | |
| B19 | `PaymentNotificationListener` (NotificationListenerService) | notify/PaymentNotificationListener.kt:31 | 04 | Full | None | Id = `app:` + sha256 prefix of package, key, text. |
| B20 | `CategoryActionReceiver` (goAsync, app scope) | notify/NewTransactionNotifier.kt:117 | 09, 21 | Full | None | |
| B21 | `CardDueActionReceiver` (mark paid, snooze 1 day) | notify/CardDueReminders.kt:203 | 14, 21 | Full | None | |
| B22 | `SpendWidgetReceiver` + `WidgetUpdater` as `TransactionsChangedNotifier` (`updateAll` after any ledger change) | widget/SpendWidget.kt:71-79 | 30 | Full | None | 30:44. |
| B23 | `TransactionsChangedHub` (budget check under mutex after ledger change) | shared and app notifier wiring | 10, 17, 21, 30 | Full | None | |
| B24 | `StatementNotifications.onLocked` (statement needs password) | notify/StatementNotifications.kt:59 | 05, 21 | Full | None | |
| B25 | `BalanceNotifications` (one notification per day per account, id 9000) | notify/BalanceNotifications.kt:36-84 | 21 | Full | None | |
| B26 | `Updater.downloadAndInstall` (APK download, SHA-256 check, installer intent via FileProvider) | update/Updater.kt:62-80 | 31 | Full | None | |
| B27 | Hilt-injected WorkManager configuration (`HiltWorkerFactory`) | HisaabApplication.kt:26-27 | none | Missing | Expand file | Same as P18. Implementation detail only. |

## Gaps list

Missing:

1. `nps-contributions` SharedPreferences (`applied` key set, cap 500, `NpsContributions.kt:29,72-81`): no spec names it. Add to 26 inventory (section 2.5) and the NPS ingest rules in 02/03. (S35)
2. `HoldingRepository.dedupe()` run on every app start (`HisaabApplication.kt:65-66`): no spec states the rule or the trigger. Add to 16_portfolio.md and 26 section 2.7. (B16)
3. Negative platform facts: no boot receiver, no AlarmManager, no foreground service, no exact alarms (P27). One line in 26 section 11.
4. WorkManager custom initialisation with Hilt worker factory (P18, B27). Flutter equivalent (`workmanager` init and callback dispatcher) is not in 26 section 11 or plan.md.
5. `supportsRtl=true` (P21) and target SDK 36 (P22) are not recorded anywhere.

Partial:

6. `gmail_settings` inventory in 26 omits `read_pdf` (default true), `history_id`, `last_sync`, `last_result` and per-address `imap_synced_at:<email>`; 03 has most of them. Make the 26 inventory the single complete list. (S27)
7. `mf-orders` SharedPreferences: documented only as a dedupe key in 05, absent from the 26 inventory, cap not stated. (S34)
8. `MainActivity` `windowSoftInputMode=adjustResize` and the `Theme.Hisaab.Starting` splash theme are not in a native-requirements section. (P9)

Notes for the Flutter port (not gaps in the specs): 26 section 2.5 states every `app_settings` default correctly and matches `AppSettings.kt` line for line. The Data sources toggles and the three notification switches (transaction alerts, card reminders, hide amounts) are exposed in `AlertsScreen.kt` and `SecurityScreen.kt`, both covered.
