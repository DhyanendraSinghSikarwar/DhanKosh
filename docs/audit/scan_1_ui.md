| capability | file:line | notes (hidden/dead/unfinished?) |
|---|---|---|
| Paths relative to hisaab_apk/app/src/main/kotlin/com/hisaab/app (A/) unless prefixed email/, parser-core/, shared/, lang/ | - | line numbers approximate (grep hits) |
| App shell: single Activity, splash held until lock state known, edge-to-edge | A/MainActivity.kt:37-60 | |
| App lock via BiometricPrompt (BIOMETRIC_WEAK or DEVICE_CREDENTIAL), relocks on onStop, skipNextLock for file pickers | A/MainActivity.kt:78-100, A/security/AppLockGate.kt | |
| Lock overlay screen (Unlock button) | A/ui/lock/LockScreen.kt | |
| First-run Welcome sign-in (name + email or phone) gates whole app; email verify code (6-digit, resend) | A/ui/nav/HisaabNavHost.kt:82-87, A/ui/onboarding/WelcomeScreen.kt:199 | strings "Verify your email", "Resend code", "Too many wrong tries" imply a code-verification flow; app claims no server, so verify how the code is delivered (IMAP self-check?) |
| Bottom tab bar (icons only, animated pill): Home, Transactions, Portfolio, Analysis, More | A/ui/nav/HisaabNavHost.kt:70-76, A/ui/nav/TabBar.kt | Settings reached from profile, not a tab |
| Route home | HisaabNavHost.kt:127 | |
| Route transactions with month/category/accountId filter args | HisaabNavHost.kt:154-163, 195 | |
| Route analytics | HisaabNavHost.kt:165 | |
| Route more | HisaabNavHost.kt:173 | |
| Route investments (Portfolio tab) | HisaabNavHost.kt:187 | |
| Route tax | HisaabNavHost.kt:181 | |
| Route rules | HisaabNavHost.kt:182 | |
| Route sources (Data sources) | HisaabNavHost.kt:183 | |
| Route security | HisaabNavHost.kt:184 | |
| Route alerts | HisaabNavHost.kt:185 | |
| Route activity (Activity log) | HisaabNavHost.kt:186 | |
| Route budgets + deep link hisaab://budgets | HisaabNavHost.kt:192 | |
| Route bills + deep link hisaab://bills | HisaabNavHost.kt:198 | |
| Route settings (About & updates) | HisaabNavHost.kt:204 | |
| Route transaction/{id} + deep link hisaab://transaction/{id} | HisaabNavHost.kt:208-210 | |
| Route accounts?tab= | HisaabNavHost.kt:214 | |
| Route review (possible duplicates) | HisaabNavHost.kt:218 | |
| Route compare/{a}/{b} side-by-side duplicate compare | HisaabNavHost.kt:221 | |
| Route add?gap= (add transaction, prefill from untracked balance gap) | HisaabNavHost.kt:224 | |
| Route statements + deep link hisaab://statements?unlock={id} | HisaabNavHost.kt:225-228 | |
| Route statement/{id} | HisaabNavHost.kt:236 | |
| Route bench (parser benchmark screen) | HisaabNavHost.kt:242, A/ui/bench/ParserBenchScreen.kt | HIDDEN/DEV: no navigate("bench") caller anywhere; unreachable from UI |
| Route account/{id} + deep link hisaab://account/{id} | HisaabNavHost.kt:243-245 | |
| Route loans and loan/{id} | HisaabNavHost.kt:249-262 | |
| Routes support, language, news, forex, customize, profile | HisaabNavHost.kt:265-270 | |
| Route category/{key}?month= | HisaabNavHost.kt:148-152 | in-app only, no deep link |
| Manifest VIEW intent filters hisaab://statements, budgets, bills, transaction, account | app/src/main/AndroidManifest.xml:36-51 | no hisaab://category, loan, tax links |
| No launcher shortcuts (no shortcuts.xml / ShortcutManager) | AndroidManifest.xml | absent |
| Home-screen widget "Spent today / This month" (Glance, 3x2, resizable, 30 min period + refresh on tx change) | A/widget/SpendWidget.kt:20-80, res/xml/spend_widget_info.xml | tap only opens MainActivity; no quick-add action, no config |
| Home greeting (morning/afternoon/evening/night) + profile avatar to Profile | A/ui/home/HomeParts.kt:48-87 | |
| Home show/hide amounts eye toggle | HomeParts.kt:93 | hideAmounts default ON |
| Home Accounts shortcut icon | HomeParts.kt:96 | |
| Home Notifications bell opens NotificationsSheet (bottom sheet) | HomeParts.kt:99-116, HomeScreen.kt:188 | |
| Home FAB: Sync everything (SMS + email) with progress counters | HomeScreen.kt:278-341 | |
| Home card: SMS permission prompt (Allow SMS access / Open App settings / Not now) | HomeScreen.kt:291-308, A/ui/components/SmsPermission.kt | |
| Home banners: possible duplicates (Review and merge), statement needs password, update available (Install the update), Welcome | HomeScreen.kt:181-192 | |
| Home add recurring (RecurringSheet) | HomeScreen.kt:120 | |
| Home POST_NOTIFICATIONS runtime permission request | HomeScreen.kt:123 | |
| Home section Spent this month (period/book aware, vs previous period, by account & card expand, income/expenses/saved) | A/ui/home/SpentThisMonth.kt:163-352 | |
| Home section Credit card dues (billed, unbilled, limit left, collapse) | HomeWidgets.kt:474-561 | |
| Home section Cash flow (income/spent/invested/saved, savings rate, best in n months) | HomeWidgets.kt:233-250 | |
| Net worth section (assets/liabilities, chart builds a point per day opened) | HomeWidgets.kt:177-211, A/ui/ledger/NetWorth.kt, A/settings/NetWorthPrefs.kt | migrated off Home to Portfolio (TabLayout.kt:124-132); selection of which money counts |
| Home section Safe to spend today / average per day | HomeWidgets.kt:264-287 | |
| Home section Upcoming 7 days + Calendar link + short-of-funds flag | HomeWidgets.kt:304-317 | "Calendar" link target to confirm |
| Home section Insights (Heads up / Good news / Pattern; See transactions / See bills / Dismiss) | HomeWidgets.kt:359-387 | |
| Home section Spend by category (+Trends link) | HomeWidgets.kt:401-412 | |
| Home section Recent transactions (All link) | HomeWidgets.kt:430 | |
| Home section Budgets (Manage, Set budgets) | HomeWidgets.kt:442-456 | hidden by default (TabLayout.kt:44) |
| Section move up/down and show/hide controls | HomeWidgets.kt:124-126, A/settings/TabLayout.kt | |
| Customise screen: section order/visibility per tab (Home, Analytics, Portfolio), presets Minimal/Spender/Investor/Business/Everything | A/ui/settings/CustomizeTabsScreen.kt, A/settings/TabLayout.kt:29-52 | |
| Customise: theme mode, 20+ palettes (Classic/Hero/Cinema groups), pure-black, text size S/D/L/XL | CustomizeTabsScreen.kt, A/settings/AppSettings.kt:20-45 | Hero/Cinema palettes are film-themed names (licensing flavour) |
| Transactions: search (merchant, amount, note), period/book/bank/type/source chips, list + month + daily calendar view | A/ui/transactions/TransactionsScreen.kt, TransactionViews.kt:108-463 | |
| Transactions daily heat calendar: spend/income/transfers/investments/flagged | TransactionsScreen.kt:231-235, TransactionViews.kt:463 | |
| Transactions LONG-PRESS row enters multi-select (Select all, Merge, Change category, Delete, Cancel) | TransactionsScreen.kt:137-142, 257, 294-310; TransactionViews.kt:269-317 | gesture-only; bulk actions |
| Transactions needs-review strip to Review | TransactionViews.kt:241-292 | |
| Transactions Bills shortcut and Add FAB | TransactionsScreen.kt:149-157 | |
| Undo snackbar after merge | TransactionsScreen.kt:115 | |
| Filter dropdown menus (FilterChip + DropdownMenu) | TransactionViews.kt:155-170 | |
| Period sheet: This week/month, Last month, This FY, Last FY, Last 12 months, Custom date-range picker | A/ui/ledger/FilterChips.kt:82-129 | |
| Book sheet: Personal / Business global book | FilterChips.kt:64-75 | |
| Transaction detail: delete confirm, change account (remember for payee), note, forex rate, category + sub-category sheets, messages list, split "not the same transaction" | A/ui/transactions/TransactionDetailScreen.kt:102-271 | |
| Add transaction: Payment / Transfer to my account / Money received; date+time pickers; category sheet; account; reference; note | A/ui/add/AddTransactionScreen.kt:271-412 | |
| Add transaction: fill from screenshot (photo picker + ML Kit on-device OCR) | AddTransactionScreen.kt:266-282, 188 | |
| Add transaction from untracked-balance gap (Assign / Looks like) | AddTransactionScreen.kt:300-306, A/ui/accounts/GapCard.kt, GapTracker.kt | |
| Review possible duplicates: Compare, Keep both, Merge | A/ui/review/ReviewScreen.kt:99-204 | |
| Analytics category donut + legend; TAP filters cards below, LONG-PRESS opens category | A/ui/analytics/AnalyticsScreen.kt:161-217 | hint text explains gesture |
| Analytics Monthly spend 12-month bars (tap bar opens MonthSheet) + essentials/lifestyle/other | AnalyticsScreen.kt:235-294 | |
| Analytics "When you spend" day/hour heatmap with peak | AnalyticsScreen.kt:318-344 | |
| Analytics Top merchants (per category) + payments bottom sheet (latest 60) | AnalyticsScreen.kt:356-395 | |
| Analytics Where your income went (income to spent/invested/left over/shortfall) | A/ui/analytics/AnalyticsSegments.kt:47-72 | |
| Analytics Income vs spend savings-rate chart | AnalyticsSegments.kt:79-97 | needs 2 months income |
| Analytics Month-end spend forecast (likely/range/budget verdict) | AnalyticsSegments.kt:110-145 | |
| Analytics Cash balance next 30 days projection + shortfall warning | AnalyticsSegments.kt:150-178 | |
| Analytics Period vs previous by category (+/-50% bars) | AnalyticsSegments.kt:188-214 | |
| Analytics Budgets progress + pace vs even pace | A/ui/analytics/AnalyticsBudgets.kt:42-159 | |
| Charts library (donut, bars, sparkline, heatmap) | A/ui/charts/Charts.kt, ProtoCharts.kt | "ProtoCharts" suggests prototype/duplicate of Charts.kt: possible dead code |
| Category detail screen (sub-categories, month, merchants) + new sub-category dialog | A/ui/category/CategoryDetailScreen.kt:198, CategoryParts.kt:115-183 | |
| Category picker sheet with search, create category (name, icon, colour) | A/ui/components/CategorySheet.kt:44-103, IconLibrary.kt | |
| Budgets screen: list, ExtendedFAB "Budget", BudgetDialog add/edit/delete, monthly limit per category | A/ui/budgets/BudgetsScreen.kt:136-258 | |
| Accounts screen: tabs, FAB add account, overflow "Restore missing accounts" | A/ui/accounts/AccountsScreen.kt:303-310 | |
| Add account/card/deposit sheet (FD, RD, PPF, NRE/NRO, prepaid/forex, wallet) incl. maturity date picker | A/ui/accounts/AccountForms.kt:99-181 | |
| Account edit sheet: nickname, hide, delete (with/without transactions), merge duplicate | AccountsScreen.kt:630-846 | |
| Possible duplicate account merge dialog | AccountsScreen.kt:398-462 | |
| Account detail (balances, card position, gap tracker, transactions) | A/ui/accounts/AccountDetailScreen.kt, CardAmountsSheet.kt:83-189 | edit billed/unbilled/min due/limit |
| Bank details sheet (customer ID, IFSC, account no., mobile, email) | A/ui/accounts/BankDetailsSheet.kt | stored on phone |
| Credit card bill due actions (Mark paid) | A/ui/accounts/CardBill.kt, CardDueActions.kt | |
| Link debit card to account prompt | A/ui/accounts/AccountsScreen.kt (keys.json "Link this debit card?") | |
| Portfolio: holdings, asset allocation donut (tap slice filters), net worth, maturity calendar 12 months, FAB add holding | A/ui/invest/InvestmentsScreen.kt:172-261, PortfolioSections.kt | |
| Holding add/edit sheet (units, invested, current value) | InvestmentsScreen.kt:222-231 | |
| PPF/EPF/NPS section (PRAN, tier) | PortfolioSections.kt (keys.json "PPF, EPF & NPS") | |
| Portfolio loans section | A/ui/invest/PortfolioLoans.kt | |
| Statements: import PDF/Excel/CSV (document picker), list, locked state, unlock dialog (remember password), add statement password | A/ui/invest/StatementsScreen.kt:182-340 | |
| Statement detail (added vs matched counts, transactions) | A/ui/invest/StatementDetailScreen.kt | |
| Loans: detected EMIs, FAB add loan, AddLoanSheet, TermsSheet, remove dialog, merge-into sheet, link payments, amortisation/payoff | A/ui/loans/LoansScreen.kt:216-869, LoanLinkSheet.kt | |
| Bills & subscriptions: auto-detected recurring, FAB add regular payment, RecurringSheet (monthly/yearly, account, category) | A/ui/plan/BillsScreen.kt:105-114, RecurringEditor.kt:71-165 | |
| More hub entries: Budgets, Bills, Loans, Tax centre, Rules, Data sources, Activity log, Accounts, Statements, Customise, Notifications, Security & backup, Language, Forex, About & updates | A/ui/more/MoreScreen.kt:200-300 | |
| More: profile avatar to Profile | MoreScreen.kt (top bar) | |
| More footer "You're all caught up" / "DhanKosh vX" | MoreScreen.kt (footer item) | |
| Market News screen (RSS: Business Standard, ET, Moneycontrol, Mint; Segmented tabs; open in browser) | A/ui/news/NewsScreen.kt:100-119, 235-298 | not in More list; reached from Portfolio (HisaabNavHost.kt:189) |
| Tax centre: FY estimate old vs new regime, slabs, 87A, surcharge, cess, 80C/80D/NPS/24(b), recommended regime | A/ui/more/TaxScreen.kt, TaxReport.kt | resident under 60 only |
| Tax what-if sheet (Calculate / Reset / Back to calculated) | A/ui/more/TaxWhatIf.kt:92-126 | not saved by design |
| Tax share: PNG (1440px) or A4 PDF via FileProvider + ACTION_SEND; "Share with amounts?" dialog | A/ui/more/TaxShare.kt:68-150, TaxReport.kt:28-105 | |
| Capital gains hint ("Enter in the calculator if you sold equity") | keys.json, TaxScreen.kt | partial: manual what-if only |
| Rules: merchant/UPI text to category rules, ExtendedFAB add rule, edit sheet with sub-category, past transactions apply | A/ui/more/RulesScreen.kt:189-377 | |
| Data sources: SMS (read now, bank senders dialog), Email (Gmail OAuth / IMAP app password), payment-app notification access, history-to-read | A/ui/more/DataSourcesScreen.kt:163-376 | |
| Email connect dialog (provider list, app-password guide, 6-digit code) | A/ui/settings/EmailConnect.kt:145-237, AppPasswordGuide.kt | |
| Gmail Google sign-in "Advanced (needs Google Cloud OAuth client)" | keys.json; email/src/main/kotlin/com/hisaab/email/auth/GmailAuthManager.kt:81 | HIDDEN/optional: only if GOOGLE_WEB_CLIENT_ID set; Welcome passes onUseGoogle=null |
| Activity log (each sync; clear-log dialog) | A/ui/more/ActivityLogScreen.kt:177, A/log/ActivityLog.kt | |
| Notifications & alerts settings (transaction notifications, card due reminders, budget alert %, open Android notification settings) | A/ui/more/AlertsScreen.kt:49-80 | |
| Security & backup: app lock, hide amounts, text size, CSV Export (CreateDocument) / Import (OpenDocument) | A/ui/more/SecurityScreen.kt:64-91, A/csv/CsvTransfer.kt:23 | CSV only (15 columns); no encrypted/full backup; allowBackup=false |
| Language: 8 languages (en hi bn te mr ta gu kn) downloaded on demand from GitHub raw | A/ui/more/LanguageScreen.kt, A/i18n/I18n.kt:26-137 | needs network; offline fallback English |
| Forex rates: per-currency/date manual rates, FAB add, markup, "need a rate" | A/ui/settings/ForexRatesScreen.kt:101-198 | no live FX API |
| About & updates: version, Check / Install | A/ui/settings/SettingsScreen.kt:44-87 | |
| In-app updater: GitHub Releases API, sha256 verify, FileProvider + package installer, daily check | A/update/Updater.kt:80-149 | REQUEST_INSTALL_PACKAGES |
| What's New sheet (release notes) | A/ui/more/WhatsNew.kt:130 | |
| Support page: UPI pay intent (upi://pay) + generated QR | A/ui/more/SupportScreen.kt:62-150, QrCode.kt | UPI id hard-coded 8054276810@ybl; support_qr.webp optional; button hidden if blank |
| Profile: name, email, phone, occupation, photo pick + crop/zoom/rotate | A/ui/profile/ProfileScreen.kt, PhotoCrop.kt:140-175, ProfileHeader.kt | |
| First-run profile setup sheet (Later) | ProfileScreen.kt:332-352 | |
| Statement unlock details (PAN, DOB, customer ID, mobile) to guess PDF passwords | A/ui/profile/StatementDetails.kt, parser-core PasswordGuesser | |
| InfoButton (i) explanation dialogs | A/ui/components/InfoButton.kt:31 | |
| Message view (original SMS/email text, Copy text) | A/ui/components/MessageView.kt | |
| Brand logos (130+ webp assets + SVG paths) | A/ui/components/BankLogo.kt, AppLogos.kt, LogoPaths.kt; app/src/main/assets/logos | |
| Notification: new transaction (low importance) with category quick-action buttons | A/notify/NewTransactionNotifier.kt:41-136 | |
| Notification: card bill due (5 days, 2 days, due date, overdue) with Mark paid / Remind tomorrow actions | A/notify/CardDueReminders.kt:45-236 | |
| Notification: budget at alert % and 100% | A/notify/Alerts.kt:64-80 | |
| Notification: payment due within 3 days from low balance; insurance renewal within a week | Alerts.kt:85-120 | |
| Notification: untracked balance change ("Add it?") | Alerts.kt:130-160, GapTracker.kt | |
| Notification: statement needs password to hisaab://statements?unlock | A/notify/StatementNotifications.kt:34 | |
| Notification: balance notifications | A/notify/BalanceNotifications.kt:58-68 | opens MainActivity only, no deep link |
| Daily AlertsWorker (WorkManager) | Alerts.kt:197-215 | |
| NightlySyncWorker (daily SMS scan, battery-not-low) | A/sync/NightlySync.kt:21-43 | |
| Gmail periodic sync worker (daily at night) | email/src/main/kotlin/com/hisaab/email/sync/GmailSyncWorker.kt:75-89 | string says "checks every hour" but worker is 1 DAY: inconsistent |
| SMS BroadcastReceiver (SMS_RECEIVED priority 999) real-time parse | A/sms/SmsReceiver.kt:50, AndroidManifest.xml:54 | |
| SMS inbox backfill worker + scan scheduler | A/sms/OptimizedSmsReaderWorker.kt, SmsScanScheduler.kt, SmsInboxSource.kt | |
| Payment-app NotificationListenerService (GPay, PhonePe, Paytm, BHIM, CRED, Amazon Pay, MobiKwik, Navi, super.money, Freecharge, YONO SBI, HDFC, ICICI iMobile, more) | A/notify/PaymentNotificationListener.kt:97-143 | opt-in |
| External intents: Android settings (notification listener, app notification, app details) | DataSourcesScreen.kt:163, AlertsScreen.kt:49, SmsPermission.kt:49 | |
| External intents: open news link, provider app-password URLs in browser | NewsScreen.kt:226, EmailConnect.kt:236 | |
| External intent: UPI chooser "Pay with" | SupportScreen.kt:146-150 | |
| One-time maintenance migrations (reparse, reattribute app rows, reclassify card bills, holdings dedupe, close matured deposits) | A/HisaabApplication.kt:42-98 | |
| ML Kit text recognition on-device; datatransport CCT backend removed for privacy | app/build.gradle.kts:108; AndroidManifest.xml:98-109 | |
| Network: Gmail REST (readonly scope) + oauth2 revoke | email/.../api/GmailApi.kt:34, auth/GmailAuthManager.kt:121-128 | |
| Network: IMAP to Gmail/Outlook/Yahoo/iCloud/Zoho/AOL with app passwords (Keystore encrypted) | email/.../imap/MailServers.kt:26-47, auth/KeystoreSecret.kt | |
| Network: GitHub raw language packs + GitHub Releases API | I18n.kt:137, Updater.kt:147 | |
| Network: RSS news feeds (14 URLs) | NewsScreen.kt:100-119 | |
| No analytics, ads, crash SDK, FCM found; allowBackup=false | AndroidManifest.xml, build.gradle.kts | |
| Parser engine: bank parsers (HDFC, ICICI, SBI, Axis, Kotak, PNB, BoB, IDFC, AU, Yes + generic), templates, merchant normaliser, rejection rules | parser-core/src/main/kotlin/com/hisaab/parser/** | |
| Statement parsers (MF order, CAS, bank/card PDFs, Excel/CSV) | parser-core/.../statement/, email/.../mime/PdfTextExtractor.kt, SpreadsheetExtractor.kt | |
| Room DB v13 with migrations; forex, recurring, categories, sub-categories | shared/schemas/*.json, shared/src/main/kotlin/com/hisaab/shared/db/ | |
| Strings: res/values/strings.xml only app_name + widget strings; all UI text via t("English key") + lang/*.json packs; keys.json has 1456 keys | app/src/main/res/values/strings.xml, lang/keys.json | |
| keys.json: "Separate Credit cards card on Home", "Hero and Cinema themes, pure-black dark mode", "Fold theme", "Seven language packs" | keys.json:1005, 490, 693, 1014 | release-note strings from WhatsNew |
| keys.json: "Calendar ›" link from Upcoming | keys.json:193, HomeWidgets.kt:304 | target unclear |
| keys.json: "Remove download", "Tap to download" language pack states | keys.json:937, 1099 | |
| keys.json: "Employer NPS 80CCD(2)", "Tax on capital gains" | keys.json | partially implemented |
| keys.json: "Sign in & send code", "Sign out" (Gmail revoke) | keys.json:1036, 1040 | |
