# Existing App Analysis: hisaab_apk (DhanKosh, formerly Hisaab)

> Reference only, not the source of truth. Feature files in `memory/` own the requirements.
> Analysed 2026-10-16 from source (no decompile needed): Kotlin, Jetpack Compose, Hilt, Room v15; modules `app`, `shared`, `parser-core`, `email`. Version 2.9.8 (versionCode 33), applicationId `com.hisaab`.
> Sources read: all `src/main` code, FEATURES.md, README.md, AGENTS.md, CHANGELOG.md, doc/, plus `v2_design/` (a separate v2 spec, treated as Proposed).
> Part A = app UI and platform; Part B = database, business rules, parser; Part C = email, statements, v2 spec.

---

# A. Android app (`:app`) - UI, navigation, settings, background work, cross-cutting

Source analysed (read-only): `hisaab_apk/app/src/main` (Kotlin + Compose), `app/build.gradle.kts`, `res/xml`, `res/values`, `assets/logos` (names only), `lang/` (structure only), `FEATURES.md`.
All paths below are relative to `hisaab_apk/app/src/main/kotlin/com/hisaab/app/` unless they start with `hisaab_apk/`. Line refs are `file:line` against the files as read.

Naming note: product is **DhanKosh** (formerly Hisaab). `applicationId = com.hisaab`, `namespace = com.hisaab.app`, `app_name = "DhanKosh"` (`res/values/strings.xml`), logo asset `artha_mark.png`. Package names still say `hisaab`, user-visible text says DhanKosh.

Build facts (`hisaab_apk/app/build.gradle.kts`): compileSdk 37, targetSdk 36, minSdk 26, versionCode 33, versionName `2.9.8`, ABI filters arm64-v8a + armeabi-v7a, release minify + shrink on, Java 17. Libraries that matter for a port: Compose BOM + Material3 + icons-extended, Navigation-Compose, Hilt (+hilt-work), WorkManager, DataStore Preferences, androidx.biometric, DocumentFile, Haze, Glance (widget), OpenCSV, ML Kit Latin text recognition (bundled model), profileinstaller. Modules: `:parser-core`, `:shared` (Room, repos, insight maths), `:email` (IMAP/Gmail, statements) - those are covered by other analysis parts.

---

## 1. Navigation map

### 1.1 Shell
- `MainActivity` (`MainActivity.kt:31`) is a `FragmentActivity` (BiometricPrompt needs it). Splash (`Theme.Hisaab.Starting`, `windowSplashScreenAnimatedIcon = ic_launcher_mark`) is held until the app-lock setting is known (`MainActivity.kt:46`).
- Content tree: `HisaabTheme(theme, palette, textScale, pureBlack)` > `Box { HisaabNavHost(); if (lock && !unlocked) LockScreen }`. The nav host stays composed under the lock so unlocking returns to the same screen (`MainActivity.kt:62-72`).
- Before the NavHost: **WelcomeScreen gate** (`ui/nav/HisaabNavHost.kt:83-88`). `WelcomeViewModel.needed` (`ui/onboarding/WelcomeScreen.kt:77`) = `profile.name == null || (profile.email == null && profile.phone == null && !mail.connected)`. While loading (`null`) nothing is drawn; `true` shows WelcomeScreen; `false` shows the app. Someone who connected an inbox before this screen existed counts as signed in.
- No NavHost route for Welcome or Lock; both are overlays/gates.
- Transitions (`HisaabNavHost.kt:107-125`): tab-to-tab = 180 ms cross-fade; push = 280 ms fade + slide 1/8 width; pop reverses. `isTabSwitch()` checks both ends are tab routes.
- Back stack helpers (`HisaabNavHost.kt:288-297`): `openTab(route, restore=true)` = `navigate` with `popUpTo(startDestination){saveState=restore}`, `launchSingleTop`, `restoreState=restore`. `goHome()` pops to `home` or navigates to it. `restore=false` is used by Home "See all" so new args (month) win.
- Start destination: `home`.

### 1.2 Bottom tabs (icons only, no labels)
`private enum class Tab` (`HisaabNavHost.kt:70`), rendered by `AnimatedTabBar` (`ui/nav/TabBar.kt:57`): flat surface (`surfaceContainer`) + hairline top, soft accent pill (12% alpha, 16dp radius, max 68dp wide) springs to the selected slot, selected icon gets a 1.15x spring, haptic `TextHandleMove` on change, 26dp icons, 42dp row, testTag `tab-<route>`. Bar is shown only when the current route (query string stripped) equals a tab route (`showBar`, line 91).

| # | Route | Label (a11y) | Icon | Screen |
|---|---|---|---|---|
| 1 | `home` | Home | `Home` | HomeRoute |
| 2 | `transactions` | Transactions | `SwapVert` | TransactionsRoute |
| 3 | `investments` | Portfolio | `BusinessCenter` | InvestmentsRoute |
| 4 | `analytics` | Analysis | `BarChart` | AnalyticsRoute |
| 5 | `more` | More | `Menu` | MoreRoute |

Tab 2 route pattern is `transactions?accountId={accountId}&category={category}&month={month}` (so the tab bar's `transactions` base route still matches). Settings is NOT a tab ("Settings is reached from the profile, not from here" - actually reached from More > About & updates and Home update notice).

### 1.3 Complete route table (`HisaabNavHost.kt:127-274`)

| Route pattern | Args | Composable (file) | Reached from | Deep link |
|---|---|---|---|---|
| `home` | - | `HomeRoute` (ui/home/HomeScreen.kt) | start / tab | - |
| `category/{key}?month={month}` | key String (enum name e.g. `FOOD` or `custom:<id>`), month String? (`YYYY-MM`) | `CategoryDetailRoute` (ui/category/CategoryDetailScreen.kt) | Home categories donut, Analytics legend, month sheet | - |
| `transactions?accountId={accountId}&category={category}&month={month}` | accountId Long (default -1), category String? (Category enum name), month String? | `TransactionsRoute` (ui/transactions/TransactionsScreen.kt) | tab; Home "See all"/"All"; Account detail "See transactions"; Budgets (`transactions?category=X&month=<now>`) | - |
| `analytics` | - | `AnalyticsRoute` | tab, Home | - |
| `more` | - | `MoreRoute` | tab | - |
| `tax` | - | `TaxRoute` (ui/more/TaxScreen.kt) | More | - |
| `rules` | - | `RulesRoute` | More | - |
| `sources` | - | `DataSourcesRoute` | More, profile | - |
| `security` | - | `SecurityRoute` | More | - |
| `alerts` | - | `AlertsRoute` | More | - |
| `activity` | - | `ActivityLogRoute` | More | - |
| `investments` | - | `InvestmentsRoute` | tab, Home | - |
| `budgets` | - | `BudgetsRoute` | More, Home, Analytics | `hisaab://budgets` |
| `bills` | - | `BillsRoute` (ui/plan/BillsScreen.kt) | More, Home upcoming, Transactions top-bar icon | `hisaab://bills` |
| `settings` | - | `SettingsRoute` ("About & updates") | More entry `settings`, Home update notice | - |
| `transaction/{id}` | id Long | `TransactionDetailRoute` | any list row | `hisaab://transaction/{id}` |
| `accounts?tab={tab}` | tab Int default 0 (0 accounts, 1 cards, 2 deposits & loans) | `AccountsRoute` | Home header bank icon, More, Portfolio holdings/maturity | - |
| `review` | - | `ReviewRoute` ("Possible duplicates") | Home bell notice, Transactions review banner | - |
| `compare/{a}/{b}` | a, b Long | `CompareRoute` | Review pair "Compare" | - |
| `add?gap={gap}` | gap String default "" (`<accountId>_<fromMs>_<toMs>_<deltaMinor>_<card 0/1>`, see `gapRoute`, `ui/accounts/GapCard.kt:51`) | `AddTransactionRoute` | Transactions FAB, Account gap card "Add transaction" | - |
| `statements?unlock={unlock}` | unlock Long default -1 | `StatementsRoute` | More, Data sources, Home notice | `hisaab://statements?unlock={unlock}` |
| `statement/{id}` | id Long | `StatementDetailRoute` | Statements row (parsed only) | - |
| `bench` | - | `ParserBenchRoute` ("Test the parser") | **No caller found** (dev-only, unreachable from UI) | - |
| `account/{id}` | id Long | `AccountDetailRoute` | Accounts list, Home card rows, "By account" rows | `hisaab://account/{id}` |
| `loans` | - | `LoansRoute` | More | - |
| `loan/{accountId}?emi={emi}` | accountId Long (`-1` for a detected EMI), emi String? (URL-encoded payee key) | `LoanDetailRoute` | Loans list, Portfolio loans, Bills EMI rows, Accounts (loan type) | - |
| `support` | - | `SupportRoute` | Profile top bar cup icon | - |
| `language` | - | `LanguageRoute` | More | - |
| `news` | - | `NewsRoute` | Portfolio top bar newspaper icon | - |
| `forex` | - | `ForexRatesRoute` | More | - |
| `customize` | - | `CustomizeTabsRoute` | More | - |
| `profile` | - | `ProfileRoute` | Home header avatar, More top-bar avatar | - |

`loanRoute(key)` (`ui/loans/LoanSource.kt:59`): `a<id>` -> `loan/<id>`, `e<payeeKey>` -> `loan/-1?emi=<Uri.encode(key)>`. `LoanDetailViewModel` key = `a$accountId` if accountId > 0 else `e$emi` (`LoansScreen.kt:422`). "Track as loan" on a detected EMI navigates to `loan/<newId>` and pops the old entry (`HisaabNavHost.kt:262`).

More list entries -> routes (`ui/more/MoreScreen.kt:196-296`), grouped:
- **Plan**: `budgets`, `bills` ("Bills & subscriptions"), `loans`, `tax` ("Tax centre").
- **Automation**: `rules`, `sources` ("Data sources", subtitle `SMS ✓/✗ · Email ✓/✗ · Notifications ✓/✗`, warn colour when SMS or notification reading is off), `activity` ("Activity log").
- **Accounts**: `accounts` ("Accounts & cards"), `statements`.
- **App**: `customize`, `alerts` ("Notifications & alerts"), `security` ("Security & backup"), `language`, `forex`, `settings` ("About & updates", shows `Version x`).
- Top-bar avatar -> `profile`. `onOpen("investments"|"analytics")` uses `openTab`, else `navigate`.
- Not in More: `support` (via Profile), `news` (via Portfolio), `review`/`statement/..`/`compare` (contextual), `bench` (none).

### 1.4 Deep links
Manifest (`AndroidManifest.xml:36-53`) filters on `MainActivity` (exported), scheme `hisaab`: hosts `statements`, `budgets`, `bills`, `transaction`, `account`. Nav-graph deep links registered in `HisaabNavHost`: `hisaab://budgets`, `hisaab://bills`, `hisaab://transaction/{id}`, `hisaab://statements?unlock={unlock}`, `hisaab://account/{id}`. Producers:
- New-transaction notification content intent -> `hisaab://transaction/<id>` (`notify/NewTransactionNotifier.kt:60`).
- Statement locked notification -> `hisaab://statements?unlock=<statementId>` (`notify/StatementNotifications.kt:34`); `StatementsRoute` auto-opens the unlock dialog for that id once if still LOCKED (`ui/invest/StatementsScreen.kt:176`).
- Budget alerts -> `hisaab://budgets`; bill/renewal alerts -> `hisaab://bills`; untracked-gap alerts and card-due reminders -> `hisaab://account/<id>` (`notify/Alerts.kt:77,109,120,143`; `CardDueReminders.kt:173`).
- Balance-updated notification opens MainActivity with no deep link (`BalanceNotifications.kt:60`).
- The widget click starts MainActivity (`widget/SpendWidget.kt:60`).
- Also `FileProvider` `${applicationId}.updates` (not a nav link): paths `cache/updates/` and `cache/shared/` (`res/xml/update_paths.xml`).

---

## 2. Screen / dialog / sheet inventory

Shared building blocks (`ui/components/Kit.kt`, `Components.kt`): `HCard` (title/action/titleInfo/onClick, flat card with 1dp hairline, 12dp `CardGap`), `HeroCard` (palette gradient), `CollapsibleCard`, `KpiRow`/`Kpi`, `Pill` (filter chip), `Tag`, `Delta`, `Segmented`, `SplitBar`, `HRow` (title/subtitle/leading/trailing/onClick), `LegendItem`, `RoundIcon`, `EmptyState(icon,title,body)`, `AnimatedAmount` (count-up), `shimmer`, `pressScale`/`pressable`, `enterOnce(index)` staggered entrance, `InfoButton` + `Info.*` canned explanations (`components/InfoButton.kt:46`). Top bars: `clearTopBar()` = solid background-coloured (no tonal scroll colour). All More sub-screens share `MoreScaffold` (`ui/more/MoreCommon.kt:29`), `SettingSwitch`, `HelpText`, `listPadding`.

Layout convention: Material3 `Scaffold(containerColor = Transparent)` over `Modifier.appBackdrop()` (see 6.1). Money/privacy helpers: `Money.format`, `AmountPrivacy` (see 6.3).

"Feature" column uses FEATURES.md section names.

### 2.1 Onboarding / gate

| Screen | File | Purpose, widgets, actions, states | Feature |
|---|---|---|---|
| WelcomeScreen | ui/onboarding/WelcomeScreen.kt:105 | First-run sign-in. Gradient backdrop (accent 18% -> transparent -> second hero colour 12%), 96dp `artha_mark`, "DhanKosh", "Know your money.". Name field ("Full name (as per bank)"). Three modes (`mode` saveable): **choose** ("Continue with email" opens `EmailConnectDialog`; "Continue with phone number" -> phone) ; **phone** (+91 prefix, 10 digits, "Continue", "Use email instead"); **details** ("Unlock your statements": mobile (only when email path), `AlternateFields`, `StatementDetailsFields` DOB+PAN, "Finish" enabled when PAN valid-or-blank, "Skip for now"). Footers "Email sign-in also reads your bank alerts and statements." and lock "Your data never leaves this phone." `finish()` saves `Identity(name, dob, pan, mobile, altName, altPhone, email)` into the sealed `StatementPasswordStore` FIRST, then `AppSettingsStore.saveProfile` (which ends sign-up). Alternates only live in the sealed identity. | Profile / security |
| LockScreen | ui/lock/LockScreen.kt:21 | Full-screen overlay: lock icon, "DhanKosh is locked", "Unlock" button re-triggers BiometricPrompt. | Security |
| Biometric prompt | MainActivity.kt:87 | `BiometricPrompt` title "Unlock DhanKosh", subtitle "Your transactions are protected", authenticators `BIOMETRIC_WEAK or DEVICE_CREDENTIAL`. Prompt re-fires on resume if locked. | Security |

### 2.2 Home (`ui/home/*`)
HomeRoute (`HomeScreen.kt:93`) + `HomeScreen` (146). LazyColumn with 12dp spacing and `bottom = tabBarPadding + 140dp`.
- Items in order: `header` (HomeHeader: profile avatar+greeting+name, tap -> profile; eye toggle (hide amounts); bank icon -> accounts; bell with badge), `filters` (`BookPeriodChips`), optional `sms` PermissionCard (when READ_SMS missing and `smsPromptDismissed == false`), then widgets from `TabLayout.visible("home")` via `itemsIndexed`.
- Collapsed header floats once `firstVisibleItemIndex > 0`. Opaque status-bar cover. 3dp linear progress under the status bar while sync active (`sync.active`). `SyncPill` bottom-start (see below). Single FAB: sync (rotating `Sync` icon, `primaryContainer`); `onAdd`/`onAddRecurring` parameters exist but the add FAB was removed (adding lives on Transactions tab); `RecurringSheet` on Home is only reachable through the unused `addingRecurring` flag - effectively dead.
- Greeting by hour (`HomeParts.kt:47`): 5-11 morning, 12-16 afternoon, 17-21 evening, else night.
- Permission request on first composition: `POST_NOTIFICATIONS` (API >= 33) once, guarded by `notificationsAsked` (`HomeViewModel.shouldAskNotifications`, line 232).
- `rememberSmsPermission(onGranted = scanInbox(full = true))` (`ui/components/SmsPermission.kt:71`): requests `READ_SMS`+`RECEIVE_SMS`; re-checks on every resume; after refusal with no rationale => `blocked` (shows "Android didn't show the permission prompt. Open App settings, then Permissions, SMS, Allow... Allow restricted settings" and button becomes "Open App settings").
- Notices (`NotificationsSheet`, ModalBottomSheet "Notifications"; empty "You're all caught up."): (a) "{n} possible duplicate(s)" -> `review`; (b) one per locked statement "Statement needs a password" -> `statements`; (c) "DhanKosh {version} is available / Install the update" + WhatsNewButton -> `settings`.
- SyncPill (`HomeScreen.kt:318`): "Reading messages · n" / "Reading email · n" while running, then 3 s "n messages · m emails read".
- HomeViewModel: `syncAll()` = `SmsScanScheduler.scanRecent` (14 days) + `GmailScheduler.syncNow` if connected+enabled + `alerts.checkBudgets/checkUpcoming` + `statementProcessor.retryLocked`. `seedHomeOnce()` migration on init. Sync progress comes from WorkManager infos (`KEY_SCANNED`, `GmailSyncWorker.KEY_EMAILS_READ`).

Home widgets (section key -> composable; titles via `t()`; all follow global Book + Period filter):

| Key | Widget (`HomeWidgets.kt`/`SpentThisMonth.kt`) | Content / states |
|---|---|---|
| `spent` | `SpentThisMonthWidget` (SpentThisMonth.kt:154), hero card | Title varies by period ("Spent this month / last month / this week / Spent · {period}"). Loading: "Loading…". `AnimatedAmount` 30sp; "Last month: ₹x" (or Previous month/period); % chip (green if less); cumulative spend line chart this vs previous (dashed); Income / Expenses / Saved tiles; folded "By account & card" list with share bars, "Other", "Total"; empty "No spending this month/in this period." Teal = `Hx.palette[2]`. |
| `cards` | `CreditCardsWidget` (HomeWidgets.kt:468) "Credit card dues" | Folded header "{n} cards" + total billed (red) or "No dues"; rows via `CardHomeRow`: avatar, name ••last4, status (Paid / Overdue · date / Due today / Due {date} · n days / Unbilled / Limit left), amount (`~` if estimated), `MarkPaidButton` when billed, unpaid and due in <= 7 days. Empty "No credit cards yet." |
| `cashflow` | `CashFlowWidget` "{period} cash flow" | KPI Income/Spent/Invested/Saved (compact), `SplitBar`, "Savings rate x%" + "best in {n} months" (only when this month's rate beats all other >= 2 months). Empty "No income recorded in this period." Action "Analyse ›". |
| `upcoming` | `UpcomingWidget` "Upcoming · 7 days" | Up to 5 items due in 0..7 days; date badge; colour by tone (CARD red, EMI/insurance amber, INVEST accent, INCOME green); "short of funds". Empty "Nothing due in the next 7 days." |
| `insights` | `InsightsWidget` | Snap carousel (86% width), tag Heads up/Good news/Pattern, title (2 lines), detail (3 lines), "See transactions/See bills" + Dismiss (session only, by title). Empty "No insights right now." |
| `categories` | `CategoriesWidget` "Spend by category" | Donut (top 7 + Others), legend with %, tap slice/legend opens category screen; empty "No spending in this period." |
| `recent` | `RecentWidget` "Recent" | Last 4 transactions (`RECENT = 4`); empty "No transactions in this period." |
| `budgets` | `BudgetsWidget` "Budgets" (hidden by default) | Up to 3 progress rings (most used first), colour green <80%, amber >= 80%, red >= 100%; empty state "Set monthly limits..." + "Set budgets" pill. |
| (legacy) `networth`, `safe` | `NetWorthWidget` / `SafeWidget` exist in code but `"networth" -> Unit` and "safe" is not in the default list | Dead/legacy. `NetWorthHeroCard` is reused by Portfolio. |
| (legacy) edit mode | `WidgetEdit` up/down/show-hide controls | Home passes `edit = null`; ordering is done only in Customise. |

Safe-to-spend maths (kept in VM though not shown): current month: `(base - spent - reservedBills) / daysLeft` where base = sum of budgets, else income (`HomeViewModel.kt:268`). 

### 2.3 Transactions (`ui/transactions/*`)
- **TransactionsRoute** (`TransactionsScreen.kt:85`): Scaffold; top bar "Transactions" + Bills icon (`EventRepeat`); FAB add (hidden while selecting). Fixed controls: `SearchBox` (44dp, placeholder "Search merchant, amount, note…", match-count badge, clear), `TxFilters` row (dropdown chips Type / Bank (logos, "HDFC"/"HDFC Bank" merged via `Brands.forBank(name).name`) / Source, with `BookPeriodChips(showBook=false)`, plus removable pills for an account or category scope that arrived via route args). LazyColumn items: `kpi` card (`TxSummaryStrip` Income/Expenses/Net, "{n} transactions · {period}" + "Out includes investments"), `review` banner (when `reviewCount > 0`), `segments` (List / Calendar / By merchant), then content.
  - Type chips (`TxKind`): All, Income, Spends, Investments, Transfers; `REVIEW` ("Needs review") has no chip - the banner selects it. Source (`TxSource`): SMS, Email, Statement, App (APP + NOTIFICATION), Manual (shown only when some row has none of the others).
  - Empty states (`EmptyState(ReceiptLong,"Nothing here")`): search miss, filter miss, empty period (text includes period label).
  - List view: `DayCard` per day (header "Today/Yesterday/EEE, d MMM yyyy", net and out). Calendar view: `CalendarCard` month grid limited to the period, per-day value (spend / income / transfers / investments / flagged by selected kind), tap day shows that `DayCard` else `CalendarDayHint`. Merchant view: `MerchantCard` per `merchant ?: bankName`, sorted by gross, expandable.
  - Multi-select: long-press toggles; top bar becomes "{n} selected" with Select all, Merge (>= 2), Change category, Delete; `BackHandler` clears selection. Dialogs: `CategorySheet` "Category for {n} transactions"; AlertDialog "Merge into one payment?" (undo via snackbar "Merged into one payment." + Undo); AlertDialog "Delete {n} transactions?" ("won't come back on a rescan"). Choosing EMI_LOAN category triggers `LoanLinkPrompt`.
  - Route args: `accountId` expands to merged children (`mergedIntoId`), `category` filters, `month` calls `ViewFilterStore.setMonth` once in VM init.
  - Search matches merchant, bank, note, reference, upiId, category label, or amount-prefix on whole-rupee digits (`TransactionsViewModel.matchesSearch`, line 188). Debounce 120 ms.
- **TransactionDetailRoute** (`TransactionDetailScreen.kt:95`): top bar "Transaction" + delete (AlertDialog "Delete this transaction?"). Body: avatar (merchant logo or category badge + bank badge), merchant (or category), signed amount; Category card + Sub-category card (rows -> `CategorySheet` then `SubcategorySheet`; "Sub-category (automatic)" when guessed); fields card: Type, "In rupees" (foreign currency: `≈ ₹x` or "Add a rate in Settings › Forex rates"), When, Account/Card (tappable -> AlertDialog account picker with "Remember for {payee}" checkbox), Channel (if not OTHER), UPI id, Reference, Balance after, Limit left, Flagged (review reason); Note field with inline Save; "Messages (n)" list of `MessageView` source cards (SMS/Email/App/Screenshot/Manual/CSV/Statement) with "Not the same transaction: split it out" when > 1. Changing a category triggers `repository.setCategory` (learns merchant rule). EMI_LOAN prompts `LoanLinkPrompt`.
- **AddTransactionRoute** (`ui/add/AddTransactionScreen.kt:260`): top bar "Add transaction". Card "Fill from a screenshot" (photo picker `PickVisualMedia.ImageOnly`; ML Kit `TextRecognizerOptions.DEFAULT_OPTIONS` -> `FreeTextParser.draft`; states: scanning progress bar; "No amount found in that screenshot. Fill the details in yourself."; "Filled in from the screenshot. Check the details, then save."; error "Couldn't read that image: …"). Segmented Spent / Received / Transfer (or the three gap choices Payment / Transfer to my account / Money received when opened from a gap). Amount (₹ or currency prefix, decimal keyboard), Paid to / From (or From + To account pickers for Transfer; From restricted to bank accounts), Category card -> `CategorySheet`, Account picker dropdown ("None (cash or other)"), date + time pickers (`DatePickerDialog`, `TimeInput`), reference caption, Note, "Save transaction". After save: "Done" button; if saved merged with an existing row shows "This matched a transaction already recorded, so the two were merged."; EMI_LOAN debit with merchant >= 2 chars asks `LoanLinkPrompt`. Gap mode: amber card "Untracked change · {summary}", candidate rows "Looks like: … [Assign]" (assigns existing account-less rows), last choice per account remembered. Sources: `Source.MANUAL` or `Source.SCREENSHOT` (OCR text kept as source text), sender "Cash / other" if no account.
- **ReviewRoute** "Possible duplicates" (`ui/review/ReviewScreen.kt:95`) + info button: pinned explanatory text; cards per flagged pair (reason, both `TransactionRow`s, both source `MessageView`s collapsed to 4 lines, buttons Compare / Keep both / Merge). Empty `EmptyState(DoneAll,"All clear","Nothing needs a decision.")`.
- **CompareRoute** "Compare" (ReviewScreen.kt:174): table rows Amount/When/Merchant/Account/Channel/Reference/Balance after/Category/Reported by, differing values tinted `tertiary`; hint text; both messages; buttons "Keep both" / "Merge into one".
- Category sheets: **CategorySheet** (`components/CategorySheet.kt:44`) 4-column grid grouped by `CategoryGroup` with search; optionally "Your categories" + "New category" tile (`NewItemDialog`). **SubcategorySheet** + **NewItemDialog** (`ui/category/CategoryParts.kt`): name, 10-colour swatches (categories only; first 6 shown), 6-column icon grid (`IconLibrary.pickable`).
- **CategoryDetailRoute** (`ui/category/CategoryDetailScreen.kt:121`): month stepper (cannot go beyond current month), donut of sub-category shares (shades of the category colour), per-sub rows expandable to their transactions, "Add a sub-category" outlined button + list of the user's sub-categories with delete; empty text "Nothing spent on {category} in {month}.".

### 2.4 Accounts & cards (`ui/accounts/*`)
- **AccountsRoute** (`AccountsScreen.kt:287`): top bar "Accounts" with overflow "Restore missing accounts" (snackbar "Restored {n} accounts"); `PrimaryTabRow` Accounts / Cards / Deposits & loans with counts; FAB add -> **AddAccountSheet** (`AccountForms.kt:115`: Card/Account segmented, bank text + 10 quick chips (HDFC Bank, SBI, ICICI Bank, Axis Bank, Kotak Mahindra Bank, IDFC FIRST Bank, Yes Bank, Bank of Baroda, Punjab National Bank, AU Small Finance Bank), last 4 digits (error "Already in your list."), type chips, network chips (cards), optional balance/available limit hidden for debit cards). List follows global Book. Per tab: duplicate-merge cards ("Possible duplicate card/account" Merge / Not duplicates), balance summary card ("In your bank accounts", "Plus ₹x in deposits, PPF and loans"), deposit summary (Deposits / Loans), debit-card link suggestion ("Link this debit card?" Link / Not now), account cards (avatar, name, type · ••last4, linked-to, maturity line, credit-card bill block "Min ₹", "Unbilled", "Limit left … est.", right figure balance/limit left/billed, due label, gap dot), edit pencil, "Hidden (n)" section with "Show again". Empty states: "No accounts yet / No cards yet / No deposits or loans".
  - Account types come from `:shared` `AccountType` (liquid vs non-liquid; FD/RD/PPF/LOAN/CREDIT_CARD/DEBIT_CARD/PREPAID_CARD/SAVINGS etc.).
  - **EditSheet** (private, AccountsScreen.kt:630; also hosted from detail via `AccountEditHost`): nickname, Used for (Personal/Business), type chips, FD/RD maturity date + action (`MaturityFields`), card forex markup % (0-20, error otherwise; "Include GST: 3.5% + 18% = 4.13%."), network chips, debit-card account link list, balance/available limit field + "Remove the balance I set", colour swatches (8 colours + none), `BankDetailsSection`, merged accounts with Unmerge, "Merge into…", Hide / Delete (`DeleteAccountDialog` with "Also delete its {n} transactions") / Cancel / Save. Merge confirm `MergeDialog` ("Merge into {name}?").
  - **BankDetailsSection** (`BankDetailsSheet.kt`): collapsible "Statement unlock details": Customer ID (<=20 alnum), full account number (<=24), IFSC (<=11, uppercase), name/mobile/email (inherit profile as placeholder "Same as profile · …"), "Also save to profile" checkbox, lock caption "Encrypted on this phone. Used only to open your statements.", Save (retries locked statements).
- **AccountDetailRoute** (`AccountDetailScreen.kt:166`): title `nickname ?: bank ••last4`, edit icon. Optional `GapCard`. Header (avatar, type label, balance). Credit cards: `CardSummaryGrid` (Total outstanding with "Edit amounts" + "Edited" badge + source line "From statement · 2 Oct"; Total limit / Limit left (est.); Billed to pay / Unbilled / Outstanding variants; "Limit used %" bar, red at >= 80%) + `CardDueActions` ("Due in 3 days · Mark paid" / "Marked paid · Undo") + `CardAmountsSheet`. Range segmented 6 months / Year (with year stepper) / All time; Spent & Income figures; two-line smooth chart (tap to read a month); "Nothing moved in this period."; "See transactions".
- **CardAmountsSheet** (`CardAmountsSheet.kt:83`) "Edit amounts": total outstanding, billed, minimum due, due date picker, unbilled; each shows "Calculated ₹x" with "Reset to calculated"; Save disabled until changed & valid; "Reset all to calculated". Total follows billed+unbilled until typed. Values equal to calculated are not stored (`CardOverrideStore`).
- **GapCard** (`GapCard.kt:89`): amber card "Untracked change · {summary}", candidate rows ("Assign to {account}"), "Add transaction", "Ignore" (dismiss persisted in DataStore `untracked_gaps`).
- Card bill helpers: `CardBill.kt` (credit-card definition `isCreditCardRow`: CARD kind, not debit, type CREDIT_CARD or untyped with an available limit; `cardSourceLine`, `dueLabel` colours: red overdue, amber <= 5 days, muted otherwise), `CardDueActions.kt` (Mark paid only silences reminders and clears manual overrides; no ledger entry).

### 2.5 Analysis (`ui/analytics/*`)
`AnalyticsRoute` (`AnalyticsScreen.kt:86`): scrolling column (status-bar padded) with title "Analysis", `BookPeriodChips`, `Segmented` Spending / Cash flow / Forecast / Compare (segment index not persisted: "every visit to the tab opens on Spending"), cross-fade 220 ms.
- **Spending** (sections from `TabLayout.visible("analytics")`: `categories`, `monthly`, `merchants`, `budgets`, `when`): cross-filter pill "{category} ✕ cross-filter active". `CategoriesCard` (KPIs Spent/Income/Saved-or-Overspent/Per day; donut; legend top 6 + "All {n} categories"; tap = filter, long-press (haptic) = open category). `MonthlyCard` "Monthly spend · 12 months" stacked bars (Essentials / Lifestyle / Other, or selected category vs Rest) with avg line; tap bar opens ModalBottomSheet `MonthSheet` (month total, % above/below average, categories). `WhenCard` heat grid 7 weekdays x 8 three-hour slots (labels 6a,9a,12p,3p,6p,9p,12a,3a), tap cell for amount and top category, "Peak: Mon–Wed, 6p–9p, mostly Food". `MerchantsCard` top 6 with bars; tap -> ModalBottomSheet of up to 60 payments. `BudgetsCard` (`AnalyticsBudgets.kt`): bullet bars per category with limit tick, "today's pace" tick (current single month only), tones green/amber (>= alertPercent)/red (>= 100%).
- **Cash flow** (`AnalyticsSegments.kt:46`): Sankey (Salary / Other income / Refunds & interest -> Essentials / Lifestyle / Other / Invested / Saved) and "Income vs spend · savings rate" sparkline (needs >= 2 income months in last 12).
- **Forecast** (`:108`): only for the current calendar month, else a card with "Show {month}" pill; month-end fan chart (low 80% / high 120% of daily rate), "Likely ₹x · within/over budget"; cash balance for next 30 days (liquid accounts, recurring bills and incomes, card charges excluded until bill paid), "Shortfall of ₹x around {date}".
- **Compare** (`:187`): current vs previous period by category, diverging bars capped at +-50%.
- Maths (`AnalyticsViewModel.kt:130`): discretionary daily rate = average of last 3 prior months' non-fixed spend / days, blended with current month's pace (prior only if day < 7); FIXED categories = RENT, BILLS, EMI_LOAN, INSURANCE, SUBSCRIPTIONS, TAXES, EDUCATION. Budgets in a multi-month period scale limit by months spanned. `alertPercent` default 80 inside this VM (the setting default is 90 - see Open Questions).
- Global filter chips (`ui/ledger/FilterChips.kt`): Book pill sheet (Personal, Business, All books; "Applies to every tab.") and Period sheet (This week, current Month, Last month, This FY, Last FY, Last 12 months, Custom… -> `DateRangePicker` dialog "Choose dates" / Apply).

### 2.6 Portfolio (`ui/invest/*`)
- **InvestmentsRoute** (`InvestmentsScreen.kt:137`): top bar "Portfolio" + newspaper icon -> `news`; FAB "Add a holding" -> **HoldingSheet** (kind chips = `HoldingKind` (MUTUAL_FUND, STOCK, ETF, EPF, NPS, PPF, BOND, GOLD, FD, OTHER), name, current value (required), amount invested, units; hint "A newer SMS or statement will update the figures again." for non-manual; Delete on edit; manual holdings get id `manual:<uuid>`, source `MANUAL`). Empty `EmptyState(PieChart,"No investments yet", "EPF from EPFO SMS; funds and shares from CAS and broker statements. Or tap + to add one.")`. Sections from `TabLayout.visible("portfolio")`: `value` (`ValueCard` hero: PORTFOLIO VALUE, Invested/Gain/Return, "Gain and return cover holdings with a purchase cost."), `allocation` (donut + legend, tap slice filters holdings), `networth` (`NetWorthHeroCard` with range Segmented 1M/6M/1Y/3Y/All, sparkline, `WorthBreakdown` bar + folded pins, Assets/Liabilities, `CardLimits` folded list; note "Estimated from transactions until {date}; recorded after."), `holdings` (collapsible card per asset class: Equity, Retirement, Debt & FD, Gold, Cash, Others; rows with sparkline + % gain; tap holding edits, tap account opens Accounts tab), `maturity` (`MaturityCard`: loans card + "Maturity calendar · 12 months" for FD/RD/PPF with months-left bar, amber when <= 30 days).
- **PortfolioLoansCard**: collapsed "Loans · {n}" with `−₹total`, rows -> `loan/<id>`.
- **StatementsRoute** (`StatementsScreen.kt:167`): pinned "Import a statement (PDF, Excel or CSV)" button (`OpenDocument` with MIME list: pdf, ms-excel, xlsx, csv, plain) + progress bar; sections LOCKED (red), "Credit card statements", "Bank statements", "Holdings statements", "Other statements"; rows with status icon (PARSED check, LOCKED lock, else error), counts, "Unlock" button, delete; locked rows show `EmailHint` (subject + email text, 4 lines, expandable); empty "No statements yet."; **UnlockDialog** ("Unlock statement", PDF password field, hints) and **AddPasswordDialog** (label + password; defined but `addingPassword` is never set true in this file - appears unreachable); snackbar messages from `describe()` (Read x: n transactions and m holdings / needs a password / found nothing / protected spreadsheet "Save it without a password and import it again." / scanned image). Statements of kinds `KIND_OVERRIDE`, `KIND_PAYMENT` are hidden from the list.
- **StatementDetailRoute** (`StatementDetailScreen.kt:118`): header (logo, bank ••last4, kind · dated), summary card (credit-card: Total amount due, Minimum due, Pay by, credit limit, "Due in n days" if 0..10, available limit; bank: closing balance, Money in/out, opening; holdings: value, invested, holdings count, gain/loss), "{added} added from this statement · {matched} matched SMS or email already in DhanKosh", account-effect line, "Read again" (only when `canReread`), "{n} holdings updated. See them in Portfolio", holdings list, email section (collapsible, selectable text), transactions list.
- **NewsRoute** (`ui/news/NewsScreen.kt:222`): see 4.9.

### 2.7 Loans (`ui/loans/*`)
- **LoansRoute** (`LoansScreen.kt:199`): top bar "Loans" with Edit/Done toggle; FAB Add loan only in edit mode; empty `EmptyState(Payments,"No loans yet", …)`. `LoansHero` (Outstanding, EMIs a month, Loans count, Next EMI), duplicate cards (Merge / Not duplicates), `LoanCard`s (name, "Detected"/"Closed" tags, "EMI ₹x · next d MMM" or "No EMI found yet", outstanding, % repaid bar, "{paid} of {total} EMIs" or "about {n} EMIs left", merge/remove icons in edit mode), section "Detected EMIs".
- Dialogs/sheets: `RemoveLoanDialog` (loan account removal, or "Not a loan" for a detected EMI; optional "Also delete {n} payments"), merge confirm AlertDialog, `MergeIntoSheet`, `AddLoanSheet` (lender, last digits, EMI, EMI day 1-31, amount, rate 0-60% p.a., tenure 1-600 months, first-EMI date; with a tenure an EMI alone is enough, principal = EMI x tenure, rate 0), `TermsSheet` (loan amount, rate, tenure, first EMI, live "EMI by these terms" vs "EMI debited"; Clear), `LinkSheet` ("Link to a loan").
- **LoanDetailRoute** (`LoansScreen.kt:453`): `LoanHero` (Outstanding/Repaid; "Not stated by the bank yet" / "As stated by the bank" / "By the repayment schedule"; EMI, Next due, Due), `RepaymentCard` (paid/left bar, EMIs paid, total paid, remaining, principal/interest/total interest, borrowed, rate, payoff, "EMI on the 5th of every month · in Bills & subscriptions"), `DetectedCard` ("Track as loan" / "Link to a loan"), prompt card "Add loan details for payoff date", merged-loans card, `ScheduleCard` (next EMIs stacked bars principal/interest + collapsible table), `PaymentsCard` (up to 60, "prepayment" tag when > 120% of EMI). Not found: `EmptyState(Payments,"Loan not found")`.
- **LoanLinkPrompt** (`LoanLinkSheet.kt:103`): ModalBottomSheet "Which loan is this?" with loan list, "New loan" (creates `AccountType.LOAN` account named after the payee), "Not part of a loan". Auto-links silently if the payee is already linked. Persistence: DataStores `loan_links` (keys `tx`, `payee`, `manual`) and `loan_dismissals` (key `payees`).

### 2.8 Plan
- **BudgetsRoute** (`ui/budgets/BudgetsScreen.kt:110`): top bar "Budgets" (back only when `onBack != null`), InfoButton (3 paragraphs), ExtendedFAB "Budget". Overview card (month · days left, spent of total, bar), `BudgetCard` per category (percent, "₹x of ₹y" with paise, bar green/amber(>= alert%)/red, "Over by ₹x" or "₹x left · about ₹y a day", edit pencil, card tap -> transactions of that category for the current month). Empty `EmptyState(Savings,"No budgets yet", …)`. **BudgetDialog** (category via `CategorySheet` limited to spend categories not already budgeted, "Monthly limit" amount, "Applies every month", Delete/Cancel/Save). Excluded categories: SALARY, INCOME, REFUND, TRANSFER.
- **BillsRoute** "Bills & insurance" (`ui/plan/BillsScreen.kt:100`): FAB add -> **RecurringSheet** (`RecurringEditor.kt:71`: Expense/Income, name, amount, Every month/Every year, day 1-31, month picker for yearly, category via sheet, "Paid from/Paid into" account dropdown, hint "With an account set, you're warned 3 days before if its balance is too low."; edits detected items as prefill). Summary card (Due in 30 days / Every month), `BillsCalendar` (month grid with dots: Payment, EMI, Income, Insurance; red day number when short of funds; tap day for its list; tap a recurring row to edit, or open the loan if `loanKey != null`), empty `EmptyState(EventRepeat,"Nothing found yet","Repeats appear after two months of payments.")`.

### 2.9 More sub-screens (`ui/more/*`, `ui/settings/*`)
- **DataSourcesRoute** "Data sources" (`DataSourcesScreen.kt:144`): intro; amber warning row when app notifications are off/without access ("Turn on"); "History to read" Segmented 7d/30d/90d/180d/365d (default 90; change re-reads SMS (full) and email); cards: **Bank SMS** (status No permission/Paused/On, last read time + last result string, toggle `smsEnabled`, "Allow SMS access"/"Open app settings" + "Then App info › ⋮ › Allow restricted settings.", "Read new messages now"); **Email** (Not connected/Sign in again/Paused/Connected; last synced; toggle; "Connect email"; per-address Remove; "Add another email"; "Bank senders" editor dialog; "Disconnect email"/"Sign out" confirm dialog); **Payment-app notifications** (On/Needs access/Off; toggle sets `appNotificationsEnabled` and opens system notification-listener settings if access missing). `SendersDialog`: multiline list (one address or domain per line; "A domain matches every address at it."), Defaults / Cancel / Save. Google sign-in uses `StartIntentSenderForResult` consent flow; `AppLockGate.skipNextLock()` before every external launch.
- **EmailConnectDialog** (`settings/EmailConnect.kt:145`): AlertDialog steps ADDRESS (email + info button + hint text + optional "Advanced: Google sign-in (needs a Google Cloud OAuth client)" only when `onUseGoogle != null`) -> SIGN_IN (`AppPasswordGuide` per provider: Gmail, Outlook, Yahoo/AOL, iCloud, Zoho, generic; app-password field with Paste; "Sign in & send code") -> CODE (6-digit, Resend code; errors for WRONG/EXPIRED/TOO_MANY_ATTEMPTS/NONE) -> DONE ("{email} is verified. DhanKosh is fetching bank emails…"). Back/Cancel/Continue buttons per step; busy shows `LinearProgressIndicator`.
- **SecurityRoute** "Security & backup" (`SecurityScreen.kt:59`): App lock switch (disabled with "Set a screen lock on this phone first" unless `BiometricManager.canAuthenticate(BIOMETRIC_WEAK|DEVICE_CREDENTIAL) == SUCCESS`), Hide amounts switch, **Text size** (Segmented Small/Default/Large/XL with a live preview card), **Backup** (Export CSV via `CreateDocument("text/csv")` named `hisaab-<date>.csv`; Import CSV via `OpenDocument` MIME text/csv, text/comma-separated-values, text/plain), privacy note "Your data never leaves this phone. No servers, no tracking."; snackbars for export/import results.
- **AlertsRoute** "Notifications & alerts" (`AlertsScreen.kt:35`): banner "Notifications are off" + Allow (opens `ACTION_APP_NOTIFICATION_SETTINGS`), Transaction alerts switch, budget alert Segmented 80% / 90% / 95%, "You are also told when a budget is used up.", Card bill reminders switch ("5 days, 2 days and on the due date").
- **ActivityLogRoute** (`ActivityLogScreen.kt:142`): Today / This week KPI cards (SMS read, Emails read, Added, Statements), Sync card (Last SMS scan, Last email sync, Next scheduled sync from WorkManager `gmail-sync-periodic` + `nightly-sync`), source filter pills (SMS scan, Live SMS, Gmail, IMAP, Statements, Notifications), per-day entries (counts + time + duration; error shown "Failed: {class}"; notification skips "Skipped: {reason}"), delete-all AlertDialog "Clear log?". Empty `EmptyState(History,"No activity yet","Each sync is recorded here, on this phone only.")`.
- **RulesRoute** "Rules" (`RulesScreen.kt:131`): intro, empty card "No rules yet", cards "Your rules · n" and "Learned · n" (row: category icon, title, "Yours"/"Learned" tag, "{match label} → Category › Sub"), remove with snackbar Undo, ExtendedFAB "Add rule", **RuleEditor** ModalBottomSheet (match Exact/Contains segmented, text >= 2 chars (`MIN_KEY`), "Replaces the existing rule for {name}", category via `CategorySheet` incl. user categories, sub-category pills + New, "Also apply to past transactions (n)" live count, Delete/Cancel/Save). `RuleMatch` enum from `:shared` (labels used with `.label`).
- **TaxRoute** "Tax centre" (`TaxScreen.kt:336`): top bar What-if calculator + Share (disabled without income); `PeriodRow` pills FY {cur}, FY {prev}, Last 12 months; What-if banner (not saved); Summary card (new vs old regime `RegimeCard`s: Total tax, Gross income, Capital gains, Deductions, Taxable income, Tax before cess, Rebate 87A, Surcharge, Cess 4%, Effective rate; "Recommended: {regime}, saves ₹x"; tags Estimate/Estimated/What-if; InfoButton); Income card; Deductions card (old regime: 80C cap ₹1,50,000 with bar, 80D cap ₹25,000, NPS 80CCD(1B) cap ₹50,000, home loan 24(b) cap ₹2,00,000, HRA/other, employer NPS 80CCD(2)); Slab breakdown (collapsible per regime). **TaxEditSheet** (`TaxWhatIf.kt:92`): 13 optional fields (salary, interest, dividends, rent, other income, STCG 111A, LTCG 112A, 80C, 80D, NPS, home-loan interest, HRA/other, employer NPS), live preview of both totals, "Back to calculated", "Calculate". **TaxShareFlow** (`TaxShare.kt:60`): confirmation AlertDialog "Share with amounts?" when amounts are hidden; sheet with Image (HD PNG 1440 px wide) and PDF (A4, selectable text, via `android.graphics.pdf.PdfDocument`); shares through FileProvider `*.updates`, file `DhanKosh-tax-estimate-<fy>.png|pdf` in `cache/shared/`. Detection regexes in `TaxSource` (QUALIFIES_80C = elss|tax saver|ppf|sukanya|ssy|nsc|national savings; NPS; EPF share = growth x 12/15.67). Rules come from `TaxRules` in `:shared`.
- **LanguageRoute** (`LanguageScreen.kt:87`): row per `Language` (native name, English name, state Built in / Downloaded / Tap to download), selected highlighted; busy spinner; delete download icon; snackbars "Couldn't download {lang}. Check your connection." / "That language pack is damaged. Download it again."
- **SupportRoute** "Support DhanKosh" (`SupportScreen.kt:89`): amount chips ₹100 / ₹200 / ₹500 / Custom (digits, <= 6), "Pay with a UPI app" -> chooser for `upi://pay?pa=<vpa>&pn=DhanKosh&cu=INR[&am=n]`; "No UPI app found" toast. The UPI VPA is a hard-coded constant (`SupportConfig.UPI_ID`, `SupportScreen.kt:66`) - a Flutter port must move it to config; it is never displayed. `QrCode.kt` (244 lines) is an in-house QR generator (byte mode, ECC M, versions 1-20) that appears unused by the screens reviewed (see Open Questions); `SupportConfig.QR_ASSET = "support_qr.webp"` is not present in assets.
- **WhatsNewButton / sheet** (`WhatsNew.kt`): (i) icon -> ModalBottomSheet with release notes (GitHub release body cleaned, or `bundledChangelog()` entries 2.9.0, 2.7.0, 2.6.0, 2.4.0, 2.2.0) + two earlier versions.
- **SettingsRoute** "About & updates" (`settings/SettingsScreen.kt:44`): app name, version + WhatsNewButton, Updates card (Check for updates / Checking… / "You have the latest version." / error message; Available -> Install; Downloading progress bar), privacy note. Note: `checkUpdates` setting has a `setCheckUpdates` VM function but no switch in this screen (auto-check uses the stored value, default true).
- **CustomizeTabsRoute** "Customise" (`CustomizeTabsScreen.kt:118`): Appearance (Segmented System/Light/Dark, "Pure black in dark mode" switch, palette swatch rows grouped Classic / Hero / Cinema), Net worth card (switch per asset class, per liability kind, folded per-account switches; "Include all"), Tab sections card (Home / Analytics / Portfolio selector, per-section up/down arrows and switch, "Reset").
- **ForexRatesRoute** "Forex rates" (`ForexRatesScreen.kt:89`): "Your spends abroad" card (currency · count, "{n} need a rate" or "All counted"), explanatory text, list of "1 USD = ₹83.10" rows with date + delete, FAB -> **RateDialog** (currency chips of known + USD/EUR/GBP/AED/SGD, 3-letter code, `DatePickerDialog`, rate field). Save calls `ForexDao.upsert` then `recompute()`.
- **ProfileRoute** "Profile" (`ui/profile/ProfileScreen.kt:202`): top bar Support cup (only if `SupportConfig.available`); brand row; `ProfileHeader` (photo-tinted gradient hero computed from a 64 px thumbnail palette: 24 hue bins, `v<0.18/s<0.16/near-white` ignored, up to 3 bins >= 4% weight at least 30° apart; avatar ring; camera button; "Remove photo"); Personal card (name required, email, phone, occupation); "For locked statements" card (alternate name/mobile, DOB, PAN regex `[A-Z]{5}[0-9]{4}[A-Z]`, "Bank details" count); Save (enabled when changed, name present, PAN valid); lock footnote. `PhotoCropDialog` (`PhotoCrop.kt:140`): full-screen circle crop, pinch 1x-5x, double-tap zoom, rotate quarter turns, reset; saved as 512x512 JPEG q90 in `filesDir/profile-<ts>.jpg` (only one kept). `ProfileSetupSheet` ("Create your profile": photo, name, email, Continue/Later) exists but has no caller in the nav graph (first-run is now WelcomeScreen).
- **ParserBenchRoute** "Test the parser" (`ui/bench/ParserBenchScreen.kt:77`): dev tool - SMS/EMAIL chips, sender default `VM-HDFCBK`, message text, "Parse"; result card with all parsed fields + parse micros, or rejection reason ("Sender … is not a known bank…", "Rejected as {reason}…", "No transaction found…"). Unreachable (no navigate caller).
- **ForeignKeys**: `Info` canned texts (SMS, EMAIL, APP_PASSWORD, FETCH_HISTORY, PAYMENT_APPS, STATEMENT_PASSWORDS, STATEMENTS, INVESTMENTS, CARD_LINK, DUPLICATES, MANUAL_BALANCE, APP_LOCK) at `components/InfoButton.kt:46-100`; only EMAIL, DUPLICATES, CARD_LINK, MANUAL_BALANCE seen wired in screens read.

### 2.10 Widget (not a screen)
`widget/SpendWidget.kt`: Glance widget "DhanKosh spend" (3x2 cells target, min 180x110dp, resizable both ways, `updatePeriodMillis = 1_800_000`, home_screen) showing "Spent today" and "This month" = sum of `DEBIT` + `INVESTMENT` totals (`dao.total(listOf("DEBIT","INVESTMENT"), start, now)`), tapping opens the app. Refreshed on every ingest via `TransactionsChangedHub` -> `WidgetUpdater` -> `SpendWidget().updateAll`. It uses `Money.format` and therefore shows `₹••••` when amounts are hidden at process level (`AmountPrivacy` default true until settings load).

---

## 3. Settings

### 3.1 DataStore / preferences inventory
All under `settings/` unless noted. Stored on device only; `allowBackup=false`, `dataExtractionRules` exclude everything from cloud backup and device transfer (`res/xml/data_extraction_rules.xml`).

**`app_settings`** (`AppSettings.kt:95`, `AppSettingsStore`):

| Key | Type | Default | Meaning |
|---|---|---|---|
| `app_lock` | bool | false | Biometric/device-credential lock |
| `theme` | string `ThemeMode` | SYSTEM | SYSTEM / LIGHT / DARK |
| `theme_palette` | string `ThemePalette` | DHANKOSH | see 6.1 |
| `pure_black` | bool | false | OLED black in dark mode |
| `text_scale` | float | 1.0 | 0.9 / 1.0 / 1.1 / 1.2 (`TextSize`); `TextSize.of` snaps to nearest within 0.05 |
| `sms_enabled` | bool | true | Pause/resume live SMS ingest (receiver checks this) |
| `sms_cursor` | long | absent (=0) | Receive time of newest scanned SMS; `smsScanned` keeps max; `resetSmsCursor` removes |
| `last_sms_scan` | long? | - | Time of last scan |
| `last_sms_result` | string? | - | Summary "N SMS checked, M from banks, a new, b merged, c to review (x.xs)" |
| `sms_prompt_dismissed` | bool | false | "Not now" on Home SMS card |
| `app_notifications` | bool | **false** | Payment-app notification reading opt-in |
| `notifications_asked` | bool | false | POST_NOTIFICATIONS requested once |
| `budget_alert_percent` | int | 90 | Choices in UI 80/90/95 |
| `alerted_keys` | string set | empty | Alert dedupe keys; capped to last 300 on write (`addAlerted`) |
| `transaction_notifications` | bool | true | New-transaction + untracked-gap + balance notifications |
| `card_due_reminders` | bool | true | Card bill reminders |
| `hide_amounts` | bool | **true** | Amounts shown as `₹••••` |
| `check_updates` | bool | true | Daily GitHub check |
| `display_name` | string? | - | Profile name (also `profile.name`) |
| `profile_email`, `profile_phone`, `profile_occupation`, `profile_photo` | string? | - | Profile fields; photo = absolute path |
| `profile_prompt_dismissed` | bool | false | Legacy first-run prompt |
| `last_update_check` | long? | - | For once-a-day gating |

**`tab_layout`** (`TabLayout.kt`): `order_home`, `order_analytics`, `order_portfolio` (comma-separated keys), `hidden` (string set of `"tab:key"`), migration flags `home_v2_seeded`, `home_spent_added`, `home_networth_left`, `analytics_when_last`.
**`net_worth_prefs`** (`NetWorthPrefs.kt`): `excluded_classes` (AssetClass names), `excluded_liabilities` (`LOANS`, `CARD_DUES`), `excluded_accounts` (account ids as strings). Everything counts by default.
**`local_lists`** (`LocalLists.kt`): `worth` = JSON array of `{day, a, l}` (net-worth daily points, paise), one per day, trimmed to last 1100 entries.
**`view_filter`** (`ui/ledger/Ledger.kt:103`): `book` (ALL / PERSONAL / BUSINESS; default ALL). Period/month/custom range are NOT persisted (reset every launch).
**`language`** (`i18n/I18n.kt:62`): `language` code (en/hi/bn/te/mr/ta/gu/kn).
**`activity_log`** (`log/ActivityLog.kt:85`): `entries` JSON array, max 200.
**`card_due_reminders`** (`notify/CardDueReminders.kt:68`): `sent` ("cardId|dueEpochDay|STAGE"), `paid` ("cardId|dueEpochDay"), `snoozed` ("cardId|dueEpochDay|untilEpochDay"); entries pruned when due date > 120 days old.
**`untracked_gaps`** (`ui/accounts/GapTracker.kt:23`): `dismissed`, `notified`, `choices` (`"<accountId>=<GapChoice>"`). Watch window 240 days.
**`loan_links`**, **`loan_dismissals`**: see 2.7.
Legacy: `datastore/tax_overrides.preferences_pb` deleted on start (`TaxSource` init) - tax what-if figures are never persisted.
Plain `SharedPreferences`: `payee_accounts` (payee key -> accountId, loaded into `transactions.payeeAccounts`, written by `onPayeeAccountRemembered`), `maintenance` (one-time flags `reparse_v1`, `app_rows_v1`, `cardbill_v1`), `balance-updates` (per account key -> last notified epoch day). Email settings, mail accounts, statement passwords and identity live in `:email` stores (e.g. `GmailSettingsStore`: lookbackDays default 90, `LOOKBACK_CHOICES = 7,30,90,180,365`, senders list, enabled, needsReauth, `connection` GOOGLE/IMAP) - Keystore-sealed, covered elsewhere.
Files: `filesDir/lang/<code>.json` (packs), `filesDir/profile-*.jpg`, `cacheDir/updates/*.apk`, `cacheDir/shared/*`.

### 3.2 TabLayout customisable sections (`TabLayouts`, `TabLayout.kt:18`)

Default order and labels:
- **home**: `spent` "Spent this month", `cards` "Credit card dues", `cashflow` "Cash flow", `upcoming` "Upcoming", `insights` "Insights", `categories` "Spend by category", `recent` "Recent transactions", `budgets` "Budgets". Hidden by default: `{"budgets"}` (`HOME_HIDDEN_BY_DEFAULT`, seeded once by `seedHomeOnce` and by `reset`).
- **analytics** (labelled "Analytics" in Customise tab selector, "Analysis" elsewhere): `categories` "Spend by category", `monthly` "Monthly spend", `merchants` "Top merchants", `budgets` "Budgets", `when` "When you spend". Applies only to the Spending segment.
- **portfolio**: `value` "Portfolio value", `allocation` "Asset allocation", `networth` "Net worth", `holdings` "Holdings", `maturity` "Maturity calendar".
Semantics: `order(tab)` = saved order filtered to known keys + unknown keys appended; `visible(tab)` removes `"tab:key"` in `hidden`; `move(by=+-1)` swaps neighbours; `reset` clears order and un-hides (but re-hides `budgets` on home); `apply(tab, shown)` = preset (shown first in order, everything else hidden).
Home presets (`HOME_PRESETS`, `TabLayout.kt:47`; the store's `apply()` exists but no UI wired to it in the screens read):
- Minimal: spent, cashflow, upcoming
- Spender: spent, cashflow, budgets, categories, upcoming, recent
- Investor: spent, insights, upcoming
- Business: cashflow, upcoming, insights, recent
- Everything: spent, cards, cashflow, upcoming, insights, categories, recent, budgets
Migrations in `seedHomeOnce` (run from `HomeViewModel.init`): "when" moved to end of analytics order; "spent" inserted after "networth"; "networth" removed from home and "spent" put first; first seed removes saved home order and hides budgets.

---

## 4. Workers, receivers, services, background features

### 4.1 Application start (`HisaabApplication.kt:34`)
`appScope` (SupervisorJob + Dispatchers.Default, `di/AppModule.kt:35`) runs, off main thread: `languages.restore()`; `SmsScanScheduler.scanIfPermitted`; `AlertsWorker.schedule`; `cardDueReminders.check()`; `NightlySync.schedule`; `accounts.closeMatured(today IST epochDay)` (FD/RD paid out); `updater.checkIfDue()`; `GmailScheduler.schedulePeriodic` if email enabled. Separate coroutines: `reparseOnce()` (flag `reparse_v1`, re-parses stored messages after the account-attribution fix), `reattributeAppRows` (`app_rows_v1`), `reclassifyCardBills` (`cardbill_v1`), `holdings.dedupe()` (every start), and a collector that keeps `transactions.phoneLast4s` = last 4 digits of the user's own numbers (profile phone, identity phone/altPhone, digits >= 10) so own mobile numbers never become accounts. WorkManager is initialised manually with `HiltWorkerFactory` (manifest removes the default initializer).

### 4.2 `SmsReceiver` (`sms/SmsReceiver.kt`)
Manifest: exported, `android:permission="android.permission.BROADCAST_SMS"`, intent-filter priority 999, action `android.provider.Telephony.SMS_RECEIVED`. Behaviour: `goAsync()`; multi-part SMS joined per `originatingAddress`; keep only senders where `registry.accepts(sender) || InvestmentParser.accepts(sender)` (sender-header filter happens before any body is read); abort if `smsEnabled == false`. Per sender: EPFO/NPS-style investment senders -> NPS contribution via `NpsContributions.contribute` and `repository.ingest`, else `holdings.record(...)` (balance); otherwise `registry.loanStatus` -> `repository.applyLoanStatus`, `registry.cardDue` -> `CardDueRecorder.apply(..,"SMS")`, then `registry.parse(body, sender, now, Source.SMS)` -> `repository.ingest(IncomingMessage(tx, messageId, body))`. `messageId = SmsIds.of(sender, sentAt, body)` = `"sms:" + first 16 bytes of SHA-256("<SENDER_UPPER>|<sentAtMs>|<body>")` as hex (`SmsInboxSource.kt:55`) so live and scan paths dedupe. `NewTransactionNotifier.onIngested(outcome,"SMS",id)` posts the user notification. Records one `SMS_LIVE` activity entry. Needs `READ_SMS` + `RECEIVE_SMS`.

### 4.3 SMS scan (`sms/OptimizedSmsReaderWorker.kt`, `SmsScanScheduler.kt`, `SmsInboxSource.kt`)
- Unique work `sms-scan`. `scan(full=false)` uses `ExistingWorkPolicy.KEEP` (full uses REPLACE). `scanRecent(days=14)` = REPLACE with `KEY_RECENT_DAYS`. `scanIfPermitted` checks READ_SMS first.
- Window: full = now - `lookbackDays` (default 90) from 0 cursor; recent = `min(cursor, now - days)`; default = cursor. Cursor never moves backwards.
- Reads `Telephony.Sms.Inbox` where `date > since`, ordered ASC; sender-only `accept` predicate before copying body; batches of **500** (`BATCH_SIZE`); parsing parallelised on `Dispatchers.Default` with slices of `max(size/parallelism, 50)` (parallelism = CPUs coerced 2..8); one Room transaction per batch via `repository.ingestBatch`.
- Per batch additionally handles investment senders, loan statuses and card dues as in the receiver; reports progress `scanned`, `found`; writes `smsScanned(cursor, summary)`; activity entry; calls `notifier.onTransactionsChanged()` if anything inserted/merged/flagged. Missing permission -> `Result.failure(error="permission")` + activity entry.
- Nightly: `NightlySyncWorker` (`sync/NightlySync.kt`) = `scanIfPermitted`; unique periodic `nightly-sync`, 1 day, initial delay to the next **02:30 local**, constraints `requiresBatteryNotLow`, policy KEEP. Email has its own `GmailScheduler` (periodic `gmail-sync-periodic`, 1 day, policy UPDATE; one-off `gmail-sync-now`).

### 4.4 `PaymentNotificationListener` (`notify/PaymentNotificationListener.kt`)
`NotificationListenerService` bound by `BIND_NOTIFICATION_LISTENER_SERVICE`; user must grant "notification access" in system settings (`hasAccess` = package in `getEnabledListenerPackages`); additionally the `app_notifications` setting must be on. Flow in `onNotificationPosted`:
1. `PAYMENT_APPS[sbn.packageName]` else return (every other app ignored, never read).
2. Drop `FLAG_GROUP_SUMMARY` and `FLAG_ONGOING_EVENT`.
3. Concatenate (trim, distinct) `EXTRA_TITLE`, `EXTRA_TITLE_BIG`, `EXTRA_TEXT`, `EXTRA_BIG_TEXT`, `EXTRA_SUB_TEXT`, `EXTRA_INFO_TEXT`, `EXTRA_SUMMARY_TEXT`, `EXTRA_TEXT_LINES`.
4. WhatsApp (`com.whatsapp`, `com.whatsapp.w4b`) only if `isChatPayment`: category != `CATEGORY_MESSAGE`, no `EXTRA_MESSAGES`, channel id does not contain "chat", and some line matches `^\s*(you (have )?(paid|sent|received)|payment (of|to|from|successful|received|sent|completed)|(₹|rs.?|inr) ?[\d,]+(.\d{1,2})? (paid|sent|received))` (case-insensitive). Conversations are never read.
5. If setting off -> activity note "app notifications are off in settings" (read=1, relevant=0).
6. `FreeTextParser().readNotification(appName, parts, postTime)` -> tx or skip reason; id = `"app:" + SHA256-16("<pkg>|<sbn.key>|<raw>")`; `repository.ingest(IncomingMessage(tx, id, raw, sourceName="APP"))`; activity entry; `onTransactionsChanged`; `NewTransactionNotifier.onIngested(..,"APP",id)`. Notification text is never logged, only a generic reason.

Package -> display name (`PAYMENT_APPS`, line 98):
`com.google.android.apps.nbu.paisa.user` Google Pay; `com.phonepe.app` PhonePe; `net.one97.paytm` Paytm; `in.org.npci.upiapp` BHIM; `com.dreamplug.androidapp` CRED; `in.amazon.mShop.android.shopping` Amazon Pay; `com.mobikwik_new` MobiKwik; `com.naviapp` Navi; `money.super.payments` super.money; `com.freecharge.android` Freecharge; `com.sbi.upi` BHIM SBI Pay; `com.sbi.lotusintouch` YONO SBI; `com.snapwork.hdfc` HDFC Bank; `com.csam.icici.bank.imobile` ICICI iMobile; `com.axis.mobile` Axis Mobile; `com.msf.kbank.mobile` Kotak Bank; `com.samsung.android.spay` Samsung Wallet; `com.samsung.android.spaymini` Samsung Pay Mini; `com.whatsapp` and `com.whatsapp.w4b` WhatsApp Pay.

Parser-side rejection rules (`parser-core/.../FreeTextParser.kt:83-127, 190-225`), reasons logged: min length 8 ("too short"); `OTP` regex `otp|one-time pass|verification code|cvv|upi pin|pin` ("otp or security text"); `FAILED` regex fail*/declined/unsuccessful/not successful/couldn't/cancel*led/rejected/reversed/pending/processing/in progress/refund initiated|in progress/will be refunded|credited/timed out/on hold/bank server/try again ("failed or pending payment"); `REMINDER` regex requested/payment request/collect request/reminder/due/overdue/expire*/valid till/bill generated/scheduled/upcoming/will be debited|deducted|charged/set up autopay ("request, reminder or due notice"); per-sentence drop of `PROMO` (cashback, reward, scratch, offer, coupon, voucher, won, win, claim, referral, earn, bonus, discount, get up to, lucky, spin, "n points", "n%", "n off", "flat ₹"), `UI_TEXT` (view/tap/know/check/learn/download/track/explore/open/see/click/share/rate/swipe/repay/invite/enjoy/thank/split/add money) and `CALL_TO_PAY` ("pay now", "recharge now", "pay ₹n"...) ("offer or promotion" if nothing left); requires a SIGNAL (credit: sent/paid you, received, credited, refund processed, money/payment received; debit: paid, sent, debited, spent, transferred, deducted, charged, purchased, payment...successful/done/completed/made/sent, recharge/bill ... successful) else "no payment wording"; amount via `AmountExtractor` > 0 else "no amount"; own transfers / card-bill pay labelled "own transfer or card bill". Confidence 0.55 for notification-read transactions. UPI app list in parser: PhonePe, Google Pay, Paytm, BHIM, BHIM SBI Pay, CRED, super.money, Navi, WhatsApp Pay, Amazon Pay, MobiKwik. Balance tails ("Avl bal …") are stripped so they are not read as the amount.

### 4.5 Notifications (channels, ids, actions)

| Notification | Channel (importance) | Id | Trigger / content | Actions |
|---|---|---|---|---|
| New transaction | `new_transactions` "New transactions" (LOW) | 10000 + txId | `NewTransactionNotifier.onIngested` only for INSERTED (not merged/dupe/rescan), setting `transaction_notifications`, skips TRANSFER type/category; title "₹x at {who}" or "₹x received from {who}"; text "Category · ••last4 · expand to change"; `setOnlyAlertOnce`, auto-cancel, `CATEGORY_STATUS`; tap -> `hisaab://transaction/<id>` | Up to 3 category buttons (`CategoryActionReceiver`, not exported): the user's most used categories for that type in last 90 days, then defaults (credit: SALARY, REFUND, INCOME, TRANSFER; debit: FOOD, GROCERIES, SHOPPING, TRANSPORT, BILLS), never the current one nor OTHER. Tap saves via `repository.setCategory` (learns merchant) and replaces with "Saved as {category}" for 4 s. |
| Balance updated | same channel | 9000 | `BalanceNotifications.onBalancesUpdated`; at most once per account per day (`BalanceReconciler.due`, prefs `balance-updates`); one notification merged (InboxStyle when several): "{what} updated · ₹x not explained · transactions may be missing" | tap opens app |
| Budget alert | `budgets_bills` "Budgets & bills" (DEFAULT) | key.hashCode | `AlertsChecker.checkBudgets` for current month: for levels `{alertPercent, 100}` highest reached; key `budget:<CAT>:<yyyy-MM>:<level>` sent once | tap -> `hisaab://budgets` |
| Upcoming payment / low balance | same | hash | `checkUpcoming`: recurring (detected + manual) debits due in 0..3 days whose paying bank account (resolving merged + linked debit-card account) has a known balance < amount; key `bill:<name>:<nextDue>` | -> `hisaab://bills` |
| Insurance renewal | same | hash | non-monthly policies due in 0..7 days, key `renewal:<insurer>:<nextDue>` | -> `hisaab://bills` |
| Untracked change | same | hash | `checkGaps`, requires `transaction_notifications`; max 3 per run, gaps whose `toTime` within last 14 days (`GAP_ALERT_DAYS`), once per gap (`markNotified`) | -> `hisaab://account/<id>` |
| Card bill reminder | `budgets_bills` | 30000 + cardId*3 | `CardDueReminderChecker.check` (see below) | "Mark paid" (id+1) and "Remind tomorrow" (id+2) via `CardDueActionReceiver` (actions `com.hisaab.app.CARD_DUE_PAID` / `CARD_DUE_SNOOZE`) ; tap -> `hisaab://account/<cardId>` |
| Statement needs password | `statements` "Statements" (DEFAULT) | 4000 + statementId | `StatementNotifications.onLocked`; shows issuer + file name only, never figures | tap -> `hisaab://statements?unlock=<id>` |
All notification posting first checks `NotificationManagerCompat.areNotificationsEnabled()` and swallows `SecurityException`. Small icon `ic_stat_statement`. Strings go through `t()`.

Card-due reminder staging (`CardDueReminderPlan.next`, `CardDueReminders.kt:49`): stages `DAYS_5(5)`, `DAYS_2(2)`, `DUE_DAY(0)`, `OVERDUE(-1)`; only the most urgent reached stage (`days <= offset`, smallest offset) and never a repeat; no reminders once > 7 days overdue (`OVERDUE_WINDOW`); none if paid or snoozed until a later day; marking a stage sent also marks all earlier stages. Source of truth for amount/due: `CardDues.position(statements, balance, cardFlow since window, today)`; billed must be > 0 and due date known else the notification is cancelled. Checks run daily (AlertsWorker), at app start, and are cheap to re-run.

### 4.6 Scheduled workers
- `AlertsWorker` (`notify/Alerts.kt:198`, HiltWorker): unique periodic `daily-alerts`, 1 day, KEEP. Runs `cardDues.check()`, `alerts.checkUpcoming()`, `alerts.checkBudgets()`, `alerts.checkGaps()`, each in `runCatching`.
- `TransactionsChangedHub` (implements `TransactionsChangedNotifier`, Alerts.kt:186): after any change -> widget update + `checkBudgets()` (guarded by a `Mutex`).
- `NightlySyncWorker`, `OptimizedSmsReaderWorker`: above. `GmailSyncWorker`: in `:email`.

### 4.7 App lock (`MainActivity.kt`, `security/AppLockGate.kt`)
State: `lockEnabled` (null until settings load), `unlocked`. Locks when the activity stops (`onStop`) unless `isChangingConfigurations` or `AppLockGate.consumeSkip()` returns true. Callers that leave the app for system UIs call `AppLockGate.skipNextLock()` first: file pickers (CSV import/export, statement import, screenshot picker), Google consent, opening provider app-password pages, notification-listener settings, notification settings, App settings, APK installer (`SettingsViewModel.installUpdate`). The permission dialog does not stop the activity so no skip is used there. Turning the lock ON inside the app sets `unlocked = true` for the session so the user is not locked out. Authenticators: `BIOMETRIC_WEAK | DEVICE_CREDENTIAL`; no PIN of its own.

### 4.8 Update checker (`update/Updater.kt`)
`GET https://api.github.com/repos/DhyanendraSinghSikarwar/hisaab_apk/releases/latest` (Accept `application/vnd.github+json`; connect 15 s, read 20 s; no payload). First asset ending `.apk`; `tag_name` with `v` stripped is the version; SHA-256 taken from a `sha256:<64 hex>` line in the release body; remaining body is the notes. `isNewer` compares numeric parts split on `.`/`-` (non-numeric = 0). `checkIfDue()` runs at app start if `checkUpdates` and last check >= 24 h. States: Idle, Checking, UpToDate, Available(release), Downloading(progress), Failed(message). Download to `cacheDir/updates/DhanKosh-<version>.apk` following up to 5 manual redirects, 64 KB buffer; verifies checksum if present (deletes file and fails with "The download didn't match its checksum, so it wasn't installed. Try again."), then `ACTION_VIEW` with `application/vnd.android.package-archive` through FileProvider `<pkg>.updates`. Needs `REQUEST_INSTALL_PACKAGES`. Android verifies the signature. A Flutter port must replace this (store updates) or keep the same GitHub API design.

### 4.9 CSV import/export (`csv/CsvTransfer.kt`)
Header (exact order): `date, amount, currency, type, bank, account_last4, account_kind, merchant, category, channel, reference, balance, upi_id, note, hash`. Export: `date` = `Instant.toString()` (ISO-8601 UTC), amounts as plain decimal with 2 places (`BigDecimal.valueOf(minor, 2)`), enum columns by `name`, writes via OpenCSV `CSVWriter` (no quotes forced); note is exported but NOT read back on import (`ParsedTransaction` has no note param in the importer). Import reads by header name (case-insensitive, trimmed) so reordered columns work; requires date, amount, type; amount `replace(",","")`, `movePointRight(2).longValueExact()`; date `Instant.parse`; type enum upper-cased; defaults: currency INR, bank "Imported", kind ACCOUNT, channel OTHER, category OTHER; hash from `hash` column else `TransactionHasher.hash(amount, type, last4, localDate, ref)`; `source = Source.SMS`, `sender = "csv"`, `confidence = 1`; malformed rows increment `badLines`. `repository.importTransactions` reports inserted/skipped (duplicates skipped). Result snackbars: "Exported {n} transactions to {file}", "Imported {n}, skipped {m} already present[, k unreadable lines]", "Import failed: {error}". Unit test: `app/src/test/.../CsvTransferTest.kt`.

### 4.10 Screenshot OCR
`AddTransactionViewModel.scan` (`ui/add/AddTransactionScreen.kt:184`): `InputImage.fromFilePath` -> ML Kit `TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)` (Latin model bundled in APK, no download) -> `FreeTextParser.draft(text, now)`. Account guess: account whose `last4` endsWith draft last4 (and same bank if known). Type never set to INVESTMENT from OCR. No network. Manifest strips Google DataTransport CCT backend so ML Kit usage counters can't be uploaded (`AndroidManifest.xml:97-103`). Flutter equivalent would be `google_mlkit_text_recognition` (Latin) feeding the shared free-text parser.

### 4.11 Language packs (`i18n/I18n.kt`, `lang/`)
- English text is the key: `t(text, vararg "k" to v)` looks up `I18n.strings[text] ?: text` then replaces `{k}` placeholders; `I18n.strings` is Compose state so changing language redraws all screens.
- Languages: en (built in), hi, bn, te, mr, ta, gu, kn (`Language` enum with native names).
- Download URL: `https://raw.githubusercontent.com/DhyanendraSinghSikarwar/hisaab_apk/main/lang/<code>.json` (connect 10 s, read 20 s), validated non-empty, written via `.json.tmp` + rename to `filesDir/lang/<code>.json`; `use()` stores the code in DataStore `language`; `delete()` removes file and falls back to English; `restore()` at start falls back to English on error.
- Pack format `{ "version": 1, "code": "hi", "strings": { "<English key>": "<translation>" } }`; only blank values are skipped. `lang/keys.json` is a flat JSON **array of 1455 unique English source strings** (the canonical key list); each of `hi bn gu kn mr ta te .json` has `strings` with all 1455 keys. `lang/tmp/` holds working shards (`bn.1..4.json`, `delta.*.json`).
- Not everything is wrapped: some screens use raw English (e.g. ParserBench, `Periods.dayHeader` returns English "Today"/"Yesterday" (callers wrap in `t()` sometimes), tax `TaxItem` labels are wrapped at render).

### 4.12 News (`ui/news/NewsScreen.kt`)
Four tabs (`NewsFeed`: Latest, Markets, Business, Stocks) merging RSS from Business Standard, Economic Times, Mint, Moneycontrol (exact URLs at lines 99-120), fetched in parallel (UA "Mozilla/5.0 (Android) DhanKosh", 10 s/15 s timeouts), dedupe by link then normalised title, newest first, max 200, in-memory cache 10 minutes, pull-to-refresh, skeleton loading, error state "Couldn't load headlines / Try again", tap opens the browser. XML parsed with `XmlPullParser`; dates `RFC_1123`.

### 4.13 Other background-ish pieces
- `ActivityLog` (`log/ActivityLog.kt`): max 200 entries; live SMS and notification entries within 30 min of the previous same-source entry are coalesced (`runs`); stores counts/class names only, never message text, senders or amounts.
- `PlanSource`, `LoanSource`, `NetWorthSource`, `LedgerSource`: `@Singleton` shared flows (cached while subscribed for 10 s) used by several screens; `NetWorthSource` records today's all-books net worth into `local_lists` whenever assets/liabilities change, and estimates history before the first recorded day (month-ends for 36 months + weekly for 26 weeks) from transactions (`WorthHistory.estimate`, `Ledger`/`NetWorth.kt:289`).
- Gap detection (`UntrackedGapFinder` in `:shared`) feeds `GapTracker`, `AlertsChecker.checkGaps`, `GapCard`, gap dots in Accounts.

---

## 5. Permissions and why (`AndroidManifest.xml`)

| Permission | Why / where |
|---|---|
| `READ_SMS` | Inbox scan (`TelephonySmsInboxSource`); requested from Home card / Data sources via `rememberSmsPermission` |
| `RECEIVE_SMS` | Live `SmsReceiver`; requested together with READ_SMS |
| `INTERNET`, `ACCESS_NETWORK_STATE` | Email (IMAP/Gmail API), update check, language packs, news RSS |
| `USE_BIOMETRIC` | App lock |
| `POST_NOTIFICATIONS` | Asked once from Home (API 33+); statement/budget/bill/transaction alerts |
| `REQUEST_INSTALL_PACKAGES` | Hand the downloaded APK to the installer after the user taps Install |
| (no permission, special access) Notification listener | `PaymentNotificationListener` bound with `BIND_NOTIFICATION_LISTENER_SERVICE`; user enables it in system settings (`ACTION_NOTIFICATION_LISTENER_SETTINGS`); sideloaded apps may need "Allow restricted settings" |
| `uses-feature telephony` required=false | App installs on devices without telephony |
Other manifest facts: `allowBackup=false`, `fullBackupContent=false`, `supportsRtl=true`, `windowSoftInputMode=adjustResize`; `network_security_config`: `cleartextTrafficPermitted=false`, system CAs only; `FileProvider` authority `${applicationId}.updates` (not exported, grants URI permissions); exported components: MainActivity, SmsReceiver (guarded by BROADCAST_SMS), PaymentNotificationListener (guarded by BIND permission), SpendWidgetReceiver; non-exported receivers `CategoryActionReceiver`, `CardDueActionReceiver`. No camera, contacts, location, storage permissions (pickers used instead).

---

## 6. Cross-cutting

### 6.1 Theme and branding
- Always DhanKosh's own colours; Material You dynamic colour deliberately not used (`ui/theme/Theme.kt:68`). Dark mode = `ThemeMode` (System follows `isSystemInDarkTheme`). `PaletteSpec` (`ui/theme/Palettes.kt:60`) per palette: light + dark `ColorScheme`, `heroLight/heroDark` (3-colour gradients), `glows` (3 backdrop glow colours), `bottomLight/bottomDark`, `glowStrength`. Cards sit on pure white in light themes, flat with 1dp hairline; `surfaceTint` transparent.
- 22 palettes (`ThemePalette`, `AppSettings.kt:21`), groups **Classic**: DHANKOSH (default), FOLD, CLASSIC, EMERALD, GRAPHITE, INDIGO ("Indigo Night"), SAFFRON, OCEAN, ROSE_QUARTZ, LAVENDER_BLOOM; **Hero**: MIDNIGHT ("Midnight Knight"), ARC_RED, STAR_SHIELD, THUNDER, GAMMA, VIBRANIUM; **Cinema**: IRON_THRONE, MIDDLE_REALM, NITRO, NEO_MATRIX, INTERSTELLAR_DUST, SPICE_DUNE. (Docs elsewhere list 8 + two groups; the enum has 10 + 6 + 6.)

  Primary (light / dark) and background (light / dark), extracted from `Palettes.kt` (full token sets - container/secondary/tertiary/outline/surface levels/hero/glow - live in that file and should be ported verbatim):

  | Palette | primary L | primary D | bg L | bg D |
  |---|---|---|---|---|
  | DHANKOSH | 2873BE | 5FB3E8 | F6F8FA | 0B1418 |
  | FOLD | 111113 | FFFFFF | FFFFFF | 000000 |
  | CLASSIC | 2F5BEA | 7C9BFF | F7F7F5 | 0E0F12 |
  | EMERALD | 0F7A55 | 5FD3A2 | F4F8F5 | 0B110E |
  | GRAPHITE | 3D5A80 | 9DB6D8 | F5F6F7 | 0F1113 |
  | INDIGO | 4F46E5 | A5A1FF | F6F5FB | 0D0C17 |
  | SAFFRON | B45309 | F5B26B | FAF6F0 | 13100D |
  | OCEAN | 0E7490 | 5ED0E6 | F3F8F9 | 0A1215 |
  | ROSE_QUARTZ | A8466A | F4A3BF | FBF6F6 | 140C12 |
  | LAVENDER_BLOOM | 6D4FC2 | CDB8FF | F8F6FB | 120C17 |
  | MIDNIGHT | 26292E | F5C518 | F2F3F5 | 000000 |
  | ARC_RED | B3122E | FF8A98 | FAF6F5 | 120B0C |
  | STAR_SHIELD | 1F3A93 | A9BCF5 | F5F6F8 | 0B0E16 |
  | THUNDER | 2C5C80 | 5CE1FF | F3F6F8 | 0B1016 |
  | GAMMA | 1F6B3A | 7FD99A | F4F7F3 | 0B100C |
  | VIBRANIUM | 5B2DB3 | BFA6FF | F5F5F8 | 050507 |
  | IRON_THRONE | 3E5A73 | A9C6E0 | F3F5F7 | 0E1013 |
  | MIDDLE_REALM | 5B6B2E | C2D08A | F8F4EA | 0D110D |
  | NITRO | 1F5FD6 | 4DA3FF | F4F5F7 | 08090B |
  | NEO_MATRIX | 1C6B3A | 5CE08A | F3F6F4 | 030504 |
  | INTERSTELLAR_DUST | 22355E | E8C48A | F7F5F1 | 070A14 |
  | SPICE_DUNE | A34A12 | F5A26A | FAF5EC | 120E0B |

  DHANKOSH full token example: light primary 2873BE / container D8E9F8 / secondary 2E8A99 / tertiary 2FAE6E / ink 121A22 / muted 5A6672 / outline 97A2AD / outlineVariant E1E6EC; dark primary 5FB3E8 / secondary 6CC5C9 / tertiary 5FD39A / ink E6EEF2 / container 121C21; hero light [2E9E72, 2E8AA0, 2F6CCF], dark [1E7A57, 1F6878, 23509E]; glows [4DB6A6, 3B78DB, 66D693]. Pure black (`pureBlack()`): bg/surface/lowest = 000000, low/container 0B0B0D, high 141417, highest 1B1B1F, bright 222226, backdrop bottom black.
- Semantic colours (`MoneyColors`, `Hx`, `Theme.kt:138-161`): credit/pos light 13895A dark 3CCB8B; debit/neg light D2453B dark FF7B70; warn light C98A0B dark F2B84B; transfer light 7A808A dark 8B919C; accent = `colorScheme.primary`; accentSoft = accent at 10% (light) / 14% (dark) alpha; error scheme light D2453B (container FBE0DD) / dark FF7B70 (container 5C1A15). Chart palette `Hx.palette` = 2F5BEA, E07A2E, 16A394, C2418B, 7A5AE0, C9A227, 3E9BD6, 8C8F96. The accent never carries meaning (money in green, out red, warnings amber on every palette).
- Category colours/icons (`Theme.kt:164-224`): FOOD E8704A, GROCERIES 7CB342, TRANSPORT 3F88C5, FUEL 8D6E63, SHOPPING D64E8C, BILLS 5C6BC0, ENTERTAINMENT AB47BC, TRAVEL 26A69A, HEALTH EF5350, EDUCATION 42A5F5, RENT 795548, INSURANCE 78909C, EMI_LOAN FFA726, INVESTMENT 2E7D32, CASH 9E9D24, SUBSCRIPTIONS 7E57C2, PERSONAL_CARE EC407A, HOUSEHOLD A1887F, GIFTS E53935, DONATIONS FF7043, TAXES 546E7A, FEES 8E7CC3, SALARY 00897B, INCOME 43A047, REFUND 29B6F6, TRANSFER 90A4AE, OTHER 9E9E9E (27 categories). Picker groups (`CategoryGroup`): Food & drink; Shopping & lifestyle; Transport & travel; Home & bills; Health & education; Money; Income; Other.
- Typography: Material3 default with **tabular figures** (`fontFeatureSettings="tnum"`) on every style; display-small/headline/title weights SemiBold. Shapes: 8/12/16/22/32 dp.
- Backdrop (`Theme/Backdrop.kt:28`): vertical wash base -> bottom colour from 35% height + three radial glows at (5%,30%), (100%,55%), (20%,98%) with alphas 0.16 / 0.13 / 0.09 x `k` where `k = (dark ? 1 : 0.62) x glowStrength`.
- Text scale: `appFontScale(system, factor) = system*factor` but when `factor > 1` capped at `max(1.3, system)`; shrinking always applies.
- Reduce motion: `Settings.Global.ANIMATOR_DURATION_SCALE == 0` (read once) disables tab pill spring/icon bounce etc. (`LocalReduceMotion`).
- Branding assets: `artha_mark.png` (shield mark), `ic_launcher_mark.png` (splash), adaptive icon `ic_launcher_foreground.xml` / `ic_launcher_background.xml`, `ic_stat_statement.xml` (notification small icon), `values/themes.xml` colors `brand #1B6E4F`, `window_light #F6FAF7`, `window_dark #101412`. Avatar fallback = initials on green gradient (2E7D32 -> 00897B) with gold ring (FFB300 @ 80% / C9A227 @ 80%). Gold `BackdropColors.gold = C9A227`.
- Logos: **140 `.webp` files** in `assets/logos/` (+ no other assets). Keys: 1mg acko adobe airbnb airindia airtel ajio amazon amazonpay amex anthropic apollo apple au audible axis bandhan bhim bigbasket blinkit bob boi booking bookmyshow box8 bpcl burgerking canara canva ccd citi cleartrip coursera cred croma decathlon delhivery digit dmart dominos easemytrip eatsure equitas federal flipkart freshtohome gaana github goibibo google gpay groww haldirams hdfc hdfclife healthifyme hotstar hpcl hsbc icici idbi idfc ikea indianbank indigo indmoney indusind instamart iob iocl irctc ixigo jio jiomart jupiter kfc kotak kuvera lenskart lic linkedin makemytrip mcdonalds meesho microsoft myntra netflix netmeds notion nykaa ola onecard openai oyo paytm pepperfry pharmeasy phonepe pizzahut pnb policybazaar porter practo primevideo pvr rapido razorpay rbl redbus relianceretail sbi sbicard scb shell shoppersstop slice sonyliv spicejet spotify starbucks steam swiggy tatacliq uber udemy unacademy union upstox urbancompany vi vistara yatra yes youtube zee5 zepto zerodha zomato zoom zoomcar. Resolution (`ui/components/AppLogos.kt`): ordered regex rule lists, case-insensitive, first match wins - `BANKS` (30 rules: sbicard first, then hdfc, icici, axis, hsbc, sbi|yono, kotak, yes, idfc, indusind, bob, pnb, au, federal, canara, union, rbl, scb, amex, onecard, boi, iob, indianbank, idbi, citi, bandhan, equitas, jupiter, slice), then `MERCHANTS`/`SPECIFIC`/`GENERIC` lists (specific brand patterns first, broad names like google/apple/microsoft last; order matters, e.g. instamart before swiggy, amazonpay before amazon). `AppLogos.allKeys()` is meant to equal the set of files (unit-testable invariant). Images are decoded with `BitmapFactory`, cached in `LruCache(64)`. Fallbacks in `Brands`/`BrandMark` (`ui/components/BankLogo.kt`): `LogoPaths` Simple-Icons SVG paths (HDFC, ICICI, Axis, HSBC, Visa, Mastercard, Amex, Diners, Discover, JCB, Paytm, PhonePe, Google Pay - CC0, v16.33.0) tinted, else a gradient monogram tile (brand colour pairs in `Brands.BANKS`; unknown banks get a stable palette colour from `hashCode`). Card networks (`CardNetwork`: VISA, MASTERCARD, AMEX, DINERS, DISCOVER, JCB, RUPAY, MAESTRO, UNIONPAY) badge at the corner of card avatars; `TypeCode` badge (FD/RD/PPF/Loan) and a "B" business badge.
- Kind colours: account 1A63C6 (dark 8AB4F8), credit card C8570F (dark FFB27A), debit card 6A3FC2 (dark C9A7FF).

### 6.2 Localization
See 4.11. Strings are English-keyed; plural handling is manual (`plural()` helper, separate `"{n} account and cards"` keys). Number/date formatting is NOT localised (`Periods` uses English patterns `d MMM yyyy`, `h:mm a`, `MMMM yyyy`, `EEE, d MMM yyyy`). Device locale only affects `NumberFormat` for en-IN. RTL declared (`supportsRtl`). For Flutter: reuse `lang/keys.json` + packs as ARB or a runtime key->string map; the keys contain `{named}` placeholders.

### 6.3 Currency and amounts
- Storage unit: integer **paise** (`amountMinor`), `currency` default `INR`; foreign spends keep original currency plus `inrMinor` (rupee value from forex rate; `LedgerMath.rupees(t) = inrMinor ?: (currency=="INR" ? amountMinor : 0)`), so un-priced foreign spends count as 0 in totals ("N need a rate" in Forex screen).
- `Money.format(minor, currency="INR", showPaise = minor % 100 != 0)` (`ui/format/Format.kt:29`): `NumberFormat.getCurrencyInstance(Locale "en-IN")` with `currency` set via `Currency.getInstance` (Indian digit grouping, ₹ symbol, `min/maxFractionDigits = 0 or 2`), value = `minor / 100.0`. If `AmountPrivacy.hidden`: `"₹••••"` (INR) or `"<CUR> ••••"`. `Money.compact`: >= 1 Cr -> `₹%.1fCr`, >= 1 L -> `₹%.1fL`, >= 1 K -> `₹%.1fK`, else `₹%.0f` (hidden -> `₹••••`). `Money.parseInput`: strips ₹, commas, spaces; regex `-?\d+(\.\d{1,2})?`; returns paise via `BigDecimal.movePointRight(2)`.
- Zone: `Periods.zone = ZoneId.systemDefault()` for all period maths (FY starts 1 April: `ViewFilter.fyStart`); `HisaabApplication` and `BalanceNotifications` use `Asia/Kolkata` for maturity/closing and balance-update day.
- Hide amounts: `AmountPrivacy.hidden` is global Compose state defaulting to **true** (so figures never flash at launch); `MainActivity` pushes the stored setting on every settings emission; Home eye icon toggles the stored setting. Tax share asks for confirmation when hidden because exports always carry real numbers.
- Signed amount colouring: `TxStyle.amount` -> transfer grey, credit `+` green, investment `−` accent, card spend `−` amber, bank/UPI spend `−` red. Credit-card bill payments are shown but never counted as spend or income.
- Tax maths: paise throughout, `TaxMath.LAKH = 100_000 * 100`, slab tax rounded `Math.round(part*rate/100.0/100.0)*100`.

### 6.4 Security
- No cloud backup / device-transfer (`data_extraction_rules.xml`, `allowBackup=false`).
- TLS only (`network_security_config.xml`); all network use: email servers (IMAP/Gmail), GitHub API/releases + raw language packs, RSS news feeds, UPI intent on Support.
- Secrets sealed with Android Keystore keys in `:email` (`StatementPasswordStore` identity incl. PAN/DOB/alt name/mobile, per-account bank unlock details, saved statement passwords; mail app passwords). UI never shows them again; "Encrypted on this phone" copy.
- App lock via `BiometricPrompt` (see 4.7); no secondary PIN; lock on every `onStop`.
- Notification text from payment apps is never persisted in logs; activity log stores counts/reasons only.
- Privacy copy repeated across screens ("Your data never leaves this phone", "no server"); ML Kit telemetry backend removed; update download checked against SHA-256 and signature.
- Obfuscation: release `minify` + `shrinkResources`; signing config from `local.properties` (`RELEASE_STORE_FILE`, `_PASSWORD`, `RELEASE_KEY_ALIAS`, `_PASSWORD`) or env `HISAAB_STORE_FILE/PASSWORD/KEY_ALIAS/KEY_PASSWORD`, falls back to debug signing when absent.
- Window is not marked `FLAG_SECURE` (no screenshot blocking found).

### 6.5 Misc UX conventions worth porting
- Empty/loading pattern: VMs expose `StateFlow` with a `loaded` flag; screens render nothing or skeleton until loaded to avoid empty-state flicker (Rules `list == null`, Tax `loaded`, Analytics `loaded`).
- Undo via Snackbar for destructive actions (merge, rule delete).
- Haptics: tab change (`TextHandleMove`), long-press on analytics legend (`LongPress`).
- Entrance animation `enterOnce(index)` for first screenful only; `animateItem()` on lazy lists; `AnimatedAmount` count-up.
- Info dialogs via `InfoButton`.
- Sheets use `ModalBottomSheet(skipPartiallyExpanded = true)` for forms; dialogs for confirmations.
- Testing hooks: testTags `tab-<route>`, `home`, `grant-sms`, `search`, `bench-body`, `bench-parse`, `bench-result`.

---

## Open Questions (not guessed)

1. **Email polling cadence mismatch**: `EmailConnectDialog` DONE text says "then checks every hour" (`settings/EmailConnect.kt:206`) but `GmailScheduler.schedulePeriodic` uses `PeriodicWorkRequestBuilder(1, DAYS)` (`email/.../GmailSyncWorker.kt:88`). Which is intended for the Flutter app? (Also `FEATURES.md` says "Automatic nightly email sync".)
2. **Budget alert default**: setting default `budget_alert_percent = 90` but `BudgetSummary.alertPercent` default is 80 in Analytics when the settings value is out of 1..100. UI choices are 80/90/95. Confirm 90 is canonical.
3. **`checkUpdates` toggle**: `SettingsViewModel.setCheckUpdates` and the DataStore key exist, but no switch is visible in the reviewed screens (About & updates only has "Check"). Is a switch intended (FEATURES.md says update checks are opt-out)?
4. **Home presets UI**: `HOME_PRESETS` and `TabLayoutStore.apply()` exist and FEATURES.md lists presets, but no screen read calls `apply()` and Customise only has per-section toggles + Reset. Is a presets control missing/removed in 2.9.x?
5. **Dead/unreachable code**: route `bench` (ParserBenchScreen), `ProfileSetupSheet`, `AddPasswordDialog` (`addingPassword` never set true), `QrCode.kt`, `SafeWidget`/`NetWorthWidget` on Home, Home `RecurringSheet` trigger, `Info.SMS/APP_PASSWORD/FETCH_HISTORY/PAYMENT_APPS/STATEMENT_PASSWORDS/STATEMENTS/INVESTMENTS/APP_LOCK` texts - confirm which should be ported (I assumed none of the dead ones).
6. **Support QR asset**: `SupportConfig.QR_ASSET = "support_qr.webp"` is referenced but not in `assets/`; `SupportConfig.available()` is true only because a UPI id is set. Whether a QR is intended is unclear.
7. **Hard-coded UPI VPA** in `SupportScreen.kt:66` (personal handle) - confirm whether the Flutter app should keep donations at all, and if so move to remote/config.
8. **Own-mobile guard** (`transactions.phoneLast4s`) behaviour only seen here as wiring; actual account-creation rule lives in `:shared` (other part).
9. **Net-worth hero card on Home** is gone (`"networth" -> Unit`) but legacy saved layouts may still list it; Portfolio keeps `networth`. Confirm no Home net-worth in the new app.
10. **Notification-listener rejection coverage for non-listed banking apps**: only the 19 package names above are read. FEATURES.md mentions "bank apps such as YONO SBI" only; confirm if more packages should be added for Flutter.
11. **Remaining unseen detail**: I read every screen/VM/worker/store file listed above in full or via targeted reads; for a few presentational files I read only signatures/headers (not full bodies): `ui/components/Kit.kt` (444), `Components.kt`, `MessageView.kt`, `Motion.kt`, `IconLibrary.kt` (icon-key list not captured), `ui/charts/Charts.kt`/`ProtoCharts.kt` (chart internals), `ui/transactions/TransactionViews.kt` (list/calendar/merchant card layouts) and `TxSummaryStrip.kt`, `ui/more/TaxReport.kt` (share layout drawing beyond the first 110 lines), `ui/more/QrCode.kt` internals, `ui/profile/PhotoCrop.kt` gesture internals, `Palettes.kt` full token tables for palettes other than DhanKosh/Fold/Classic/Emerald/Graphite. These are visual details rather than behaviour; re-read them when the Flutter widgets are specified.
12. **Appearance vs FEATURES.md**: FEATURES.md lists themes "DhanKosh, Fold, Classic, Emerald, Graphite, Indigo Night, Saffron, Ocean, Hero and Cinema palette groups" but the enum also has ROSE_QUARTZ and LAVENDER_BLOOM (Classic group). Treat the enum as source of truth.
13. **Test hooks**: Compose tests/androidTest folders exist (`app/src/test`: `CsvTransferTest`, `SmsIdsTest`; `shared/src/androidTest`) - out of scope here but they define behaviour invariants (e.g. SMS id format) the port must match.


---

# B. Database (`shared`) and Parser (`parser-core`) analysis

Source root: `hisaab_apk/`. Abbreviations used for file references:

- `SH/` = `hisaab_apk/shared/src/main/kotlin/com/hisaab/shared/`
- `PC/` = `hisaab_apk/parser-core/src/main/kotlin/com/hisaab/parser/`
- Line numbers are file-relative. A few come from concatenated reads and may be off by one or two; the symbol name is the reliable key.

Conventions that apply everywhere:

- All money is `Long` minor units (paise). `inrMinor` is the rupee value; `amountMinor` is in the transaction's own currency.
- All timestamps are epoch millis (UTC). Day buckets use IST (`Asia/Kolkata`, `ParserConfig.zone`, `PC/ParserConfig.kt:7`).
- Enums are stored as TEXT using the enum constant name (Room default).
- Booleans are INTEGER 0/1.

---

## 1. Database schema v15

`HisaabDatabase` (`SH/db/HisaabDatabase.kt:9-47`): file name `hisaab.db`, `VERSION = 15`, 13 entities, `exportSchema = true`, bundled SQLite driver (`SH/di/SharedModule.kt:30`). Identity hash of v15 is `85c4e5b943dbe2d2bc3934115822da0a` (`shared/schemas/.../15.json`). Query coroutines run on `Dispatchers.IO`.

DAOs exposed by the database: `transactions, sources, processedEmails, accounts, budgets, deletedMessages, statements, holdings, merchantRules, recurring, categories, forex, reconcile`.

Notation below: `?` = nullable, `DEFAULT` = Room `defaultValue`. "Enum" columns list the allowed values.

### 1.1 `transactions` (entity `TransactionEntity`, `SH/db/Entities.kt:13-61`)

| Column | Type | Notes |
|---|---|---|
| id | INTEGER PK autoincrement | |
| amountMinor | INTEGER | amount in `currency` minor units |
| currency | TEXT | "INR", "USD", ... |
| type | TEXT enum | `DEBIT, CREDIT, TRANSFER, INVESTMENT` |
| bankName | TEXT | display name, e.g. "HDFC Bank", or an app name ("PhonePe") for app notifications |
| accountLast4 | TEXT? | may be 2-4 chars (ICICI prints 3, SBI Corporate prints 2) |
| accountKind | TEXT enum | `ACCOUNT, CARD` |
| accountId | INTEGER? FK -> accounts.id | `ON DELETE SET NULL` |
| merchant | TEXT? | normalised display name |
| upiId | TEXT? | lower-cased VPA |
| referenceNumber | TEXT? | upper-case alphanumeric, min length 6 |
| channel | TEXT enum | `UPI, IMPS, NEFT, RTGS, CARD, ATM, AUTO_DEBIT, OTHER` |
| balanceMinor | INTEGER? | stated account balance (also debit cards: the linked bank account's) |
| availableLimitMinor | INTEGER? | stated available credit limit (credit cards) |
| timestamp | INTEGER | when money moved |
| hasExplicitTime | INTEGER (bool) | false = time of day taken from message arrival time |
| category | TEXT enum | see section 6.8 |
| transactionHash | TEXT | UNIQUE; SHA-256 (see section 7) |
| confidence | REAL | 0..1 |
| needsReview | INTEGER (bool) default false | dedup was unsure |
| duplicateOfId | INTEGER? | candidate id for a flagged review row (no FK declared) |
| reviewReason | TEXT? | human text |
| note | TEXT? | e.g. "Credit card bill payment", "Self transfer between your accounts" |
| createdAt | INTEGER | |
| subcategory | TEXT? DEFAULT NULL | user-chosen; null = auto guess from merchant |
| customCategoryId | INTEGER? DEFAULT NULL | points at `custom_categories.id` (no FK); `category` is then `OTHER` |
| inrMinor | INTEGER? DEFAULT NULL | rupee value; maintained by SQL triggers (section 2.9) |

Indices: UNIQUE `index_transactions_transactionHash(transactionHash)`; `index_transactions_amountMinor_accountLast4_timestamp`; `index_transactions_referenceNumber`; `index_transactions_timestamp`; `index_transactions_accountId`; `index_transactions_needsReview`.

### 1.2 `transaction_sources` (`TransactionSourceEntity`, Entities.kt:63-89)

Every message that contributed to a transaction (an SMS plus an email merge into one transaction).

| Column | Type | Notes |
|---|---|---|
| id | INTEGER PK auto | |
| transactionId | INTEGER FK -> transactions.id | `ON DELETE CASCADE` |
| source | TEXT | "SMS", "EMAIL", "CSV", "MANUAL", "APP", "SCREENSHOT", "STATEMENT" (the comment lists only SMS/EMAIL/CSV/MANUAL, the code writes `Source.name` and "CSV") |
| sourceMessageId | TEXT | unique per source. Special forms: `xfer-out:<uuid>`, `xfer-in:<uuid>` (manual own-transfer legs), `stmt:<statementKey>:<row>` (statement rows), ids containing `#` (derived rows such as `<id>#nps`, `...#split:<n>`) |
| sender | TEXT | SMS header or email From |
| parsedHash | TEXT | hash this message produced (so a later 3rd copy still matches after a merge) |
| rawText | TEXT? | capped at 20,000 chars (`RAW_TEXT_CAP`), kept for re-parse and split |
| receivedAt | INTEGER | = `ParsedTransaction.messageTimestamp` |
| subject | TEXT? DEFAULT NULL | email subject |

Indices: UNIQUE `(source, sourceMessageId)`; `(transactionId)`; `(parsedHash)`.

### 1.3 `processed_emails` (Entities.kt:91-99)

`messageId TEXT PK`, `processedAt INTEGER`, `outcome TEXT` (PARSED, REJECTED, DUPLICATE, ERROR), `transactionId INTEGER?`. Gmail ids already handled so no email is parsed twice.

### 1.4 `accounts` (`AccountEntity`, Entities.kt:101-138)

| Column | Type | Notes |
|---|---|---|
| id | INTEGER PK auto | |
| bankName | TEXT | |
| last4 | TEXT | UNIQUE with bankName |
| kind | TEXT enum | `ACCOUNT, CARD` |
| nickname | TEXT? | |
| colorArgb | INTEGER? DEFAULT NULL | |
| latestBalanceMinor | INTEGER? | last bank-stated balance |
| availableLimitMinor | INTEGER? | last stated card available limit |
| balanceUpdatedAt | INTEGER? | time that figure was true |
| createdAt | INTEGER | |
| manualBalanceMinor | INTEGER? DEFAULT NULL | user-typed balance (or card available limit) |
| manualBalanceAt | INTEGER? DEFAULT NULL | |
| accountType | TEXT? DEFAULT NULL | `SAVINGS, CURRENT, SALARY, NRE, NRO, WALLET, FD, RD, PPF, LOAN, CREDIT_CARD, DEBIT_CARD, PREPAID_CARD` (`AccountType`, Entities.kt:201-214). `liquid=false` for FD, RD, PPF, LOAN |
| cardNetwork | TEXT? DEFAULT NULL | `VISA, MASTERCARD, RUPAY, AMEX, DINERS, DISCOVER, JCB, MAESTRO, UNIONPAY` |
| linkedAccountId | INTEGER? DEFAULT NULL | debit card -> its bank account (no FK) |
| hidden | INTEGER (bool) DEFAULT 0 | |
| usage | TEXT DEFAULT 'PERSONAL' | `PERSONAL, BUSINESS` |
| maturityDay | INTEGER? DEFAULT NULL | epoch day for FD/RD |
| maturityAction | TEXT? DEFAULT NULL | `CREDIT` (closes), `RENEW_PRINCIPAL`, `RENEW_ALL` |
| forexMarkupBps | INTEGER? DEFAULT NULL | card forex markup (350 = 3.5%) |
| loanPrincipalMinor | INTEGER? DEFAULT NULL | |
| loanRateBps | INTEGER? DEFAULT NULL | annual rate in bps |
| loanTenureMonths | INTEGER? DEFAULT NULL | |
| loanStartDay | INTEGER? DEFAULT NULL | epoch day of first EMI |
| mergedIntoId | INTEGER? DEFAULT NULL | "visual merge": shown together with another account (no FK) |

Index: UNIQUE `(bankName, last4)`.

### 1.5 Other tables

- `budgets`: `category TEXT PK`, `monthlyLimitMinor INTEGER`. (Business logic lives in `:app`, see 2.8.)
- `deleted_messages`: composite PK `(source TEXT, messageId TEXT)`, `deletedAt INTEGER`. Tombstones: a deleted transaction's messages are never ingested again.
- `statements` (`StatementEntity`, `SH/db/Investments.kt:16-60`): `id PK auto`, `key TEXT` (UNIQUE `index_statements_key`), `source` (EMAIL, FILE; also "SMS"/"MANUAL" for card-due and override rows), `sender`, `subject?`, `fileName`, `receivedAt`, `status` (PARSED, LOCKED, EMPTY, UNREADABLE), `transactionCount`, `holdingCount`, `filePath?`, `bankName?`, `last4?`, `processedAt`, then DEFAULT NULL columns: `kind` (CREDIT_CARD, BANK, INVESTMENT, OTHER, plus special `CARD_PAYMENT`, `CARD_OVERRIDE`), `totalDueMinor`, `minDueMinor`, `dueEpochDay`, `creditLimitMinor`, `statementEpochDay`, `openingMinor`, `closingMinor`, `debitsMinor`, `creditsMinor`, `availableMinor`, `emailText`. This table is overloaded: it also stores per-card due notices and manual card overrides (2.2).
- `holdings` (Investments.kt:62-81): `id PK auto`, `kind` (`EPF, MUTUAL_FUND, STOCK, ETF, NPS, PPF, BOND, GOLD, FD, OTHER`), `name`, `identifier` (UNIQUE; ISIN, `EPF:<member>`, `NPS:<last4>[:T2]`, `MF:<scheme>`, `STOCK:<name>`, `US:...`, `AGG:INDMONEY:<class>`, `manual:<uuid>`), `units REAL?`, `valueMinor?`, `investedMinor?`, `asOf?`, `source` (SMS, EMAIL, STATEMENT, MANUAL), `note?`, `updatedAt`, `previousValueMinor? DEFAULT NULL`, `previousAsOf? DEFAULT NULL`.
- `merchant_rules` (Entities.kt:155-195): `merchantKey TEXT PK` (lower-cased name, UPI id, or contains-text), `category`, `updatedAt`, `matchType DEFAULT 'EXACT'` (`EXACT, CONTAINS`), `subcategory? DEFAULT NULL`, `customCategoryId? DEFAULT NULL`, `manual INTEGER DEFAULT 0`.
- `recurring` (`SH/db/Recurring.kt`): `id PK auto`, `name`, `amountMinor`, `income` (bool), `frequency` ("MONTHLY"/"YEARLY"), `dayOfMonth`, `month?` (1..12 for yearly), `category`, `accountId?`, `createdAt`. User-added plan items; they never create transactions.
- `custom_categories` (`SH/db/Categories.kt`): `id PK auto`, `name`, `icon` (icon-library key), `colorArgb`, `createdAt`.
- `custom_subcategories`: `id PK auto`, `parent` (enum name like "FOOD", or `custom:<id>`), `name`, `icon`, `createdAt`; UNIQUE `(parent, name)`.
- `forex_rates` (`SH/db/Forex.kt`): composite PK `(currency TEXT, day INTEGER)` (epoch day, India time), `inrPerUnit REAL`.

### 1.6 Relationships

- `transactions.accountId -> accounts.id` (SET NULL). `transaction_sources.transactionId -> transactions.id` (CASCADE). Those are the only declared FKs.
- Soft (unenforced) references: `accounts.linkedAccountId` (debit card -> bank account), `accounts.mergedIntoId` (visual merge, can chain; the SQL handles one hop plus "linked account of a merged child"), `transactions.customCategoryId`, `transactions.duplicateOfId`, `recurring.accountId`, `custom_subcategories.parent`, `processed_emails.transactionId`.
- `AccountDao.referenceCount` (Daos.kt:517) counts cards linked + recurring items on an account (guard before delete).

### 1.7 Migration history (`SH/db/HisaabDatabase.kt:53-212`)

| From-To | Change |
|---|---|
| 1-2 | `accounts.manualBalanceMinor/At` |
| 2-3 | `accounts.accountType/cardNetwork/linkedAccountId`; table `deleted_messages` |
| 3-4 | tables `statements` (unique key), `holdings` (unique identifier) |
| 4-5 | statements: kind, totalDue, minDue, dueEpochDay, creditLimit, statementEpochDay |
| 5-6 | holdings: previousValueMinor, previousAsOf |
| 6-7 | `accounts.hidden NOT NULL DEFAULT 0`; table `merchant_rules` |
| 7-8 | table `recurring` |
| 8-9 | `accounts.usage NOT NULL DEFAULT 'PERSONAL'` |
| 9-10 | `transaction_sources.subject`; `transactions.subcategory/customCategoryId`; tables `custom_categories`, `custom_subcategories` (+ unique index); statements: opening/closing/debits/credits/available |
| 10-11 | `statements.emailText` |
| 11-12 | `transactions.inrMinor` (backfilled = amountMinor where INR); `accounts.maturityDay/maturityAction/forexMarkupBps`; table `forex_rates`; installs the two INR triggers |
| 12-13 | `merchant_rules`: matchType, subcategory, customCategoryId, manual |
| 13-14 | accounts: loanPrincipalMinor, loanRateBps, loanTenureMonths, loanStartDay |
| 14-15 | `accounts.mergedIntoId` |

Gotcha for a port: the two triggers `transactions_inr_insert` and `transactions_inr_update` (AFTER UPDATE OF amountMinor, currency, accountId, timestamp) are NOT in the exported schema JSON; they are created by `ForexSql.install` in the 11-12 migration and again on every database open (`SharedModule.kt:36-38`, `CREATE TRIGGER IF NOT EXISTS`). A Flutter/Drift port must recreate them or compute `inrMinor` in code.

---

## 2. Repositories and business rules

### 2.1 Balance computation (accounts)

Per account the DB keeps up to three "balance" notions:

1. Bank/card-reported: `latestBalanceMinor` / `availableLimitMinor` at `balanceUpdatedAt`.
2. User-typed: `manualBalanceMinor` at `manualBalanceAt`.
3. Derived "change since" values computed in `AccountDao.observeWithActivity` (Daos.kt:459-491).

Updating the reported balance: `AccountDao.updateBalance(id, balance, limit, at)` (Daos.kt:398-403) uses `COALESCE` so a null leaves the old value, and only applies when `balanceUpdatedAt IS NULL OR balanceUpdatedAt <= at`. Older messages never rewind it. `setLimitFromStatement` has the same guard.

`AccountBalances` (Entities.kt:303-315):

- `usesManual(kind, reportedBal, reportedLimit, reportedAt, manual, manualAt)`: false if either manual field is null; otherwise true when `reported == null || reportedAt == null || manualAt >= reportedAt` (reported = limit for CARD, balance for ACCOUNT).
- `current(...)`: if usesManual then `manual + changeSinceManual`, else `(limit for CARD / balance for ACCOUNT) + changeSinceReported`, null if no reported figure.
- `AccountWithActivity.balanceIsEstimated` = not manual, `changeSinceReported != 0`, and a reported figure exists.
- `isLiquid` = kind ACCOUNT, `accountType?.liquid != false`, not hidden (counts toward Home balance).

Signed effect per transaction used in both `changeSince*` columns (and `ReconcileDao.netChange`, Daos.kt:550-561):

```
CREDIT                    -> +inrMinor
DEBIT, INVESTMENT         -> -inrMinor
TRANSFER and account is a CARD -> +inrMinor     (bill payment frees limit)
TRANSFER on a bank account    -> TransferLegs.SIGNED_SQL  (-1/+1/0, see below)
anything else             -> 0
```

Row filters: `t.accountId = a.id` OR the account is a child (`c.linkedAccountId = a.id`, `c.mergedIntoId = a.id`, or a child's linked account is merged into a); `t.needsReview = 0`; `t.inrMinor IS NOT NULL`; `t.timestamp > manualBalanceAt` (changeSinceManual) or `> balanceUpdatedAt` (changeSinceReported). `changeSinceReported` is forced to 0 for account types FD, RD, PPF, LOAN (interest moves them without transactions). The account list hides accounts merged into an existing account (`WHERE mergedIntoId IS NULL OR mergedIntoId NOT IN (SELECT id ...)`), `monthSpent` counts DEBIT+INVESTMENT `inrMinor` in `[from,to)` for the account plus children, `transactionCount` counts the account and merged children only. `linkedAccountId` in the result is rewritten to the linked account's `mergedIntoId` when that exists.

`TransferLegs.SIGNED_SQL` (`SH/db/TransferLegs.kt:13-16`), for a TRANSFER row `t` on a bank account:
- has a source whose `sourceMessageId LIKE 'xfer-out:%'` -> `-inrMinor`
- has `'xfer-in:%'` -> `+inrMinor`
- `t.note LIKE 'Credit card bill%'` -> `-inrMinor` (bill paid from this account)
- else 0 (direction unknown; counted as "unclear" by reconcile).

Stated-balance check (`TransactionRepository.gapFor`, repo lines 148-160, and `BalanceReconciler`, `SH/repo/BalanceReconciler.kt`): when a new message states a balance (or card limit) at time `at`, the repo computes `netChange(account, card, previousAt, at)` and flags a `BalanceGap` when `|stated - (previous + net)| > 100` paise (`TOLERANCE_MINOR`), only if `statedAt > previousAt`, `unclear == 0`, `now - statedAt <= 15 days` (`FRESH_MS`), the account is liquid, and no manual balance newer than the previous stated one exists. Debit-card messages state the linked bank account's balance and update that account (repo lines 253-258). Credit-card messages update `availableLimitMinor`; balance is only taken for accounts or debit cards (`tx.balanceMinor.takeIf { ACCOUNT || isDebitCard }`, repo line 244). "Key per account, one notification per day" is a `BalanceGap` doc statement; the daily gating lives in `:app` (`BalanceReconciler.due(lastDay, today)`).

Statement to account (`applyStatementToAccount`, repo 529-549): CARD available limit = `available ?: (creditLimit - (totalDue ?: 0)).coerceAtLeast(0)`; ACCOUNT balance = `closingBalance`. Both only move forward in time.

Deposits/loans from messages (`applyLoanStatus` / `applyDeposit`, repo 378-413): see 2.5 and `DepositTerms` (`SH/repo/DepositTerms.kt`): `typeOf(kind)`; `of(d, at, currentDay, currentAction, newest)` returns the maturity day/action to save. A closed deposit gets maturity day = stated maturity or message day (IST) and action CREDIT, only if `newest`. `AccountDao.closeMatured(today)` hides CREDIT-action deposits with `maturityDay <= today`.

### 2.2 Credit-card figures (billed / min due / unbilled / limit)

File: `SH/repo/CardDues.kt`. Inputs to `CardDues.position(rows, availableMinor, flow, today, zone)`:

- `rows`: the statement-table rows for that card (`CardDues.rowsFor(all, bank, last4, cards)`, lines 187-199).
- `availableMinor`: the card's current available limit (`AccountWithActivity.currentBalanceMinor`).
- `flow`: card movements over the last `WINDOW_DAYS = 60` days (or since the newest statement date, whichever is older; see `NetWorthSource.cardLimit` in `:app`), as `(timestamp, type, inrMinor)`, ignoring duplicates.

Output `CardPosition`: `billedMinor, minDueMinor, dueDay, statementDay, limitMinor, unbilledMinor, outstandingMinor, estimated`, edit flags, `calculated` (the base position beneath an override), `source` (SMS/EMAIL/STATEMENT/MANUAL), `sourceAtMs`. Derived: `totalMinor = billed + unbilled` when either known, else `outstanding`; `owedMinor = billed if >0 else outstanding if >0 else 0`; `limitLeft(limit, available)` = `max(0, limit - totalMinor)` only when billed/unbilled/outstanding was manually edited, else `available`.

Constants: `STALE_DAYS = 35`, `WINDOW_DAYS = 60`, `DUE_GAP_DAYS = 19` (typical statement-to-due days), due-gap clamp `10..30`, special row kinds `CARD_OVERRIDE`, `CARD_PAYMENT` (`debitsMinor` = amount paid, `statementEpochDay` = day it was acknowledged), `CREDIT_CARD` (`KIND_DUE`).

Helper `net(flow, from, to)` = sum over flow with `from <= ts < to` of `DEBIT:+amount`, `CREDIT:-amount`, others 0, floored at 0.

Algorithm (`basePosition`, lines 202-257):

1. Usable rows (`usable`, line 158): status not LOCKED/UNREADABLE and kind not BANK/INVESTMENT; overrides excluded here. `carriesBill(r)` = kind not CARD_PAYMENT/CARD_OVERRIDE and (`totalDueMinor` or `dueEpochDay` non-null).
2. A bill row with no `statementEpochDay` is given one: `dueEpochDay - 19`, else the arrival day (`receivedAt` if >0 else `processedAt`).
3. `bill` = the row with `totalDueMinor != null` that is newest by `(statementEpochDay, arrival, processedAt)`. `limit` = `creditLimitMinor` of the newest row that has one. `dueDay` = bill's due day. `gap` = `clamp(due - stmt, 10, 30)` when both known else 19. `statementDay` = bill's statement day or `dueDay - gap`.
4. `paidSince(day)` = `max( sum of TRANSFER flow amounts with ts >= start of day, sum of CARD_PAYMENT rows' debitsMinor with statementEpochDay >= day )`.
5. `stale = dueDay < today - 35 days`. Reference row = newest row with a statement or due date; `refStmt` = its statement day or `due - gap`; `expected = latestStatement(refStmt.dayOfMonth, today)` (latest date <= today with that day-of-month, clamped to month length).
6. `covered = bill != null && !stale && (trust || expected == null || statementDay == null || statementDay >= expected)`.
   - If covered: `billed = max(0, bill.totalDue - paidSince(statementDay))` (when `statementDay` null: max of all TRANSFER flow and all payment rows); `minDue = bill.minDue` only if `billed > 0`; `unbilled = net(flow since the day after statementDay)`; `source = bill.source` for due notices, else "STATEMENT".
   - Else if `expected != null && refStmt != null`: estimated bill. `prev` = same day-of-month in the month before `expected`. `carried = bill != null && !stale && statementDay != null && statementDay >= prev - 3 days`. `base = carried ? statementDay : prev`. `gross = (carried ? bill.total : 0) + net(flow, base+1, expected+1) - paidSince(base)`. If `gross > 0 || carried`: position with `billed = max(gross, 0)`, `minDue = null`, `dueDay = expected + gap`, `statementDay = expected`, `unbilled = net(flow since expected+1)`, `estimated = true`.
   - Else `outstanding`: if `limit != null && available != null && limit >= available` then `limit - available`; else if the flow has any DEBIT then `net(flow since last TRANSFER timestamp, or 0)`; else null. Returns `CardPosition(limitMinor, outstandingMinor)`.

Manual override (`position`, lines 118-153): override = newest `CARD_OVERRIDE` row (fields: billed in `totalDueMinor`, minDue, due day, unbilled in `closingMinor`, outstanding in `openingMinor`, set time in `processedAt`; an all-null override is ignored).
- A real bill/due row that ARRIVED after the edit replaces the override (`trust = true`; limit still filled from older rows).
- Otherwise `paid = max(TRANSFER flow since setAt, CARD_PAYMENT rows on/after set day)`; `billed = o.billed - paid`; if `billed <= 0` or `outstanding <= 0` the override is dropped and base is returned. Else base with `billed` (override), `minDue` (override if billed overridden, else `o.minDue ?: base.minDue`), `due` (override or base), `unbilled = o.unbilled + net(flow since setAt)`, `outstanding = o.outstanding - paid + spent`, `source = "MANUAL"`, `calculated = base`.

Due messages recorded as rows (`CardDueRecorder.apply`, lines 294-311): key `cardpay:<bank>:<last4>:<day>:<amount>` for payments, `carddue:<bank>:<last4 or "any"+total>:<day>` for dues, where `day` = statement day (or the sent day). A row is skipped when the key exists and (it is a payment, or the existing row already has a total, or the new one has no total). `CardOverrideStore` writes key `cardovr:<bank lower>:<last4>`.

Matching rows to cards (`rowsFor`, lines 187-199; `bankMatches`, 174-180): same last4 and (row bank null or same issuer), or, when the card is the only card of its issuer, rows of that issuer with no last4 or a last4 no known card has. Issuer equality = `BankKeys.of(name)` (hdfc, icici, axis, hsbc, sbi, kotak, yes, idfc, indusind, baroda, pnb, federal, canara, union, rbl, scb, amex, au) else noise-stripped lower name; equal, or one prefix of the other with min length 3.

### 2.3 Transfers and card-bill-payment exclusion

Where money is classified as TRANSFER (excluded from spend and income everywhere: `MonthSpend` rules, analytics queries use only `type IN ('DEBIT','INVESTMENT')` / `'CREDIT'`):

1. Parser level: `TypeClassifier` TRANSFER regex (card "payment received" wording, self transfer, own account) -> TRANSFER; `BaseBankParser` converts a bank DEBIT to TRANSFER when `CardBill.isBill(text, merchant, vpa)` (`PC/bank/BaseBankParser.kt:95`); payment-app notifications paying a card are kept as TRANSFER with merchant label "Credit card bill" (`FreeTextParser.kt:108-120`).
2. Ingest level: `CardBill.mark` (`PC/rules/CardBill.kt:79-83`) converts any DEBIT whose text or payee reads as a card bill into TRANSFER/Category.TRANSFER with merchant `merchant ?: "Credit card bill"`; the bank-side row also gets note `"Credit card bill payment"` (repo `CARD_BILL_NOTE`, repo line 233), which gives the transfer its direction in SQL.
3. `pairTransfers(id)` (repo 323-353), run after each INSERT (not for merges):
   - DEBIT or CREDIT row on an account: look for the opposite type, same `amountMinor`, within +-2 hours, a different non-null `accountId`, both `accountKind == ACCOUNT` -> both rows become TRANSFER with note "Self transfer between your accounts".
   - A bank DEBIT: look within +-`CARD_PAIR_WINDOW` for a same-amount TRANSFER that is on a CARD or whose note starts "Credit card bill" -> mark this debit TRANSFER with note "Credit card bill payment".
   - Else, a bank DEBIT tries `pairEmi`.
   - A card-side TRANSFER ("payment received"): the nearest same-amount bank DEBIT (kind ACCOUNT) within the window becomes TRANSFER with the bill note.
   - `CARD_PAIR_WINDOW = 5 days` (repo line 853) although the kdoc at line 321 says 3 days; the constant is authoritative.
4. `pairEmi` (repo 359-372): same amount within +-3 days; one side on a LOAN account with category EMI_LOAN, the other a DEBIT on a non-loan account with category EMI_LOAN or channel AUTO_DEBIT -> the loan-account side becomes TRANSFER with note "EMI also debited from your bank account" (so the bank debit stays the spend).
5. Manual transfers (`addOwnTransfer`, repo 437-468): two TRANSFER rows (out leg on `from`, in leg on `to`; one may be missing), hash `manual-xfer:<uuid>:out|in`, source MANUAL with `sourceMessageId = xfer-out:<uuid>` / `xfer-in:<uuid>`, merchant "To <account label>" / "From <account label>". A later bank message matching a leg (same account, same amount, same direction, within 36 h, nearest) is folded into the leg (`manualLegFor`, 419-428).
6. Sweeps: `reclassifyCardBills()` (805-848) re-runs the classification over stored data (bank/wallet/app DEBITs with a card-bill payee or text -> TRANSFER; then pairs every card-side payment).
7. Rules never re-file transfers: `ruleFor` returns null for TRANSFER; `MerchantRuleDao.applyToPast/observeMatchCount` have `type != 'TRANSFER'`.

Spend definition (`SH/insight/MonthSpend.kt:46-55`): spend = `DEBIT` and category != TRANSFER; refund = `CREDIT` with category REFUND (subtracted from spend); income = `CREDIT` and category not TRANSFER/REFUND; investments (type INVESTMENT) are not "spend" in this view. Note the Room aggregate queries (`observeCategoryTotals`, `observeMonthly`, etc.) count `DEBIT` and `INVESTMENT` as "spent" and `CREDIT` as "income" (including refunds); the two definitions differ and a port must pick the right one per screen.

### 2.4 Untracked-payment ("balance gap") detection

`SH/insight/BalanceGaps.kt`, loaded by `SH/repo/UntrackedGapFinder.kt`. Constants: `MIN_GAP_MINOR = 100` (1 rupee), `MIN_SHARE_BPS = 50` (0.5% of money involved), `MAX_AGE_MS = 90 days`, `MAX_UNKNOWN_TRANSFERS = 6`, history loaded = 240 days (`HISTORY_DAYS`).

Algorithm (`detect`, lines 54-86), per account `a` that is not merged, hidden, linked (debit cards), or non-liquid:

1. `members = {a} + debit cards linked to a + accounts merged into a (+ cards linked to those)`.
2. `rows` = usable (`!needsReview && duplicateOfId == null && accountId != null`) transactions of the members, sorted by `(timestamp, id)`. `stated` = rows with a non-null `availableLimitMinor` (cards) or `balanceMinor` (accounts).
3. For each consecutive pair of stated rows `(s1, s2)`: skip if `t2 <= t1` or `now - t2 > 90 days`, or if a manual balance was set within `(t1, t2]`. Expected `B2 = B1 + sum(window)` where the window is every row with `t1 < ts <= t2` (the stating row included): CREDIT `+`, DEBIT/INVESTMENT `-`, TRANSFER on a card `+`, TRANSFER on an account uses the known direction map (`xfer-out`, `xfer-in`, or note "Credit card bill") else it is "unknown". Any row with null `inrMinor` aborts the window.
4. `gap = B2 - expected`. With unknown-direction transfers every sign combination is tried; if any reading explains the balance (insignificant) -> no gap; and if there are any unknown transfers the result is null regardless. More than 6 unknown transfers -> null.
5. Significance: `|gap| >= max(100, (|gap| + sum(|amounts in window|)) * 50 / 10000)`.
6. Emit `UntrackedGap(accountId, fromTime, toTime, deltaMinor, balanceBefore, balanceAfter, card)`; key `"accountId|fromTime|toTime"`; skipped if in the dismissed set. `moneyLeft = delta < 0`. Results sorted by `toTime` descending.

Follow-ups: `GapPrefill.of(gap, lastChoice)` picks `choices` (out and card: PAYMENT only; out: PAYMENT or TRANSFER; in: RECEIVED or TRANSFER); default is TRANSFER for a card limit that rose, else the first choice; prefill time = `toTime - 60 s`. `GapCandidates.find(gap, rows)`: from account-less INR rows inside the window with the right direction and not TRANSFER (max 14 oldest), finds up to 3 suggestions whose amount (single, or sum of 2 or 3 rows) is within 100 paise of `|delta|`.

### 2.5 Loans detection and amortisation

`SH/insight/Loans.kt`.

`Amortization`: monthly rate `r = rateBps / 10000 / 12`. `emi = round(P r (1+r)^n / ((1+r)^n - 1))` (zero rate: `ceil(P/n)`). `schedule(terms, emiOverride)` iterates until the balance is 0 (hard cap = tenure + 600): `interest = round(balance * r)`; final instalment when `n == tenure` or `emi >= balance + interest` pays off the rest; stops if principal part <= 0 and it is not last. `dueOn(first, n)` = first EMI's day-of-month clamped to month length. `elapsed(first, today, max)` = EMIs due on or before today. `remainingEmis(outstanding, emi, rateBps)` = `ceil(-ln(1 - r*outstanding/emi) / ln(1+r) - 0.01)` (null if `x <= 0` or no EMI).

`Loans.build(accounts, payments, today, zone, dismissed, links, merged)`:

- Payment pool: `pays` = EMI-candidate transactions (`TransactionDao.observeLoanPayments`: `type != 'CREDIT' && needsReview = 0 && (category = 'EMI_LOAN' OR accountId in LOAN accounts)`), filtered by `isPayment` (not needsReview, not CREDIT, currency INR, category != INVESTMENT, customCategoryId == null).
- Loan accounts: `AccountWithActivity.isLoan` and not hidden. A payment belongs to a loan account when booked on it (or on a merged child), or it is an EMI_LOAN payment booked on a non-loan account and (`LoanLinks` links it: by tx id or by payee key `keyOf = (merchant ?: upiId).trim().lowercase()`, length >= 2) or (unlinked and its text names the loan: the loan's last4 (>=4 chars) appears in merchant/upi/note, or merchant equals / is "name " prefix of the nickname or bank name, min length 5).
- Detected loans (no account): EMI_LOAN payments not claimed, grouped by `keyOf`, not in `dismissed`; kept when payments span >= 2 distinct months (or the key is in `links.manualPayees`) and the latest payment is within 75 days.
- `summarise()`: `distinct()` collapses same-amount payments within 3 days; `median` of amounts; `series` = payments within 20% of the median (`|a - median| <= median/5`); `emi` = last series amount else computed EMI; `emiDay` = median day-of-month of the series else the start day; `elapsed` by calendar when terms+start day are set; `paidCount = elapsed ?: series.size`; `outstanding = bankOutstanding ?: schedule balance after elapsed`; `remaining` rules (schedule size minus elapsed when no bank figure; else `remainingEmis` from outstanding; else tenure minus series count); `nextDue` = EMI day this month if not yet paid this month and not before today, else next month, but never before the start day, and null when remaining==0 or outstanding==0; `payoff` = `nextDue + (remaining-1) months`. `closed = outstanding == 0 || (remaining == 0 && terms != null)`; `progress` by principal repaid, else EMIs.
- Loan account balance (`outstanding`) = `|currentBalanceMinor|` (the account's reported figure), or the latest child's.
- Duplicate loans (`duplicates`): same last4 (>=3 chars), or no conflicting numbers and same name / 5+ char prefix / same lender name; `into` = the one with terms then more payments.

Message side: lenders have their own parsers (`LenderParser`, section 6.9). `applyLoanStatus` (repo 378-393) creates the LOAN account for a lender status, sets principal from a disbursal only when the account has none, and stores outstanding as the account balance via `updateBalance`. `ensureAccount` auto-types any new account at a known lender as LOAN (repo 303, `Lenders.isLender`).

### 2.6 Net-worth history (lives in `:app`, summarised for completeness)

Not in `shared`. `app/.../ui/ledger/NetWorth.kt` (`NetWorthSource`, `WorthHistory`) and `app/.../settings/LocalLists.kt` (`recordWorth`):

- Assets = liquid bank balances (>0) + FD/RD balances + PPF + holdings by class (`AssetClass.of(kind)`); liabilities = |loan balances| + sum of each credit card's `owedMinor` (from `CardDues.position`). Per-class, per-liability-kind and per-account exclusions (DataStore `NetWorthPrefs`). Business accounts excluded from the PERSONAL book, holdings excluded from the BUSINESS book.
- Daily recorded point: whenever the all-books (assets, liabilities) pair changes and one is >0, `recordWorth` upserts `{day, a, l}` for today into a JSON array in DataStore; keeps the last 1100 entries (~3 years).
- Before the first recorded day the history is estimated by walking back from the anchor (first recorded point or today): month-ends for 36 months (`WorthHistory.MONTHS = 36`) plus 26 weekly points, only from the first transaction day on; asset account flows undone (credits/debits only, investments/transfers leave net worth unchanged), credit-card dues = anchor dues + (payments - spends), clamped >= 0; EPF/NPS growth between previous and latest value spread linearly.
- Home shows "net worth ~30 days ago" = last history point on or before today-30 days, else the first point if >= 2 points.

### 2.7 Merchant-rule learning

- Key: `MerchantRuleEntity.keyOf(merchant, upiId)` = `(merchant ?: upiId).trim().lowercase()`, length >= 2 (Entities.kt:176).
- Learned rule: `TransactionRepository.setCategory(ids, category)` (repo 490-500): updates categories (clearing subcategory and customCategoryId), then for each non-TRANSFER transaction's key not already a manual rule: upsert an EXACT, non-manual rule (category only, no subcategory) and run `applyToUncategorised`: set that category on past rows with `category = 'OTHER'`, type in DEBIT/CREDIT/INVESTMENT, and `LOWER(TRIM(merchant)) = key OR (merchant IS NULL AND LOWER(TRIM(upiId)) = key)`.
- Manual rules (More > Rules): `saveRule(rule, previousKey, applyToPast)` upserts with `manual = true`; optionally `applyToPast` runs `MerchantRuleDao.applyToPast` (sets category, subcategory, customCategoryId on all non-TRANSFER rows that match exactly (by merchant or UPI id) or by `LIKE %text%` with `ESCAPE '\'` and `% _ \` escaped by `likeOf`). A recategorisation never overwrites a manual rule.
- Applying at ingest (repo 166-170, 181-183): TRANSFER never gets a rule; best rule = manual EXACT, else manual CONTAINS with the longest key, else the learned EXACT rule for the key (looked up by primary key). The rule sets `category`; its `subcategory`/`customCategoryId` are written onto the new row too (`filed()`). On a MERGE into an existing row the rule's subcategory follows only if the row has no subcategory/custom category and its category equals the incoming one (`keepsOwn`, repo 206).
- Matching function `matches` (Entities.kt:169): EXACT compares trimmed lower-cased merchant OR upiId to the key; CONTAINS tests the key as a substring of `"<merchant> <upiId>".lowercase()`.
- Payee-to-account memory: `payeeAccounts` map key -> accountId fed from app settings; applied to account-less APP-source rows (repo 191, 279-283).

### 2.8 Budgets

`budgets(category PK, monthlyLimitMinor)`; `BudgetDao` has `upsert`, `delete(category)`, `observeAll`. No business rules in `shared`. In `:app`: `notify/Alerts.kt:checkBudgets` reads `TransactionDao.observeCategoryTotals(monthStart, monthEnd)` (type DEBIT+INVESTMENT, `inrMinor`), and for each limit alerts when `used * 100 >= limit * level` for level in `{budgetAlertPercent (default 90 per the kdoc), 100}` descending, deduplicated by key `budget:<CATEGORY>:<yyyy-MM>:<level>` stored in `alertedKeys`. `AnalyticsViewModel` sums limits x months in the range for "budget vs spent". Budgets have no custom-category support (PK is the built-in `Category`).

### 2.9 Forex

`SH/db/Forex.kt`.

- `forex_rates(currency, day)` = rupees per unit, user-set per day. `ForexDao.upsert` (REPLACE), `delete`, `observeRates`, `observeForeign` (counts of non-INR transactions and how many have `inrMinor IS NULL`), `recompute()`.
- `inrMinor` formula (used by the triggers and `recompute`): for INR: `amountMinor`; otherwise `CAST(ROUND(amountMinor * r.inrPerUnit * (1 + markupBps/10000.0)) AS INTEGER)` where `markupBps` = the transaction's account `forexMarkupBps` (0 if none) and `r` is the rate row for the same currency whose day is nearest (`ABS(r.day - istDay)` minimal; `istDay = (timestamp + 19,800,000) / 86,400,000`; ties resolved by `LIMIT 1`, order unspecified). No rate for that currency -> NULL (excluded from every total instead of being counted as rupees).
- Triggers: `AFTER INSERT` recomputes for the new row; `AFTER UPDATE OF amountMinor, currency, accountId, timestamp` recomputes. Changing a rate or a card's markup does NOT fire a trigger: the app must call `ForexDao.recompute()` (updates every non-INR row).
- Parser side: amounts can be USD/EUR/GBP/AED/SGD/AUD/CAD/JPY/CHF/SAR/QAR (`AmountExtractor`); Fixture example "USD200.00 was spent on your SBI Corporate Card ...".
- All aggregations use `inrMinor`; `MonthSpend` and `Planning` additionally fall back to or filter on `currency == "INR"`.

---

## 3. Recurring detection (exact)

`Planning.recurring` (`SH/insight/Planning.kt:89-114`). Input: list of `TransactionEntity`, `today: LocalDate`, `zone`.

Steps:

1. Filter: `type in {DEBIT, INVESTMENT}`, `!needsReview`, `currency == "INR"`, local date `>= today - 130 days`.
2. Group by `key(t) = (merchant ?: upiId).trim().lowercase()`, kept only when length >= 2 (null keys dropped).
3. For each group: `median` = element at index `size/2` of the sorted `amountMinor` list (upper median for even sizes). `similar` = rows with `|amount - median| <= median / 5` (integer division, i.e. within 20%), sorted by timestamp.
4. `months` = distinct year-months of `similar`; require `months.size >= 2`.
5. `days` = day-of-month of each similar row; require `max(days) - min(days) <= 6` (plain subtraction, no wrap-around across month ends).
6. `last` = latest similar row; require its date `>= today - 45 days`.
7. Output `Recurring(name = last.merchant ?: last.upiId ?: "Payment", amountMinor = last.amountMinor (the latest, not the median), dayOfMonth = median of days (index size/2 of sorted), category = last.category, accountId = last.accountId, lastPaid = lastDate, nextDue = (month of lastDate + 1).atDay(min(day, monthLength)), occurrences = similar.size)`.
8. Sorted ascending by `nextDue`.

There is no yearly or weekly detection and no minimum amount; frequency is always monthly. Note a group's amounts outside the 20% band are silently dropped from `similar`, and the "2 months" test counts distinct months, so two payments in the same month do not qualify.

`withManual(detected, manual, today)` (lines 120-135): user items (`RecurringEntity`) become `Recurring` with `manualId`, `income`, `yearly`; next date = monthly: this month's day if `>= today` else next month; yearly: `month` (default current month) this year if `>= today` else next year, always with day clamped to month length. A manual item replaces any detected item with the same lower-cased name.

`withLoans(recurring, loans)` (lines 142-162): for each non-closed loan with `emiMinor`, `emiDay`, `nextDue`: tag the first untagged non-income item whose name equals the loan name (ignoring case) OR (`category == EMI_LOAN` AND `|amount - emi| <= emi/5` AND `|dayOfMonth - emiDay| <= 6`) with `loanKey`; if none, add a synthetic item named `loan.name` (detected) or `"<name> EMI"`, category EMI_LOAN, `occurrences = loan.trackedCount`.

Insurance policies (`policies`, lines 176-190): transactions with category INSURANCE and type not CREDIT/TRANSFER grouped by trimmed merchant (default "Insurance"); `monthly` when two distinct payment months and some pair is exactly 1 month apart (`ChronoUnit.MONTHS.between == 1`), else yearly; `nextDue = lastDate + 1 month` or `+ 1 year`; kind by regex on `"$insurer ${note}"`: HEALTH `health|mediclaim|star\s|niva|bupa|care\s|cigna|aditya birla health`, LIFE `\blife\b|term|\blic\b|pru|aia|max life`, MOTOR `motor|car\b|bike|two.?wheeler|vehicle|\bauto\b`, else OTHER (first match wins in that order).

---

## 4. Insights and forecast logic

All in `SH/insight/Planning.kt` and `MonthSpend.kt` (pure functions).

`Planning.insights(txs, recurring, today, zone, max = 5)` (lines 224-282): considers DEBIT, `!needsReview`, `INR`. Produces, in this order, then `take(5)`:

1. Pace: spend up to the same day-of-month this month vs last month. If both > 0 and `pct = (now - last) * 100 / last` (integer) has `|pct| >= 10`: title "Spending is N% ahead of last month" (WARN) or "... below ..." (GOOD).
2. Category drift: for each `Category`, `avg` = (sum of the 3 previous full months) / 3 and `now` = this month so far; among categories with `avg > 0`, the one with max `now - avg`; only if `now - avg >= 50,000` paise (Rs 500): "<label> is above your usual" (WARN).
3. Regular payments: if recurring non-empty: "N regular payments, Rs X a month" (INFO) with subscription count = recurring items in SUBSCRIPTIONS, ENTERTAINMENT or BILLS.
4. Biggest expense of the month (INFO), the single largest DEBIT this month.
5. Weekend share: if weekend (Sat, Sun) spend >= 45% of the month's spend -> INFO.

Savings: `Planning.month(txs, month, zone)`: income = CREDIT non-REFUND sum; spent = (DEBIT sum - REFUND credits) floored at 0 (note: INVESTMENT excluded from spent; `investedMinor` reported separately; TRANSFER excluded since it is neither type); `savedMinor = income - spent`; `rate = saved / income`. `Planning.savings`: average saved over the last up-to-3 complete months that have any income or spend; PF/NPS growth per month = `(valueNow - previousValue) / max(1, (asOf - previousAsOf) / 30 days)` summed over EPF and NPS holdings (floored at 0); `yearlyEstimate = (average + pfNps) * 12`.

`MonthSpend.compute` (see 2.3 for the definition): running cumulative-by-day lists for this period (to today) and the previous period, `previousSamePeriod` = previous cumulative at the same elapsed day count, `changePercent = (spent - previousSamePeriod) * 100 / previousSamePeriod` (int), `byAccount` spend grouped by `accountId` (null kept). It uses `inrMinor` (fallback `amountMinor` when INR, else 0).

Forecasting is limited to: `Recurring.nextDue` (above), loan `upcoming` (next 12 amortisation rows), deposit maturity days, the savings yearly estimate, and TaxIncome projection (section 5.2). There is no balance or cash-flow forecast in `shared`. See Open Questions.

Subcategory guessing (`SH/insight/Subcategories.kt`): see section 6.8.

---

## 5. Tax centre

`SH/insight/TaxCalculator.kt`, `TaxIncome.kt`. Header comment (lines 6-16): "Rules as of 2026-10-11"; FY 2026-27 reuses the FY 2025-26 rules (`FY2026_27 = FY2025_26.copy(fyStartYear = 2026)`); not confirmed against the official 2026-27 page: old-regime rebate and capital-gains rates (111A 20%, 112A 12.5% above Rs 1.25 lakh) carried over. `TaxRules.forYear(y)` = last rule set with `fyStartYear <= y`, else FY2024-25.

Units: paise. LAKH = 10,000,000 paise (Rs 1 lakh). All percentages below are the code's values.

### 5.1 Rules

Slabs (taxed at rate up to the limit; marginal):

New regime FY2025-26 and FY2026-27 (same for every age band):
- 0 to 4L: 0%; 4L to 8L: 5%; 8L to 12L: 10%; 12L to 16L: 15%; 16L to 20L: 20%; 20L to 24L: 25%; above 24L: 30%.

New regime FY2024-25: 0 to 3L: 0%; 3L to 7L: 5%; 7L to 10L: 10%; 10L to 12L: 15%; 12L to 15L: 20%; above 15L: 30%.

Old regime (all years):
- Below 60: 0 to 2.5L: 0%; 2.5L to 5L: 5%; 5L to 10L: 20%; above 10L: 30%.
- Senior (60 to 79): 0 to 3L: 0%; 3L to 5L: 5%; 5L to 10L: 20%; above: 30%.
- Super senior (80+): 0 to 5L: 0%; 5L to 10L: 20%; above: 30%.

Standard deduction: new regime Rs 75,000 (both years); old regime Rs 50,000. Applied as `min(salary, std)`.
Family pension deduction: `min(pension / 3, cap)`; cap Rs 25,000 new regime, Rs 15,000 old regime.
Rent received: 30% standard deduction (`rentStandardPct = 30`): `rentNet = rent * 70 / 100`.

Section 87A rebate:
- New regime FY2025-26/26-27: if total income (taxable + special-rate income) <= Rs 12 lakh -> rebate = `min(slabTax, Rs 60,000)`. Above the limit with marginal relief (only when there is no special-rate income): `rebate = max(0, slabTax - (total - 12L))`. FY2024-25: limit Rs 7 lakh, max Rs 25,000, marginal relief true.
- Old regime: limit Rs 5 lakh, max Rs 12,500, no marginal relief.

Surcharge on tax (tier chosen by `lastOrNull { total > threshold }`, total = taxable + special income):
- Old regime tiers: above Rs 50L 10%, above Rs 1 Cr 15%, above Rs 2 Cr 25%, above Rs 5 Cr 37%.
- New regime tiers: above Rs 50L 10%, above Rs 1 Cr 15%, above Rs 2 Cr 25% (no 37% tier; capped 25%).
- Surcharge = `round(normalNet * rate/100 + specialTax * min(rate, 15)/100)` (capital-gains surcharge cap `specialSurchargeCapPct = 15`).
- Marginal relief at a tier: total tax plus surcharge must not rise more than the income above the threshold; implemented by recomputing the tax at the threshold (cutting income above it first from normal income, then LTCG, then STCG) and capping `surcharge <= max(0, taxAtThreshold + surchargeAtThreshold + over - tax)`.

Health and education cess: 4% of `(tax + surcharge)`, rounded to nearest rupee. `tax = slabTax - rebate + specialTax`.

Capital gains: STCG on equity (111A) 20%; LTCG on equity (112A) 12.5% above an exemption of Rs 1.25 lakh. Unused basic exemption (shortfall of taxable income below the first slab's upper limit, when that slab's rate is 0) absorbs STCG first, then LTCG after the exemption. Special tax = `round(stcgT * 20% + ltcgT * 12.5%)`.

Deductions (`deductionsAllowed`: old regime true, new regime false except employer NPS):
- Employer NPS 80CCD(2): allowed in both regimes, uncapped here (`max(0, employerNps)`).
- Old regime only: 80C `min(c80, Rs 1.5L)`; 80CCD(1B) `min(nps1B, Rs 50,000)`; 80D self `min(d80Self, Rs 25,000 or Rs 50,000 if age != BELOW_60)`; 80D parents `min(d80Parents, Rs 25,000 or Rs 50,000 if parentsSenior)`; home-loan interest `min(x, Rs 2L)`; savings interest 80TTA `min(x, Rs 10,000)` (below 60) or 80TTB `min(x, Rs 50,000)` (senior and super-senior, "all deposit interest"); `hraOther` as entered (uncapped).
- Total deductions = `min(afterStd, claimed)`; taxable = `afterStd - deductions` where `afterStd = max(0, gross - std - pensionDed)` and `gross = salary + otherIncome + familyPension + rentNet`.

`RegimeTax` exposes `total = slabTax - rebate + specialTax + surcharge + cess`; `totalIncome = taxable + specialIncome`; `standardDeduction` field = `std + pensionDed`. All tax amounts are rounded to whole rupees (`roundRupee`: round(paise/100)*100).

### 5.2 Income estimation from transactions (`TaxIncome.estimate`)

- Live rows: `!needsReview && duplicateOfId == null`. Period `[from, to]` clipped to `[firstTransactionDay, today]`.
- `months` = months in the clipped period (inclusive); if the period is still running (`end == today && end < to`) and `today.day < lengthOfMonth - 2`, the current month is not counted; clamp 0..12; `estimated = months < 12`.
- Candidate rows: type CREDIT, category != TRANSFER, inside the period.
- Salary: category SALARY and text (merchant + note + upiId) not matching `reimburs|refund|reversal|cashback`; `salarySoFar` = sum; when estimated and any salary exists: `salary = salarySoFar + latestMonthSalary * (12 - months)`.
- Other income: rows with category INCOME, text-classified in this order: excluded words (skip) -> dividend `dividend|\bdiv\b` -> interest `\binterest\b|\bint\.?\s?(pd|paid|cr|credit)\b|\bint\b` (and if also `\bfd\b|fixed deposit|\brd\b|recurring|deposit` it is deposit interest, not savings interest) -> rent `\brent\b` -> other. Each bucket is scaled `v * 12 / months` when estimated. `savingsInterest = interest - depositInterest`. `otherIncome (slab-rate line) = interest + dividends + other`; rent is separate.

---

## 6. Parser pipeline (`parser-core`)

### 6.1 Entry points and stages

Registry `ParserRegistry.parse(body, sender, timestamp, source)` (`PC/registry/ParserRegistry.kt:76-79`): `resolve(sender)` (HashMap by sender key) else the fallback `GenericBankParser` if `canHandle(sender)`; returns null if none. Other registry calls: `accepts(sender)` (SMS pre-filter = known sender or generic bank-looking), `loanStatus(...)` (lender status or FD/RD/PPF status), `cardDue(...)` (card statement / payment notice), `defaultEmailSenders`, `isStatementSubject(subject)`.

`BaseBankParser.parse` pipeline (`PC/bank/BaseBankParser.kt:62-139`):

1. `TextNormalizer.normalize(body)`; for EMAIL, `trimEmail` (cap 3000 chars, cut at first email-footer phrase found at offset >= 40).
2. Reject if `text.length < 20`.
3. `RejectionRules.shouldReject` (6.4).
4. Templates: for EMAIL try email templates then SMS templates; for SMS only SMS templates. First match wins.
5. Amount: template `amt` (+ `cur`), else `AmountExtractor.extract`; none -> null.
6. Type: `TypeClassifier.classify(text, templateType, lower)`; null -> null.
7. Account: template `acct` (last 4 chars) else `AccountExtractor.extract(text, type)`; kind = template kind, else extracted kind, else ACCOUNT. Reference = `ReferenceExtractor.normalize(templateRef ?: extract)`.
8. Drop the message if `last4 == null && reference == null && no template hit` ("almost always marketing").
9. Drop if `DepositParser.aboutDepositOnly(text, last4)` (FD/RD/PPF advice about the deposit itself; it becomes a deposit status via `depositStatus`).
10. `ChannelDetector.detect`. Raw merchant: template merchant/vpa else `MerchantExtractor.extract(text, type, lower)`.
11. If DEBIT and (`TypeClassifier.looksLikeInvestment` or directory category of the merchant == INVESTMENT) -> INVESTMENT.
12. If DEBIT and `CardBill.isBill(text, merchant, vpa)` -> TRANSFER.
13. `MerchantNormalizer.normalize(raw, type, channel, text)` -> display name and category.
14. Balance: template `bal` (signed) else `BalanceExtractor.balance`. For CARD kind: `limit = BalanceExtractor.limit(...)` else the balance when the text says "credit card" and not "debit card" (a credit card's "Avl bal" is a limit). `isDebitCard` = CARD and (text has `debit card|BLOCK DC` or (balance present, no limit, not "credit card")). Stored balance = null for a credit card, else the balance.
15. Time (`resolveTime`): date from `DateTimeExtractor`; ignored if after message date + 1 day or before message date - 45 days (`maxBackdateDays`); with a time in text -> explicit; same day as message -> message timestamp, not explicit; else the date at the message's time of day, not explicit.
16. Confidence: 0.5, +0.15 if last4, +0.15 if reference, +0.10 if merchant name, +0.10 if a template hit; capped 1.0.
17. Hash = `TransactionHasher.hash(amount, type, last4, date(IST), reference)`.

Other pipelines:
- `PaymentAppParser` (bank-name "UPI app"): `FreeTextParser.readNotification` (6.7).
- `LenderParser`: EMI receipts (6.9).
- `GenericBankParser`: same base pipeline, bank name = raw SMS header or capitalised domain label.
- `StatementParser` (PDF/CSV text) for statements, `CardDueParser`, `InvestmentParser`, `MfOrderParser`, `PortfolioSummary` (6.10).

### 6.2 Text normalisation (`PC/text/TextNormalizer.kt`, `Rx.kt`)

- `normalize`: drops zero-width/BOM/soft-hyphen chars and `\r`; collapses runs of spaces/tabs/NBSP; a line break becomes `". "` unless the previous char is one of `.!?:,;` (then a space); currency spellings replaced by `"INR "`: regex `(?:₹|\bRs\.?|\bINR\.?)\s*[:.]?\s*(?=-?\d)`.
- Email footer cut regex (`EMAIL_FOOTER`): `if you (did not|have not|haven't|do not)`, `if this (transaction|txn) (was|is) not`, `in case you have not`, `this is an? (system|computer|auto)`, `please do not reply`, `disclaimer`, `warm regards`, `regards,`, `thank you for banking`, `to unsubscribe`, `never share your`, `for any (queries|query|clarification)`.
- `rx(pattern)` = Java `Pattern.CASE_INSENSITIVE` (ASCII folding). `Guarded(pattern, needles...)` runs a regex only if the lower-cased text contains one of the needles (a performance guard; every possible match must contain a needle).

### 6.3 Sender registry (`registry/`)

- `SenderKeys.candidates(sender)`: for SMS, a single key `smsHeader(sender)`: upper-case, split on `-`, strip non-alphanumerics from each part; if there are >= 2 parts and the first has <= 2 chars (operator prefix like "VM", "AD", "JD") -> the second part, else the first. E.g. "VM-HDFCBK-S" -> "HDFCBK". For email (contains `@`): the address in `<...>` or the whole string, lower-cased, then each domain suffix with at least one dot: `alerts@hdfcbank.net` -> [`alerts@hdfcbank.net`, `hdfcbank.net`]; `x@alerts.sbi.co.in` -> [`...`, `alerts.sbi.co.in`, `sbi.co.in`, `co.in`].
- Registry map: HashMap of `senderKeys` (upper-case SMS headers + lower-case domains); duplicate claims throw at construction. `default()` builds, in order, the 10 core bank parsers, 16 lender parsers, `PaymentAppParser`, then the `IndianBanks` list (each listed bank only gets headers/domains not already taken), fallback `GenericBankParser`.
- `GenericBankParser.canHandle`: last candidate key; for emails the key must contain `bank`; for SMS the header must be in `CARD_ISSUERS` (`AMEXIN AMEXCC INDUSB INDUSL HSBCIN HSBCCC SCBNKS STANCB ONECRD BOBFIN BOIIND SIBSMS PAYTMB SLCEIT UNIONB RBLCRD DBSIND CITIIN IDBIIN FEDSMS`) or match `(?:BK|BNK|BANK|BNKK|CRD)$|BANK|CARD`. Unclaimed senders like "VM-AMAZON" are rejected.

Supported banks with dedicated parsers (`PC/bank/Banks.kt`) and their keys:

| Bank | SMS headers | Email domains |
|---|---|---|
| HDFC Bank | HDFCBK HDFCBN HDFCCC | hdfcbank.net hdfcbank.com hdfcbank.bank.in |
| ICICI Bank | ICICIB ICICIT ICICIO | icicibank.com icici.bank.in icicibank.bank.in |
| SBI | SBIINB SBIUPI CBSSBI ATMSBI SBIPSG SBICRD SBIBNK | alerts.sbi.co.in sbi.co.in sbicard.com sbi.bank.in |
| Axis Bank | AXISBK AXISMR AXISCC | axisbank.com axis.bank.in axisbank.bank.in |
| Kotak Mahindra Bank | KOTAKB KOTAKM KMBLTD | kotak.com kotak.bank.in kotakbank.com |
| IDFC FIRST Bank | IDFCFB IDFCBK | idfcfirstbank.com idfcfirst.bank.in idfcbank.com |
| Yes Bank | YESBNK YESBKK YESBK | yesbank.in yes.bank.in yesbank.bank.in |
| Bank of Baroda | BOBTXN BOBSMS BOBCRD BOBCMS | bankofbaroda.com bankofbaroda.co.in bobcard.co.in bankofbaroda.bank.in |
| Punjab National Bank | PNBSMS PNBBNK PUNBNK | pnb.co.in pnb.bank.in pnbindia.in |
| AU Small Finance Bank | AUBANK AUSFBL AUBNKK | aubank.in au.bank.in |

Listed banks with no templates (`PC/bank/IndianBanks.kt:19-77`, shared extractors only): Central Bank of India, Bank of Maharashtra, Canara Bank, Union Bank of India, Bank of India, Indian Bank, Indian Overseas Bank, UCO Bank, Punjab & Sind Bank, IDBI Bank, IndusInd Bank, Federal Bank, South Indian Bank, Karur Vysya Bank, City Union Bank, CSB Bank, DCB Bank, Tamilnad Mercantile Bank, Jammu & Kashmir Bank, Dhanlaxmi Bank, Nainital Bank, Karnataka Bank, RBL Bank, Bandhan Bank, Equitas SFB, Ujjivan SFB, Jana SFB, Suryoday SFB, Utkarsh SFB, ESAF SFB, Capital SFB, HSBC, Standard Chartered, Citibank, DBS Bank, Paytm Payments Bank, Airtel Payments Bank, India Post Payments Bank, Fino Payments Bank, Jio Payments Bank, Nagrik Sahakari Bank, Saraswat Bank, Cosmos Bank, SVC Bank, Abhyudaya Bank, TJSB Sahakari Bank, Bharat Co-operative Bank, Kalupur Commercial Co-operative Bank, NKGSB Co-operative Bank, Janata Sahakari Bank, Apna Sahakari Bank. (Each carries 2-12 headers and 1-3 domains; read the file for the full code list.)

Lenders (`Lenders.ALL`, `PC/bank/LenderParser.kt:40-61`; every account at these banks is auto-typed LOAN): Propelld (PROPLD PRPLDF PROPEL PRPELD PRPLDS; propelld.com), Aditya Birla Capital (ABCLTD ABCFIN ABCAPL ABCDAP ADBIRL ABFLTD ABHFLT; adityabirlacapital.com, abcd.adityabirlacapital.com), Bajaj Finance (BAJAJF BAJFIN BAJAJL BFLEMI; bajajfinserv.in, bajajfinance.in), Tata Capital (TATACP TATCAP TCLOAN; tatacapital.com), HDFC Credila (CREDLA CREDIL HCREDL; credila.com, hdfccredila.com), Avanse (AVANSE AVNSFS; avanse.com), InCred (INCRED INCRDF; incred.com), SMFG India Credit (SMFGIN SMFGIC FULRTN FULTON; smfgindiacredit.com, fullertonindia.com), Home Credit (HOMECR HCINDA HMCRDT; homecredit.co.in), KreditBee (KRDBEE KBEEIN KREDTB; kreditbee.in), Navi (NAVIFN NAVILN NAVIAP; navi.com), Poonawalla Fincorp (POONAW PFLTDL PFLLON; poonawallafincorp.com), HDB Financial (HDBFSL HDBFIN HDBFSS; hdbfs.com), L&T Finance (LTFINC LNTFIN LTFSMS; ltfs.com), Hero FinCorp (HEROFC HEROFN; herofincorp.com), Cholamandalam Finance (CHOLAF CHOLAL; chola.murugappa.com), Mahindra Finance (MMFSLT MAHFIN MMFINL; mahindrafinance.com).

Payment apps (`PaymentAppParser`, `PC/bank/PaymentAppParser.kt`): SMS headers PHNEPE PHONPE PHONEP CREDCL MOBIKW; email domains `phonepe.com, noreply@phonepe.com, googlepay-noreply@google.com, payments-noreply@google.com, noreply-payments@pay.google.com, pay.google.com, paytm.com, paytm.in, cred.club, mobikwik.com, amazonpay.in, freecharge.in, super.money`. App name from the sender substring (PhonePe, Google Pay, Paytm, CRED, MobiKwik, Amazon Pay, Freecharge, super.money, else "UPI app").

Email whitelists (`ParserRegistry.STATEMENT_SENDERS`, 100+ domains: CAMS, KFintech, NSDL, CDSL, brokers, EPFO, card issuers, lenders, MF platforms) and `STATEMENT_SUBJECTS`/`isStatementSubject` regex (CAS, NPS, PRAN, EPF passbook, SIP instalment/processed, units allotted, statement of transactions, holdings, portfolio, FD/RD/term deposit, deposit advice, PPF statement, portfolio summary) are listed in `PC/registry/ParserRegistry.kt:87-122`.

Bank-specific templates (`Template(pattern, type?, kind?)`, named groups `amt, cur, acct, merchant, vpa, ref, bal`; `AMT = \d[\d,]*(?:\.\d{1,2})?`). Representative ones (all in `PC/bank/Banks.kt`):
- HDFC SMS: `Sent\s+INR\s*(?<amt>AMT)\.?\s+From\s+HDFC\s+Bank\s+A/C\s+[x*]*(?<acct>\d{4})\.?\s+To\s+(?<merchant>.+?)\.?\s+On\s+\d{2}/\d{2}/\d{2}\.?\s+Ref\s+(?<ref>\d{9,14})` (DEBIT); `NEFT\s+Cr-[A-Z]{4}0[A-Z0-9]{6}-(?<merchant>[^-]+?)-[^-]*-(?<ref>[A-Z0-9]{12,22})`. HDFC email: credit-card "ending (\d{4}) for INR ... at <merchant> on" (CARD) and "has been debited from account ... to VPA <vpa> <merchant> on".
- ICICI SMS: `Acct\s+XX(?<acct>\d{3,4})\s+debited\s+(?:for|with)\s+INR\s*AMT\s+on\s+[\w-]+;\s*(?<merchant>.+?)\s+credited\.\s*(?:UPI|IMPS|RRN)\s*:?\s*(?<ref>\d{9,14})`; card: `INR AMT spent (using|on) ICICI Bank Card XX(\d{4}) on <date> on <merchant>.`.
- SBI SMS: `A/C\s+X(\d{4})\s+debited\s+by\s+AMT\s+on\s+date\s+\S+\s+trf\s+to\s+<merchant>\s+Refno\s+(\d{9,14})`; credit: `A/c X(\d{4})-credited by INR AMT on \S+ transfer from <merchant> Ref No (\d{9,14})`.
- Axis SMS (new): `Spent INR AMT. Axis Bank Card no. XX(\d{4}). <date> <time> IST. <merchant>. Avl (Credit )?Limit`; old: `Spent. Card no. XX(\d{4}). INR AMT. <d> <t>. <merchant>. Avl`.
- Kotak SMS: `Sent INR AMT from Kotak Bank AC X(\d{4}) to <vpa> on [\d-]+. UPI Ref (\d{9,14})`; `Received INR AMT in your Kotak Bank AC X(\d{4}) from <vpa> on`.
- IDFC SMS `debited by INR AMT on \S+ for (UPI txn|IMPS|NEFT) to <merchant>.`; Yes, BoB (`INR AMT Dr. from A/C ... and Cr. to <vpa>.`, `Cr. to A/C ... from <vpa>`, `spent on your BOBCARD ending`), PNB (`debited INR AMT on \S+ by (UPI|IMPS) Ref (\d{9,14}) to <merchant>.`), AU (`INR AMT debited from AU Bank A/c XX.. on \S+ via (UPI|IMPS|NEFT) to <merchant>.`). Plus issuer-specific "Credit Card ending NNNN for INR X at <merchant> on" email templates for HDFC, SBI, Axis, Kotak, IDFC, Yes, BoB, PNB, AU.

### 6.4 Rejection rules (`PC/rules/RejectionRules.kt:10-91`)

`reasonFor(text, lower)` returns the first matching reason, in this order (null = may be a transaction):

1. `otp`: OTP word (`otp|one[\s-]time[\s-]password|verification\s+code|security\s+code|passcode`) AND (OTP_CODE pattern like `(?:otp|code|password)\s*(?:is|:|-)?\s*\d{4,8}`, `\d{4,8} is your otp`, `(otp|code) for`, `use (otp )?\d{4,8}`, `(otp|code).{0,100}?is\s*:?\s*\d{4,8}` OR no past-tense movement word (`debited|credited|spent|withdrawn|deposited|received|sent|paid|deducted|transferred|refunded|reversed|charged|(has been|was) used`)).
2. `failed`: `failed|failure|declined|unsuccessful|not successful|could not be (processed|completed)|(has been|was|is) rejected|insufficient (funds|balance|bal)|incorrect pin|invalid pin|returned unpaid|dishonou?red|bounced`, unless the text has both a reversal word (`reversed|refunded|reversal|refund`) and `credited`.
3. `future`: `will be (auto-)?(debited|deducted|charged|credited|processed|presented|paid|transferred)`, `is scheduled`, `scheduled for|on`, `upcoming`.
4. `mandate`: e-mandate/autopay/standing instruction/e-NACH within 80 chars of registered/created/set up/activated/approved/revoked/cancelled/modified/paused, or "set up/created/registered/activated (an|your) mandate".
5. `collect`: `has requested|requested (money|INR|payment)|collect request|payment request`.
6. `promo`: `pre-approved|apply now|you are eligible|eligible for|avail (now|the offer)|get up to|limited-period|exclusive offer|special offer|click here|congratulations`.
7. `reminder`: `is due|due (on|by|date)|payment due|(amount|amt) due|min(imum) (amount|amt)|overdue|bill (is )?generated|statement (is )?(generated|ready)|statement for|pay now|payment reminder|gentle reminder|reminder`, unless the text also has `debited|credited|spent|withdrawn|deposited|received`.
8. `balance`: `(available|avl|avbl|account|a/c|closing|ledger) bal(ance) ... (is|:) (rs|inr|₹)` when, after removing "if you ..." clauses, the text has no past-tense movement and none of `using|used|purchase|transaction|txn|payment`.

Lender parsers treat `future`, `reminder` and `balance` as "soft" (they still yield a loan status). Card due/statement messages are rejected as transactions by rule 7 but read separately by `CardDueParser`.

### 6.5 Field extractors (`PC/extract/`)

Amount (`AmountExtractor`): first `\b(INR|USD|EUR|GBP|AED|SGD|AUD|CAD|JPY|CHF|SAR|QAR)\s*(\d[\d,]*(?:\.\d{1,2})?)` not preceded within 45 chars by `(bal(ance)?|lmt|limit|due|outstanding)\b[^0-9]{0,30}$`; fallback `\b(?:debited|credited)\s+(?:by|for|with)\s+(number)`. `Money.parse`: strips commas, rounds HALF_UP to 2 decimals, must be >0 and <= 1,000,000,000,000 paise (Rs 10,000 crore).

Balance: `(?:\b|(?<=avl)|(?<=avbl))bal(?:ance)?\b[^0-9]{0,40}?\b(?:INR)\s*(-?\d[\d,]*(?:\.\d{1,2})?)` (signed). Limit: `\b(?:lmt|limit)\b[^0-9]{0,30}?\bINR\s*(\d[\d,]*(?:\.\d{1,2})?)`.

Account (`AccountExtractor`):
- Labelled: `(?:\b(a/c|ac|acct|account)|(card))(?:\s*(?:no|number|num)\.?)?(?:\s*(?:ending|ends)(?:\s+(?:with|in))?)?\s*[:.\-]?\s*(?:\d{0,6}[x*#.][x*#.\s]*)?(\d{3,6})\b` (last 4 of the digits; CARD when the word "card" is the label or appears 15 chars before).
- Bare masked: `(?<![\w*])[x*]{2,}(\d{3,4})\b` (kind CARD if the text contains "card").
- Short ending (2 digits): `\b(card|a/c|ac|acct|account)(?:\s*(?:no|number|num)\.?)?\s+(?:ending|ends)(?:\s+(?:with|in))?\s*[x*]*(\d{2})\b`.
- A candidate is rejected if it is a phone/VPA (digits followed by `^[\w.\-]*@[a-z]`, or a bare mask preceded within 30 chars by mobile/phone/registered/upi id/vpa/+91 words), or it is the other party: preceded by `benef...|payee|recipient|in favour of`, or by "to" (debit/transfer) / "from|by|remitter|sender" (credit) within 2 words, unless qualified `your|ur|own|self`. First surviving candidate wins; labelled before masked before short.

Type (`TypeClassifier`, `PC/extract/TypeClassifier.kt`):
- TRANSFER regex (Guarded): `payment .{0,60}? received .{0,60}? card`, `received (your )?payment .{0,70}? card`, `payment .. (credited|posted|reflected) .. credit card`, `credit card .. payment .. (credited|posted|reflected|received)`, `thank you for (your|the)? payment`, `self[ -]transfer`, `own account`, `between your (own )?accounts`, `towards (your )?(<up to 3 words>) credit card`, `(credit card|cc) (bill )?payment`, `card bill`. TRANSFER wins even over a template hint.
- Hint type from a template wins next.
- OUTGOING (payee-side wording read as debit): `credited (in)?to (the )?(beneficiary|benef\w*|bene|payee|recipient)`, `credited to <name>'s (a/c|acct|account|bank)`, `transfer of INR x to (a/c|acct|account|beneficiary)`, `transfer ... to (a/c|...) ... success`, `(sent|transferred|remitted) to (a/c|acct|account|beneficiary|benef|payee)`.
- DEBIT verbs: `debited|debit (by|for|of|alert)|spent|withdrawn|withdrawal|paid|sent|purchased?|deducted|charged|transferred to|txn of|used (for|at|on)|thank you for using|(transaction|trxn|txn) (of )?(INR|USD|EUR|GBP|AED|SGD)|transaction alert on (your )?(<=4 words) card|made a (transaction|purchase|payment)`. CREDIT verbs: `credited|credit (by|of|alert|with)|received|deposited|refund(ed)?|reversed|reversal`. The earlier verb wins (credit searched only up to 12 chars past the first debit start).
- Investment keywords (`looksLikeInvestment`): `mutual fund|MF|SIP|zerodha|groww|upstox|kuvera|iccl|indian clearing|nse clearing|clearing corp|cams|kfin(tech)?|smallcase|angel one|paytm money|ppf|nps`.
- Channel (`ChannelDetector`, priority): ATM (`\bATM\b|cash withdrawal|\bwithdrawn\b`) > AUTO_DEBIT (`ACH|NACH|ECS|mandate|auto[ -]?pay|standing instruction`) > UPI (`\bUPI\b|\bVPA\b|@(okaxis ... ybl ibl axl paytm upi icici hdfcbank sbi axisbank apl ptyes ptsbi pthdfc ptaxis kotak idfcbank)`) > IMPS > NEFT > RTGS > CARD (text contains "card") > OTHER.

Reference (`ReferenceExtractor`): slashed `(UPI|IMPS|NEFT|RTGS)/(<2-4 alnum>/)?([A-Z0-9]{9,22})/`; labelled `UPI transaction reference (no|number)`, `(UPI|IMPS|NEFT|RTGS)( Ref...)?( No|Number|ID)?`, `RRN`, `UTR( No)?`, `Refno`, `Ref(erence)?( No|Number|ID|#)?`, `(Txn|Trxn|Transaction) (ID|No|Number|Ref)` followed by `[:.\-#]? \(?([A-Z0-9]{6,22})`; a value needs at least 5 digits (else retry from the next char). Normalised: alphanumerics only, upper-case, length >= 6.

Date/time (`DateTimeExtractor`): ISO `(20\d{2})[-/:](\d{1,2})[-/:](\d{1,2})(?:[\sT:]+hh:mm(:ss)?)?`, DMY `d[-/.]m[-/.](yyyy|yy)`, `d-Mon-yy(yy)` (month names jan..dec, optional trailing letters), `Mon d, yyyy`; the earliest date in the text wins; years 2000..2099; time = ISO's, else the first `hh:mm(:ss)? (am|pm)?` within 30 chars after the date, else the first time anywhere. 2-digit years are 20xx.

Merchant (`MerchantExtractor`, order): `SLASHED` (`UPI/P2M/<ref>/<name>`), `VPA_WITH_NAME` (`to|from|by VPA <vpa> <name>`), `BENEFICIARY` (`beneficiary(name)?:`); then for CREDIT: `FROM` (from|by), `INFO` (`Info: ...`), VPA, `ACH`; for DEBIT/other: `AT`, VPA, `INFO`, `ACH`, `TO` (trf to|transferred to|paid to|sent to|to), `TOWARDS`; then `DATE_ON` ("... 05-Oct-26 on SWIGGY"), then `AFTER_DATE` (merchant on its own sentence after a date, no 5+ digit run). `BODY = [A-Z0-9][A-Z0-9 &'*_\-/@.]{0,50}?`, ended by a lookahead of connector words or punctuation; names that begin with your/you/the/a/c/ac/card/mobile/vpa/neft/imps/upi/inr etc. are skipped (`NOT_A_NAME`). A candidate must be >= 2 chars, contain 2+ letters and not be a UI phrase (`GenericPhrases`: view details, click here, pay now, track order, ... 30 phrases).

### 6.6 Merchant normalisation and category inference

`MerchantNormalizer.normalize` (`PC/merchant/MerchantNormalizer.kt:32-53`):

1. `channel == ATM && type == DEBIT` -> merchant "ATM", category CASH.
2. Clean the raw name (`clean`): upper-case; if it contains `@` treat as VPA; strip glued order numbers (`^([A-Z]{3,}?)(?:IND|INDIA|IN)?\d{4,}$`, e.g. UBERIND13513699 -> UBER) unless it is an IFSC (`[A-Z]{4}0[A-Z0-9]{6}`); split on `/`, `|` and (when a part looks like a code) `-`; take the first segment that is not code-like (`^(?:.*\d{4,}.*|IFSC|[X*\d\s]+|P2[AMP]|[A-Z]{2}\d+)$`) and not only noise words; replace non `[A-Z0-9&' ]` with spaces; drop leading noise prefixes (`ACH NACH ECS TP D DR CR UPI IMPS NEFT RTGS POS VPA MMT BIL INF TO FROM BY SI MANDATE AUTOPAY PAYMENT TXN TRF TRANSFER PAY CMS ATD ONL VIN`) and trailing noise suffixes (`PVT LTD PRIVATE LIMITED LLP INC CO UPI PAYMENTS PAYMENT`, only while more than 1 word remains); result needs >= 2 chars and a letter.
3. VPA to name: local part split on `. _ -`, dropping noise words (`UPI PAY PAYTM RAZORPAY RZP BHARATPE PAYU CASHFREE MERCHANT OKAXIS OKICICI`) and trailing digits, words >= 2 chars.
4. Directory lookup (`MerchantDirectory`, ~120 entries): multi-word keys match as phrases (longest first), single-word keys must equal a token ("OLA" does not match "COCA COLA"). Display = directory name else Title Case (keep-upper set: ATM IRCTC LIC KFC HP BP SBI HDFC ICICI IDFC PNB AU NSE BSE).
5. Category: TRANSFER -> TRANSFER; INVESTMENT -> INVESTMENT; CREDIT -> SALARY if text has `SALARY|SAL CR|PAYROLL`, REFUND if text contains "refund" or "revers", else INCOME; otherwise directory category; otherwise keyword category (`categoryByKeyword`); otherwise OTHER.

Directory highlights (name -> category): FOOD (Swiggy, Zomato, EatSure/Faasos, Domino's/Jubilant, McDonald's, KFC, Starbucks, Haldiram's); GROCERIES (Swiggy Instamart, BigBasket, Blinkit/Grofers, Zepto, DMart, JioMart); TRANSPORT (Uber, Ola/ANI Technologies, Rapido, BluSmart, Namma Yatri, Meru, FASTag, Metro/DMRC/BMRCL); FUEL (HPCL, BPCL, Indian Oil); SHOPPING (Amazon, Flipkart, Myntra, AJIO, Meesho, Nykaa, Croma, Decathlon, IKEA, Aditya Birla Fashion); BILLS (Airtel, Jio, Vi, BSNL, Electricity (BESCOM/Tata Power/Adani/MSEDCL/TNEB), Tata Play); ENTERTAINMENT (Netflix, Spotify, JioHotstar, Prime Video, BookMyShow, PVR INOX, YouTube); TRAVEL (IRCTC, MakeMyTrip, Goibibo, Cleartrip, IndiGo, Air India, redBus, OYO, ixigo); HEALTH (Apollo, PharmEasy, Tata 1mg, Netmeds, MedPlus, cult.fit); EDUCATION (Udemy, Coursera, Unacademy); INVESTMENT (Zerodha, Groww, Upstox, Kuvera, ICCL, smallcase, Aditya Birla Sun Life MF, Tata Securities, Tata Mutual Fund); INSURANCE (LIC, Policybazaar, Acko, HDFC Ergo, ICICI Lombard, Star Health, Niva Bupa, Care Health, Aditya Birla Health, ManipalCigna, Tata AIG, Bajaj Allianz, Digit, Reliance General, New India Assurance, Axis Max Life, HDFC Life, SBI Life, ICICI Prudential Life, Tata AIA, Kotak Life, ABSLI); EMI_LOAN (Bajaj Finance, Propelld, Aditya Birla Capital, Tata Capital, HDFC Credila, Avanse, InCred, SMFG India Credit, Home Credit, KreditBee, Navi, Poonawalla Fincorp, HDB Financial, L&T Finance, Hero FinCorp, Cholamandalam, Mahindra Finance; names match the lender parsers so EMI debits link to loans); RENT (NoBroker). Keyword fallback tokens: FOOD (RESTAURANT CAFE PIZZA BURGER BIRYANI BAKERY FOODS KITCHEN DHABA SWEETS), GROCERIES (SUPERMARKET GROCERY GROCERIES MART KIRANA FRESH), FUEL (PETROL FUEL FUELS PETROLEUM), TRANSPORT (CAB CABS TAXI PARKING TOLL), HEALTH (HOSPITAL CLINIC PHARMACY MEDICAL MEDICALS CHEMIST DIAGNOSTICS LAB LABS), EDUCATION (SCHOOL COLLEGE UNIVERSITY ACADEMY TUITION FEES), BILLS (ELECTRICITY RECHARGE BROADBAND BILL BILLDESK GAS WATER DTH), TRAVEL (HOTEL HOTELS AIRLINES AIRWAYS TRAVELS TOURS RAILWAY), INSURANCE (INSURANCE PREMIUM), EMI_LOAN (EMI LOAN FINANCE), RENT (RENT), INVESTMENT (MUTUAL SIP MF SECURITIES BROKING CAPITAL), ENTERTAINMENT (MOVIES CINEMA CINEMAS GAMING).

Card-bill recognition (`PC/rules/CardBill.kt`): text regex (credit card/cc + bill|dues|payment|pymt|repayment|outstanding; "card bill/dues payment"; "towards (your) ... credit card"; "to <not your> ... credit card xxNNNN"; `<bank list> (bank)? (credit)? card (bill|payment|pymt|dues)`; "bank ltd credit card"; `axiscc|hdfccc|...`; `billdesk|bbps|bil` + cc/credit card; "cred club", "dreamplug"); payee-name regex (e.g. "<issuer> credit card", "sbi card(s)", "cred", "dreamplug"); UPI-id tokens (`creditcard cardpayment cardpay ccpay ccbill cardbill ccpayment axiscc hdfccc icicicc sbicc kotakcc idfccc yescc rblcc indusindcc amexcc aucc sbicard credclub`, bare `cc` only beside an issuer, `cred.club`). A payee match is ignored on a card's own debit (a card cannot pay its own bill). Bank list: axis hdfc icici sbi kotak idfc yes rbl indusind amex citi hsbc au bob pnb federal "standard chartered" sc. Label: "Credit card bill".

### 6.7 Account / type inference at ingest (`SH/repo/AccountGuess.kt`)

New account type guess from message text (case-insensitive):
- CARD: debit-card flag -> DEBIT_CARD; `(prepaid|forex) card` -> PREPAID_CARD; `credit card` or has available limit -> CREDIT_CARD; else null.
- ACCOUNT: lender bank -> LOAN; `(RD|recurring deposit) (a/c|account|ac|no)` -> RD; `(FD|fixed deposit|term deposit|deposit) (a/c|account|ac|no)` -> FD; `PPF (a/c|account|ac)` -> PPF; `loan (a/c|account|ac)` -> LOAN; else null.
- Network (cards only): rupay, visa, `master\s*card`, `amex|american express`, diners.
Account creation rules (`ensureAccount`, repo 296-315): no last4 -> no account; APP-source rows never create an account (they match an existing one by exact bank+last4, or by digits with a unique same-kind bank-prefix match, `existingAccountOf` 286-293); a new account is not created when its last4 is in `phoneLast4s` (the user's own phone-number tails) unless forced; `INSERT IGNORE` on the unique `(bankName, last4)`. An existing untyped account gets DEBIT_CARD (if debit card) or LOAN (if lender).

### 6.8 Category taxonomy (full)

`Category` enum (`PC/model/Model.kt:53-81`, enum name -> label): FOOD "Food & Dining", GROCERIES "Groceries", TRANSPORT "Transport", FUEL "Fuel", SHOPPING "Shopping", BILLS "Bills & Utilities", ENTERTAINMENT "Entertainment", TRAVEL "Travel", HEALTH "Health", EDUCATION "Education", RENT "Rent", INSURANCE "Insurance", EMI_LOAN "EMI & Loans", INVESTMENT "Investment", CASH "Cash Withdrawal", SUBSCRIPTIONS "Subscriptions", PERSONAL_CARE "Personal Care", HOUSEHOLD "Household", GIFTS "Gifts", DONATIONS "Donations", TAXES "Taxes", FEES "Bank Fees & Charges", SALARY "Salary", INCOME "Income", REFUND "Refund", TRANSFER "Transfer", OTHER "Other".

Subcategories (`SH/insight/Subcategories.kt`): built-in list per category, matched by regex against `"<merchant> <upiId>"` (first sub whose regex matches wins; case-insensitive). Subcategory used = the user's saved one, else the guess, else the category's single no-pattern subcategory, else "Other". Catalog:

- FOOD: Food delivery, Cafes & coffee, Fast food, Bakery & desserts, Bars & nightlife, Restaurants
- GROCERIES: Quick commerce, Supermarket, Dairy, Fruits & vegetables, Kirana
- TRANSPORT: Cabs & rides, Metro & bus, Parking & tolls, Vehicle service
- FUEL: Petrol & diesel, EV charging, CNG
- SHOPPING: Online shopping, Fashion, Electronics, Home & furniture, Sports & fitness gear, Books & stationery
- BILLS: Mobile recharge, Electricity, Broadband & DTH, Gas cylinder, Water, Society maintenance
- ENTERTAINMENT: Movies, Events & shows, Gaming, Outings
- TRAVEL: Cabs, Flights, Trains, Hotels & stays, Bus, Travel booking
- HEALTH: Medicines, Doctor & hospital, Lab tests, Fitness, Personal care, Eye care
- EDUCATION: Courses & coaching, School & college fees, Books
- RENT: House rent, PG & hostel
- INSURANCE: Life insurance, Health insurance, Vehicle insurance
- EMI_LOAN: Home loan, Car loan, Education loan, Card EMI, Personal loan
- INVESTMENT: Mutual funds, Stocks, PPF/EPF/NPS ("PPF, EPF & NPS"), FD & RD, Gold
- SUBSCRIPTIONS: Streaming, Music, Cloud & apps, News & reading, Memberships
- PERSONAL_CARE: Salon & spa, Cosmetics & skincare
- HOUSEHOLD: Home services, Domestic help, Laundry, Home supplies
- GIFTS: Flowers & cakes, Gifts (no pattern)
- DONATIONS: Religious, Charity (no pattern)
- TAXES: Income tax, GST, Property tax
- FEES: Interest & late fees, Card fees, Bank charges (no pattern)
- CASH: ATM withdrawal (no pattern)
- No subcategories: SALARY, INCOME, REFUND, TRANSFER, OTHER (always "Other").

Each sub has an icon key (Material-style names such as `delivery_dining`, `local_cafe`, `fastfood`, `bolt`, `local_taxi`, `local_gas_station`, `shopping_bag`, `smartphone`, `movie`, `flight`, `medication`, `school`, `home`, `favorite`, `pie_chart`, `live_tv`, `receipt_long`, `atm`, ...) and a regex; the full regex per subcategory is in the file (lines 18-147); examples: Food delivery `swiggy|zomato|uber\s*eats|eatsure|box8|faasos|rebel\s*foods|magicpin`; Cabs & rides `\buber\b|\bola\b|olacabs|ani\s*technologies|rapido|roppen|blusmart|meru|namma\s*yatri`; Income tax `income\s*tax|\bitd\b|\btds\b|advance\s*tax|incometax`. Custom categories and subcategories live in `custom_categories` / `custom_subcategories`.

### 6.9 Free-text, payment-app, lender, deposit, card-due, investment parsers

Payment-app notification (`FreeTextParser.readNotification`, `PC/FreeTextParser.kt:83-128`): split every text field on newlines/bullets and sentence ends, normalise, de-duplicate; skip with reason strings, in order: `too short` (< 8 chars), `otp or security text` (`otp|one-time pass|verification code|cvv|upi pin|pin`), `failed or pending payment` (`fail*|declined|unsuccessful|not successful|couldn't|cancel*|rejected|reversed|pending|processing|in progress|refund initiated/in progress|will be refunded/credited|timed out|on hold|bank server|try again`), `request, reminder or due notice` (`requested|payment request|collect request|remind*|due|overdue|expir*|valid till|bill generated|scheduled|upcoming|will be debited|set up autopay`), `offer or promotion` (sentences dropped for promo words: cashback/reward/scratch/offer/coupon/voucher/won/win/claim/referral/earn/bonus/discount/`get up to`/lucky/spin/N points/N%/`N off`/`flat Rs`; UI text starting view/tap/know/check/...; calls to pay "Pay now", "Recharge now", "Pay Rs N"), `no payment wording` (needs a `SIGNAL`: credit = sent/paid you, received, credited, refund processed/credited, money received, payment received; debit = paid, sent, debited, spent, transferred, deducted, charged, purchased, money sent, "payment ... successful/done/completed/made/sent", "recharge/bill ... successful/paid"), `no amount`, `own transfer or card bill` (transfer wording that is not a recognised card bill). Balance tails (`avl bal ...`) are cut. A bare "paid 250" gets "INR" inserted. Payee/payer extraction regexes: `to <name>`, `at <name>`, `paid <name> INR`, `from <name>`, `<name> (has )?(sent|paid) you`; UTR `\b(utr|rrn|upi ref(erence)?( no|id)?)\W{0,4}(\d{10,22})\b` beats the app's own transaction id; bill-kind labels (electricity/water/gas/broadband/postpaid/mobile/dth/phone/internet/insurance bill; recharge). Output `ParsedTransaction` with `confidence = 0.55`, `bankName` = bank named in the text (HDFC, ICICI, SBI, Axis, Kotak, IDFC, Yes, BoB, PNB, AU, IndusInd, Federal, Canara, Union, HSBC, RBL) else the app name; time = posted time, never explicit. UPI apps set Channel.UPI if nothing else is detected.

`FreeTextParser.draft` (screenshots): same extractors, no sender; amount required, type may be null; date in the text must not be > 1 day after `now`.

Lender (`LenderParser`): an EMI receipt = DEBIT on the loan account, category EMI_LOAN, merchant = lender name, `confidence 0.9` (0.7 without loan number). Requires a "paid" pattern (`(EMI|instalment|repayment|payment|INR x).{0,80}? (received|paid|debited|deducted|collected|realised|cleared)` etc.) and no disbursal word; EMI amount from `(EMI|instalment|repayment|payment) (amount)? (of|:)? INR x`, else the first `INR x` not preceded within 40 chars by outstanding/principal/balance/POS/loan of/sanction/disburs/limit/overdue/charges. Loan number `loan (a/c|account|id|no|number)`, `LAN`, `agreement`, `contract`, `for|towards|on|against (your) loan <num>`; last4 of the number (digits only after an `X` mask, minimum 3). Outstanding (`outstanding|balance principal ... INR x`, `POS ... INR x`) goes into `balanceMinor`. Status (`LoanStatus(lender, last4, principal, outstanding, at, deposit?)`) for reminders, future debits and disbursals (disbursal: principal = `loan of INR x`, `INR x ... disburs*`, `disburs* ... INR x`).

Deposits (`DepositParser`): FD/RD/PPF numbered by `(PPF|public provident fund)`, `(RD|recurring deposit)`, `(FD|FDR|fixed deposit|term deposit|TD|SDR|MIS)` followed by an account number with 3+ digits (last 4, or digits after the X mask); needs a context word (booked, opened, created, placed, renewed, maturity, balance, interest, instalment, deposited, credited, received, closed, liquidated); not OTP/failed/offer/"book now"/loan against/overdraft. Fields: maturity date (`matur... (date) ... <date>`), maturity amount, rate `(@|at|rate ...)(\d{1,2}(\.\d{1,2})?)%` accepted in 0.5..20.0 as bps, action (renew all / renew principal when interest paid out / payout / null), closed (`has been matured|closed|prematurely closed|liquidated|redeemed`, "matured ... credited", "proceeds ... credited", PPF "account closed"). FD outstanding = principal (first INR amount not labelled maturity/interest/balance/proceeds/limit/penalty/charges), RD/PPF outstanding only from a stated balance. Bank name "India Post" for `DOP|IPPB|INDPST|INDPOS|POSTAL` headers.

Card due (`CardDueParser.parse`, `PC/statement/CardDue.kt:127-152`): requires the word "card"; `last4` from `(?:[x*]{2,}[\s-]?|ending (with|in|no)?|no.?|number )(\d{4})` (empty if only a product name); issuer from sender or text (HDFC, ICICI, SBI, Axis, Kotak, IDFC, Yes, IndusInd, Amex, HSBC, RBL, AU, Federal, Standard Chartered). Min due `min(imum) (amt|amount|payment)? (due|payable) ... <amt>`; total due `total (amount|amt|payment)? (due|payable|outstanding)` / `amount due|payable` / `total amt` (not followed by due) / `total dues` / `new balance` / `outstanding balance|amount` / `bill amount`; due date `(due date|due on|due by|pay by|payable by|on or before) <date>`; statement date `(statement|bill) (dated|date|generated on|generated for|of) <date>`; a statement notice needs a total or min, the word statement/bill/due, and (total or due date). Otherwise, unless it says failed, a payment acknowledgement `payment of Rs X ... (received|credited|posted|successful|made|paid)` etc. with a last4. Dates without a year take the year nearest the message date (due dates: pushed forward when 30+ days behind; statement dates: pulled back when 30+ days ahead).

Investments (`InvestmentParser`, `MfOrderParser`, `PortfolioSummary`, `EpfPassbook`, `NpsStatement`, `Holding*`): SMS senders accepted by `InvestmentParser.accepts`: EPFO*, EPFIND, UMANGB, anything with NPS or PRAN, PFRDA*, plus CRA headers `NSDLPR NSDLCR NSDLNP PROTEN PRTEAN PROTNC KFINTN KFNCRA KFCRA KCRA KCRANP CAMSNP CAMSCR`. EPF: `passbook balance against <member id> is INR x`; contribution `contribution of INR x ... received|credited|deposited`; identifier `EPF:<member id, alphanumerics upper>`, default `EPF:default`. NPS: value `PRAN ...(\d{4}) ... (holding|balance|value|corpus) ... INR x` or reversed; identifier `NPS:<last4>` or `NPS:<last4>:T2`; contributions need NPS/PRAN context and a done word (credited/allotted/received/...) and none of failed/pending/reminder/will be/...; key `nps|<pran4>|<tier>|<date>|<amount>` deduplicates SMS+email via a SharedPreferences set (max 500). MF orders: SIP/purchase confirmations with scheme/amount/units/NAV/folio/date, rejecting reminders, failures, redemptions; identifier `MF:<normalised scheme>` (lower-case, stop words direct/plan/growth/option/fund/... removed). Statement PDFs: see `StatementParser` (below). Password guessing: `PasswordGuesser` (PAN, NAME(4 letters)+DDMM, DOB forms, phone fragments, card last4 combos; max 240, 300 with bank details).

Statements (`PC/statement/StatementParser.kt`): rows are lines starting with a date and containing an amount; card rows: spend unless CARD_PAYMENT words (`payment received|thank you|bbps payment|autopay|auto debit payment|neft payment|payment -`) -> TRANSFER, or Cr; bank rows: last two amounts = (amount, balance); direction by `Cr/Dr`, else balance up/down vs previous balance, else credit words (`refund|reversal|reversed|cashback|credit|interest credit|salary|neft cr|imps cr|by transfer|deposit`). Time is noon IST on the statement date (`hasExplicitTime = false`), source STATEMENT, confidence 0.7, hash with null reference. Summary extraction labels: total due, min due, due date, credit limit, statement date, statement period, cash limit, available limit, opening, closing, debits, credits balances (handles header-row/values-row, one-label-per-line, label|value pipes). Statement kinds: CREDIT_CARD, BANK, INVESTMENT, OTHER. Deposit advices (PPF, RD, FD) yield `LoanStatus` deposit info, not transactions. Holdings: ISIN lines (`[A-Z]{2}[A-Z0-9]{9}\d`), CAMS "Closing Unit Balance", NSDL/CDSL tables, Groww-style ISIN-less tables, EPF passbook, NPS statement, spreadsheet tables (`HoldingSheet`, `¦` cell separator).

### 6.10 Model summary

`ParsedTransaction` fields: `amountMinor, currency, type, bankName, accountLast4, accountKind, merchant, upiId, referenceNumber, channel, balanceMinor, availableLimitMinor, transactionTime, hasExplicitTime, category, source (SMS|EMAIL|APP|SCREENSHOT|MANUAL|STATEMENT), sender, messageTimestamp, confidence, transactionHash, isDebitCard`. `TransactionType.direction`: DEBIT and INVESTMENT -> "OUT", CREDIT -> "IN", TRANSFER -> "XFER".

---

## 7. Deduplication (exact)

### 7.1 Hash

`TransactionHasher.hash(amountMinor, type, accountLast4, date, referenceNumber)` (`PC/hash/TransactionHasher.kt:17-34`):

```
key = "<amountMinor/100>.<amountMinor%100 zero-padded to 2>"   // e.g. "250.00"
    + "|" + type.direction        // OUT, IN or XFER (so DEBIT vs INVESTMENT hash alike)
    + "|" + (accountLast4 ?: "")
    + "|" + date.toString()       // yyyy-MM-dd of transactionTime in IST
    + "|" + (referenceNumber ?: "")
hash = lower-case hex of SHA-256(UTF-8(key))
```

The date is `Instant.ofEpochMilli(time).atZone(config.zone).toLocalDate()` using the resolved transaction time. SMS and email for one transaction hash identically only when they agree on all five parts; when one has the reference and the other does not, the fuzzy matcher catches them.

### 7.2 Decision procedure (`DuplicateMatcher.decide`, `PC/dedup/DuplicateMatcher.kt:60-135`)

Constants: `WINDOW_MILLIS = 30 min`, `REVIEW_WINDOW_MILLIS = 12 h`, `STATEMENT_WINDOW_MILLIS = 36 h`, `ROUNDED_WINDOW_MILLIS = 4 h`; loose sources `{APP, SCREENSHOT, MANUAL}`. Storage lookups: by reference, by hash (including hashes of already-merged messages via `transaction_sources.parsedHash`), by amount in a time window, by amount range in a time window.

Outcomes: `Duplicate(existingId, reason in REFERENCE|HASH|FUZZY)` (merge), `PossibleDuplicate(existingId, reasonText)` (insert flagged for review), `New`.

1. Reference: if the incoming has a reference, any stored row with the same reference, the same `amountMinor` and the same `type.direction` -> `Duplicate(REFERENCE)`.
2. Hash: stored row with `transactionHash == hash` or any source `parsedHash == hash`:
   - if incoming has no reference and the incoming source name is already among the stored row's sources -> `PossibleDuplicate("Same amount, account and day, no reference number")` (same source, two purchases possible).
   - otherwise `apart = |stored.time - incoming.time| > 30 min`; `dated = incoming is STATEMENT or stored has STATEMENT source`. If NOT (`apart && !dated && (incoming ref null || stored ref null)`) -> `Duplicate(HASH)`. (Hours apart with a missing reference falls through to the fuzzy rules.)
3. Fuzzy candidates: stored rows with the same `amountMinor` and same direction within +-36 h, sorted by time distance. For each candidate `c` (`gap = |c.time - tx.time|`):
   - skip if both references exist and differ;
   - `bothHaveAccount`; `sameAccount = last4Match` (equal, or one ends with the other, e.g. "123" vs "0123"); skip if both have accounts and they differ;
   - `sameMerchant` = both non-null and equal ignoring case; `crossSource = incoming source not in c.sources`; `close = gap <= 30 min`; `loose` = incoming source in loose set or any of c's sources is; `accountless` = either account null;
   - Statement involved (incoming STATEMENT or c has STATEMENT): `Duplicate(FUZZY)` if `crossSource && gap <= 36 h && (sameAccount || accountless)`, else skip candidate (no review for statements);
   - skip if `gap > 12 h`;
   - then the first matching rule: `close && crossSource && (sameAccount || sameMerchant)` -> Duplicate(FUZZY) immediately; `close && crossSource && loose && accountless && merchantsAgree` -> Duplicate(FUZZY); (a review candidate already chosen -> ignore); `close && (sameAccount || sameMerchant)` -> review "Same amount and account|merchant within 30 minutes" (same source, could be two purchases); `close && crossSource && (!loose || merchantsAgree)` -> review "Same amount from SMS and email within 30 minutes"; `crossSource && sameAccount` (within 12 h) -> review "Same amount and account on the same day, from SMS and email".
4. Rounded payment-app match (`roundedAppMatch`): if incoming is APP with a whole-rupee amount, search stored rows with `amount in (amt+1)..(amt+99)` paise; if incoming is non-APP with a paise amount, search the amount truncated to whole rupees; within +-36 h, same direction, incoming source not in stored sources, and (incoming APP -> stored must have a non-APP source; incoming non-APP -> stored must be APP-only); same local day or within 4 h; accounts compatible (either null or `last4Match`); references compatible (either null or equal); `merchantsAgree`; the nearest wins -> `Duplicate(FUZZY)`.
5. Else `review?.let { PossibleDuplicate } ?: New`.

`merchantsAgree(a, b)`: true if either is null or a generic UI phrase; else compare lower-cased alphanumerics (one containing the other = agree); else true if they share a word of >= 3 letters.

### 7.3 What ingest does with the decision (`TransactionRepository.ingestInTransaction`, repo 172-261)

All inside one immediate (write) transaction per batch.

1. `CardBill.mark(parsed, rawText)` (DEBIT paying a card -> TRANSFER). `billMarked` = result is TRANSFER on an ACCOUNT that was a DEBIT or recognised as a bill (gets the note later).
2. Apply a merchant rule (category).
3. If `(source, sourceMessageId)` exists in `transaction_sources`, or in `deleted_messages` -> `ALREADY_PROCESSED` (skip).
4. `DuplicateMatcher.decide`; `accountId = ensureAccount(...)`. A decision that is not already Duplicate is upgraded to `Duplicate(FUZZY)` if `manualLegFor` finds a hand-entered transfer leg (36 h, same account, amount, direction, nearest) for the bank message. An APP-source row without an account takes a remembered payee account.
5. Duplicate: load the existing row; `mergedWith(tx)` (7.4); if the message names a real account (non-APP source) and the stored row has no `accountId` or no `accountLast4`, adopt the account (`accountId`, `bankName`, `accountKind`), else keep `existing.accountId ?: accountId`; update the row (rule's subcategory applied only when the row has no own placement); outcome `MERGED`; the balance/limit update goes to the account the row ends on.
6. PossibleDuplicate: insert a new row with hash `"<hash>#<SOURCE>:<messageId>"`, `needsReview = true`, `duplicateOfId = candidate`, `reviewReason`; outcome `FLAGGED_FOR_REVIEW`.
7. New: insert. If `insert` returns -1 (unique hash race), load by hash and merge; outcome `MERGED`; otherwise `INSERTED`. On INSERTED: add the card-bill note when set and the row has no note; run `pairTransfers`.
8. Insert a `transaction_sources` row for the message in all cases (so a rescan is idempotent), `rawText` capped at 20,000.
9. If an account exists, apply balance / limit (see 2.1), with a gap check first.

Counts reported: `IngestReport(inserted, merged, flagged, skipped)`.

### 7.4 Merge rules

`TransactionEntity.mergedWith(ParsedTransaction)` (`SH/repo/Merge.kt:13-34`): keep stored values, fill gaps from the message:
- `amountMinor`: replaced only if the stored amount is a whole rupee, the incoming has paise, same rupee part and same currency (app rounding).
- `merchant`: `betterMerchant`: incoming replaces stored only if stored is "weak" (contains `@`, or more than half digits, or a generic UI phrase) and incoming is not weak.
- `upiId`, `referenceNumber`, `balanceMinor`, `availableLimitMinor`: stored `?:` incoming. `accountLast4`: the longer of the two ("0123" over "123").
- `type`: DEBIT becomes INVESTMENT if the incoming says INVESTMENT.
- `category`: only replaces stored OTHER or INCOME, and only with a category that is neither OTHER nor INCOME.
- `timestamp`: an explicit printed time beats an arrival time (`!hasExplicitTime && incoming.explicit -> incoming time`); if the incoming states a balance/limit, is not a STATEMENT, and the chosen time is after the incoming time by <= 30 min, use the incoming time (so the payment is not applied on top of a balance that already includes it). `hasExplicitTime` OR-ed; `confidence` max.
- Row-to-row merge (`mergedWith(TransactionEntity)`): same fill-the-gap idea plus `accountId`, `note`.

Review actions: `mergeFlagged(id)` merges the flagged row into its `duplicateOfId` target, moves its sources and deletes it (if the target vanished, just clears the flag); `keepSeparate(id)` clears `needsReview/duplicateOfId/reviewReason`. Needs-review rows are excluded from balances, loans, recurring, tax income and insights.

`split(transactionId, sourceId)`: re-parses a stored source's `rawText` via the registry, inserts it as a new transaction with hash `"<hash>#split:<sourceId>"` and moves that source; requires at least 2 sources.

Manual merge (`SH/repo/ManualMerge.kt`): `merge(ids >= 2)` ranks rows by (real non-generic merchant, explicit time, has reference, has account, earliest `createdAt`, lowest id) -> keeps the best, folds the others in (`fold`: paise filling when the amounts differ by < 100 paise and the keeper is whole; bank name/kind from the other when the keeper has no account; explicit time; category only if keeper is OTHER; subcategory/customCategory fill), reassigns their sources, deletes them (no tombstones, so messages stay visible/splittable); `undo(result)` restores.

Deleting transactions (`deleteTransactions`): writes tombstones `(source, messageId)` for every source of the deleted rows (chunks of 900), then deletes (FK cascade removes sources).

Other repair jobs (all idempotent): `reparseStored` (re-read stored SMS/email to fix account and CREDIT-vs-DEBIT mistakes), `restoreMissingAccounts`, `reattributeAppRows` (fold account-less APP rows into the bank's row: amount range for a whole-rupee app amount, same direction, 4 h for rounded amounts else 30 min, references/merchants compatible), `reclassifyCardBills`, `importTransactions` (CSV: skip rows whose hash exists).

---

## 8. Sample message formats (from `parser-core/src/test/kotlin/.../corpus` and feature tests)

All samples in the repository are already anonymised (account digits "1234"/"5678", UPI refs like "526812345678", names such as "Swiggy", "John Doe", "Acme Corp"). Received time of the corpus is 25 Sep 2026 12:00 IST. Examples below are quoted from the test files (`\n` marks a newline).

SMS, bank savings account (UPI, NEFT, ATM, ACH):

1. HDFC UPI debit, `VM-HDFCBK`: `Sent Rs.250.00\nFrom HDFC Bank A/C *1234\nTo SWIGGY\nOn 25/09/26\nRef 526812345678\nNot You?\nCall 18002586161/SMS BLOCK UPI to 7308080808` -> DEBIT 250.00, a/c 1234, ref 526812345678, merchant "Swiggy", 2026-09-25 (`HdfcCorpus`).
2. HDFC NEFT credit: `Update! INR 5,000.00 deposited in HDFC Bank A/c XX1234 on 01-SEP-26 for NEFT Cr-CITI0000001-ACME CORP-XXXXXX-CITIN52026090112345. Avl bal INR 52,340.50. Cheque deposits in A/C are subject to clearing` -> CREDIT, ref CITIN52026090112345, merchant "Acme Corp", balance 52,340.50.
3. HDFC ATM: `Rs.2,000.00 withdrawn from HDFC Bank A/c XX1234 at ATM MUMBAI ANDHERI on 12SEP26 14:35. Avl Bal Rs.8,450.00` -> DEBIT, merchant "ATM" (category CASH).
4. HDFC ACH investment: `UPDATE: INR 999.00 debited from HDFC Bank XX1234 on 05-SEP-26. Info: ACH D- TP ACH ZERODHA-1234567. Avl bal:INR 23,410.00` -> INVESTMENT, merchant "Zerodha".
5. SBI UPI: `Dear UPI user A/C X1234 debited by 250.0 on date 25Sep26 trf to SWIGGY Refno 526812345678. If not u? call 1800111109. -SBI`; SBI credit: `Dear SBI User, your A/c X1234-credited by Rs.5000 on 20Sep26 transfer from JOHN DOE Ref No 526312345678 -SBI` (`SbiCorpus`).
6. Axis (new layout, line-broken): `INR 250.00 debited\nA/c no. XX1234\n25-09-26, 10:15:32\nUPI/P2M/526812345678/SWIGGY\nNot you? SMS BLOCKUPI Cust ID to 919951860002\nAxis Bank`.
7. ICICI 3-digit account: `ICICI Bank Acct XX123 debited for Rs 240.00 on 23-Sep-26; SWIGGY credited. UPI:526612345678. Call 18002662 for dispute. SMS BLOCK 123 to 9215676766.` and credit `Dear Customer, Acct XX123 is credited with Rs 5,000.00 on 20-Sep-26 from JOHN DOE. UPI:526312345678-ICICI Bank.`.
8. Kotak UPI: `Sent Rs.300.00 from Kotak Bank AC X1234 to swiggy@icici on 25-09-26.UPI Ref 526812345678. Not you, https://kotak.com/KBANKT/Fraud` (VPA only; merchant derived from the VPA).
9. HDFC UPI to VPA with fused name: `Rs.120.00 debited from a/c **1234 on 23-09-26 to VPA zomato-order@ptybl(UPI Ref No 526612349876).`.

SMS, credit/debit cards:

10. HDFC credit-card spend (explicit time, ISO-like): `Rs.1500.00 spent on HDFC Bank Card x5678 at AMAZON PAY INDIA on 2026-09-24:18:22:10. Not You? To Block+Reissue Call 18002586161/SMS BLOCK CC 5678 to 7308080808` -> DEBIT CARD; with limit: `Rs.349.00 spent via HDFC Bank Card xx5678 at UBER INDIA on 2026-09-20:22:01:45 Avl Lmt: Rs 1,23,456.00` -> `availableLimitMinor = 12,345,600`, `balanceMinor = null`.
11. HDFC debit-card cash withdrawal: `Withdrawn Rs.10000 From HDFC Bank Card x2139 At +NALLAGANDLA 3 On 2026-09-20:14:20:34 Bal Rs.573096.22 Not You? Call 18002586161/SMS BLOCK DC 2139 to 7308080808` -> CARD kind, `isDebitCard = true`, channel ATM, category CASH, balance 573,096.22 (the linked bank account's).
12. Axis card (multi-line): `Spent\nCard no. XX5678\nINR 1,299.00\n22-09-26 18:44:02\nAMAZON\nAvl Lmt INR 98,701.00\nNot you? SMS BLOCK 5678 to 919951860002\nAxis Bank`.
13. SBI Corporate Card with 2-digit ending and foreign currency: `USD200.00 was spent on your SBI Corporate Card number ending with 96 at ANTHROPIC on 01/10/26. Available Credit Limit: Rs.59,165.07, If this trxn. wasn't done by you, call 18605003000` -> amount 20000 USD minor, a/c "96", limit 59,165.07.
14. Card bill payment received (TRANSFER): `Payment of Rs 12,345.00 received towards your HDFC Bank Credit Card XX5678 on 18-09-26.`; bank side: `Rs 12,345.00 debited from A/c XX1234 on 05-09-26 towards your HDFC Bank Credit Card XX5678. Avl Bal Rs 40,000.00` -> TRANSFER.

Email:

15. HDFC UPI email: `Dear Customer,\n\nRs.450.00 has been debited from account **1234 to VPA swiggy@icici SWIGGY on 25-09-26.\n\nYour UPI transaction reference number is 526812345678.\n\nIf you did not authorize this transaction, please report it immediately ...\n\nWarm Regards,\nHDFC Bank` (sender `HDFC Bank InstaAlerts <alerts@hdfcbank.net>`); the footer is cut at "If you did not".
16. HDFC card email: `Dear Card Member,\nThank you for using your HDFC Bank Credit Card ending 5678 for Rs 1,500.00 at AMAZON PAY INDIA on 24-09-2026 18:22:10.\nAuthorization code:- 012345\nAfter the above transaction, the available balance on your card is Rs 98,500.00`.
17. ICICI card email: `Dear Customer,\nYour ICICI Bank Credit Card XX9012 has been used for a transaction of INR 1,499.00 on Sep 22, 2026 at 18:10:05. Info: AMAZON PAY IN.\nThe Available Credit Limit on your card is INR 88,501.00`.

Payment-app notifications (`NotificationLayoutsTest.kt`): title and body are separate fields: `("PhonePe", "Payment successful", "₹250 paid to Ravi Kumar")`, `("PhonePe", "Paid ₹250", "to Ravi Kumar")`, `("PhonePe", "asha@ybl sent you ₹500", null)`, `("Google Pay", "You paid Ravi Kumar ₹250", "Tap to view")`, `("PhonePe", "AutoPay", "₹199 paid to Netflix via AutoPay")` (channel AUTO_DEBIT), `("CRED", "Credit card bill paid", "₹5,000 paid towards your HDFC Bank Credit Card")` -> TRANSFER. Skipped: `("PhonePe", "Payment failed", "₹250 to Ravi Kumar could not be paid")`, `("Google Pay", "You've won ₹50 cashback!", "Scratch your card now")`, `("BHIM", "123456 is your OTP to pay ₹500", null)`, `("PhonePe", "Scheduled payment", "₹199 will be debited tomorrow for Netflix")`, `("PhonePe", "Ravi Kumar requested ₹500", "Pay now")`.
Payment-app receipt email: `PhonePe <noreply@phonepe.com>`: `Payment receipt. Paid to Ravi Kumar. Amount ₹250. Transaction ID T2610101234567890. UTR 526812340020. Debited from HDFC Bank XX1234. Date 10 Oct 2026` -> DEBIT 250, merchant "Ravi Kumar", a/c 1234, ref 526812340020.

Lender, deposit, card due, investment:

18. Propelld EMI SMS (`VM-PROPLD-S`): `Dear Customer, EMI of Rs.12,345 for your loan a/c no. XXXX1234 has been received on 05-10-2026. Thank you. - Propelld` -> DEBIT 12,345 on loan account 1234, EMI_LOAN. Disbursal: `Congratulations! Loan of Rs 2,00,000 has been disbursed to your account. Loan A/c XXXX5678. - Propelld` -> `LoanStatus(principal=outstanding=2,00,000, last4=5678)`.
19. FD booking SMS (`VM-HDFCBK`): `Your FD No. XXXXXXXX5678 for INR 1,00,000.00 has been booked on 24-09-2026 for 1 year at 7.10% p.a. Maturity date: 24-09-2027. Maturity amount INR 1,07,281.00. It will be auto renewed on maturity. -HDFC Bank` -> deposit status FD, rate 710 bps, maturity 2027-09-24, RENEW_ALL; not a transaction.
20. Card statement SMS (`VK-AXISBK-S`): `Your statement for Axis Bank Credit Card no. XX4821 is generated.\nDue on: 30-10-26\nTotal amt: INR  Dr. 5432.10\nMin amt due: INR  Dr. 109.00\nPay at axis.bank.in/ccpaynow ...` -> `CardDue(total 5432.10, min 109.00, due 2026-10-30)`; `registry.parse` returns null for it.
21. EPF SMS (`FundEmailsTest`): `Dear Member, your passbook balance against MH/BAN/0012345/000/0001234 is Rs. 2,56,250/-. Contribution of Rs. ...` and NPS: `Your NPS a/c PRAN XXXXXXXX1234 holding value as on 23-09-2026 is Rs. 4,56,789.12.`; MF order email: `Your SIP instalment of ₹5,000 for Parag Parikh Flexi Cap Fund Direct Growth has been processed successfully.` (subject "SIP instalment processed", sender `Groww <noreply@groww.in>`).

Negatives that must be rejected (all corpus files):
- OTP: `123456 is your OTP for txn of INR 1,500.00 at AMAZON on HDFC Bank card ending 5678. Valid for 5 mins. Do not share OTP with anyone.`
- Promo: `Get a Personal Loan of up to Rs.40 lakh, pre-approved for you! Apply now: hdfcbk.io/x7Yt. T&C apply`
- Declined: `Transaction of Rs.500.00 on HDFC Bank Card x5678 at FLIPKART has been declined due to insufficient balance.`
- Statement reminder: `HDFC Bank Credit Card XX5678 statement: Total Amt Due Rs.12,345.00, Min Amt Due Rs.620.00, due by 05-10-26. Pay now: hdfcbk.io/pay`
- Mandate: `E-mandate for Rs.1,500.00 for SIP with ZERODHA has been registered successfully on HDFC Bank A/c XX1234.`
- Future debit: `Rs.599.00 will be debited from HDFC Bank A/c XX1234 on 01-10-26 towards NETFLIX mandate.`
- Collect request: `RAHUL SHARMA has requested Rs.500.00 from you via UPI on ICICI Bank iMobile. Approve or decline in the app.`

The corpus test (`CorpusAccuracyTest`) requires >= 98% field accuracy over amount/type/account/ref/merchant/balance/date, 0 negative leaks, and identical SMS/email hashes for the same transaction.

---

## Open Questions

1. `CARD_PAIR_WINDOW` is 5 days (`TransactionRepository.kt:853`) but the kdoc above `pairTransfers` (line ~321) and the doc comment say "within 3 days". The code value is documented above; confirm 5 days is intended before porting.
2. `ForexSql`: the choice of rate when two rate days are equally near a transaction day is `LIMIT 1` with no ORDER BY (undefined). Who calls `ForexDao.recompute()` after a rate or markup edit is in `:app`, not read here.
3. Cash-flow / balance forecast: no such logic exists in `shared`. The Home screen uses a `PlanSnapshot` (`plans.snapshot` in `app/.../ui/home/HomeViewModel.kt:178`), which is in `:app` and was not analysed. Confirm whether "forecast" needs anything beyond recurring `nextDue`, loan schedules, savings estimates and tax-income projection.
4. Budgets: no logic in `shared` beyond the table. The alert thresholds are from `:app/notify/Alerts.kt` (default `budgetAlertPercent` value not read; the kdoc says 90). Analytics budget aggregation (`AnalyticsViewModel`) was only grepped, not read.
5. Net-worth history (2.6) comes from `:app` (`NetWorth.kt`, `LocalLists.kt`) and is summarised from a partial read (`AssetClass.of(kind)` mapping, `Book` filter, `LedgerMath.rupees` were not read).
6. Tax: FY2026-27 rules are a copy of FY2025-26 and the header says the old-regime rebate and capital-gains rates are not confirmed against the official 2026-27 page. Treat the 2026-27 numbers as provisional. Also the surcharge marginal-relief code path and rebate marginal relief when special-rate income exists (relief disabled when `stcgT + ltcgT > 0`) are as implemented; no tax-law source was consulted.
7. `Planning.recurring` uses the median amount index `size/2` (upper median) and the day spread `max - min <= 6` without wrap-around (a payment on the 30th and the 2nd is not recognised). Unknown if this is intended.
8. `transaction_sources.source` documentation lists SMS/EMAIL/CSV/MANUAL, but code also writes APP, SCREENSHOT and STATEMENT (`Source.name`). Confirm there are no other values (e.g. from `:app` importers).
9. The `statements` table is overloaded for non-statement data (card due notices `CARD_PAYMENT`/`CREDIT_CARD`, manual overrides `CARD_OVERRIDE`) with column re-use (`openingMinor` = outstanding, `closingMinor` = unbilled, `debitsMinor` = payment). A Flutter schema may want separate tables; if the Android DB is ever migrated/imported, these encodings matter.
10. `PasswordGuesser`, the holdings parsers (`HoldingColumns`, `HoldingTable`, `HoldingSheet`, `HoldingLines`, `HoldingsCheck`, `SpreadsheetLines`, `EpfPassbook`, `NpsStatement`, `PortfolioSummary`, `HoldingProfiles`) were read for purpose and constants only, not regex-by-regex; they are only summarised in 6.9. Port them from source when the Investments feature is built. Header synonyms in `HoldingColumns.SYNONYMS` and profile headers in `HoldingProfiles.ALL` were not enumerated here.
11. `MerchantDirectory` and `Subcategories` regexes: key entries are listed; the complete regex per subcategory (Subcategories.kt:18-147) and every directory alias (MerchantDirectory.kt:13-147) should be copied from source for a faithful port.
12. `IndianBanks` header lists were summarised by bank name; copy the exact header and domain codes from `PC/bank/IndianBanks.kt:19-77` (registry rejects a duplicate claim at start-up, so overlaps between lists matter).
13. Dedup of two SMS from the same bank for the same payment with differing time: review flagged only within 12 h; beyond 12 h a cross-source duplicate with the same amount/account is treated as New (e.g. a bank email arriving a day late). That follows from `gap > REVIEW_WINDOW_MILLIS -> continue`, but the KDoc says "later the same day"; confirm the 12 h window is the intended meaning.


---

# Part C: Email, Statements, History and the v2 Spec

Source: `hisaab_apk/` (Kotlin/Android, app name now DhanKosh, package `com.hisaab.app`) and `v2_design/`.
Paths below are relative to `hisaab_apk/` unless stated. `E` = `email/src/main/kotlin/com/hisaab/email`, `S` = `parser-core/src/main/kotlin/com/hisaab/parser/statement`.
Line numbers are for the file named. Read-only analysis; nothing under `hisaab_apk` or `v2_design` was changed.

---

## 1. Email

### 1.1 Two connection modes (`E/sync/GmailSettings.kt:22`)

`enum MailConnection { NONE, GOOGLE, IMAP }`. The worker picks the engine from this value (`E/sync/GmailSyncWorker.kt:41-45`). IMAP is the default product path since 1.1.0; Google sign-in is kept as an "advanced option" (CHANGELOG 1.1.0).

| Aspect | IMAP (app password) | Gmail API (Google sign-in) |
|---|---|---|
| Engine | `ImapSyncEngine` (`E/imap/ImapSyncEngine.kt`) | `GmailSyncEngine` (`E/sync/GmailSyncEngine.kt`) |
| Transport | JavaMail over `imaps` (TLS), host from `MailServers.forAddress` | Ktor HTTP to `https://gmail.googleapis.com/gmail/v1/users/me` (`E/api/GmailApi.kt:34`) |
| Auth | email + app password, verified by 6-digit code | Credential Manager sign-in + `AuthorizationClient`, scope `gmail.readonly` (`GmailAuthManager.kt:128`) |
| Multiple inboxes | Yes, `logins()` loops all accounts (`ImapSyncEngine.kt:45-56`) | One account (`ACCOUNT` key) |
| First sync | Whole look-back window | `messages.list` with `{from:(...) subject:"..."} newer_than:Nd` (`GmailSyncEngine.kt:183-193`) |
| Later syncs | Re-read from `lastSync - 1 day` (`OVERLAP_MS`, `ImapSyncEngine.kt:101`), skip processed ids | `users.history.list` from stored `historyId`, `historyTypes=messageAdded`, `maxResults=500` (`GmailApi.kt:50-59`) |
| History expiry | n/a | 404 -> `HistoryExpiredException` -> `FALLBACK_FULL` bounded by days since last sync, +1, clamped `1..lookbackDays` (`GmailSyncEngine.kt:76-81`) |
| Sender filter | Client side after envelope fetch (`SenderAllowList.allows`) | Server side in query on full sync; client side (`filterBySender=true`) on incremental (`:113-114`, `:138`) |
| Concurrency | Sequential | 8 parallel `messages.get` (`MAX_CONCURRENT_FETCHES`, `GmailSyncEngine.kt:176`), page size 100 |
| Retry | WorkManager retry | 429/5xx exponential backoff 500 ms << attempt, 3 retries; 401 refresh once, then `AuthRequiredException`; 403 -> auth required (`GmailApi.kt:62-84, 86-89`) |

### 1.2 IMAP details

- Server table `E/imap/MailServers.kt:21-52`, IMAP port default 993 (`:7`), regex for address validity `:17`.
  - gmail.com / googlemail.com -> `imap.gmail.com`, SMTP `smtp.gmail.com:465` SSL; app-password URL `https://myaccount.google.com/apppasswords`.
  - outlook.com, hotmail.com, live.com, msn.com, outlook.in, hotmail.co.in -> `outlook.office365.com`, SMTP `smtp-mail.outlook.com:587` STARTTLS; `https://account.live.com/proofs/AppPassword`.
  - yahoo.com/.co.in/.in, ymail.com, rocketmail.com -> `imap.mail.yahoo.com`, `smtp.mail.yahoo.com:465`.
  - icloud.com, me.com, mac.com -> `imap.mail.me.com`, `smtp.mail.me.com:587`.
  - zoho.com, zohomail.com, zohomail.in -> `imap.zoho.com`, `smtp.zoho.com:465`.
  - rediffmail.com -> `imap.rediffmail.com`, `smtp.rediffmail.com:465`. aol.com -> `imap.aol.com`, `smtp.aol.com:465`.
  - Else: `imap.<domain>` / `smtp.<domain>:465` SSL (`:50`).
- JavaMail session (`E/imap/MailClient.kt:172-182`): `imaps`, `ssl.checkserveridentity=true`, connect/read timeout `20000` ms (`:196`), `partialfetch=false`.
- Folder choice (`:91-92`, `:166-170`): the folder carrying IMAP attribute `\All` (Gmail "All Mail", any language), else `INBOX`. Opened `READ_ONLY`.
- Query: `ReceivedDateTerm(GE, Date(since))` (server compares dates, not times), then ONE envelope+UID fetch for all hits, then bodies are decoded only for messages passing `accept(from, subject)` (`:95-101`). Decode failures are swallowed per message (`runCatching ... getOrNull`, `:101`).
- Message id: `imap:<Message-ID>` else `imap:uid:<uid or messageNumber>` (`:112-113, :121`).
- `receivedAt = receivedDate ?: sentDate ?: 0` (`:122`).
- Attachments capped at `MAX_PDFS = 5` per mail (`:198, :147`).

### 1.3 Connect flow and verification code (IMAP)

`E/imap/MailConnector.kt:23-55`:
1. `signInAndSendCode(email, password)`: lowercase+trim email, strip spaces from the app password (`:24`), `checkLogin` (IMAP connect+close). Wrong password -> `MailAuthException` (maps `AuthenticationFailedException`, `MailClient.kt:188-190`).
2. Mail a 6-digit code to the user's own address via SMTP (`sendToSelf`, from-name "DhanKosh"). Subject `DhanKosh verification code: <code>`; body says it expires in 10 minutes (`:34-43`).
3. `verify(typed)`: on `OK` the login is saved (`MailAccountStore.save`) and `settings.connected(email, IMAP)`; caller starts the first sync.

`E/imap/MailVerification.kt`:
- Code = `SecureRandom.nextInt(900_000) + 100_000` (always 6 digits) (`:28`).
- Stored only in memory as SHA-256 of `"email|code"` (`:55`); TTL 10 min (`ttlMillis`, `:15`); max 5 wrong tries (`:16`); typed input filtered to digits; constant-time compare `MessageDigest.isEqual`.
- Results: `OK, WRONG, EXPIRED, TOO_MANY_ATTEMPTS, NONE`.
- Purpose stated in doc comment: proves the address is the user's and that the app can both send and receive with the login.
- `signOut()` wipes all stored logins + Keystore key, clears account (transactions stay) (`:63-66`); `remove(email)` drops one and switches sync off if none remain (`:69-73`).

### 1.4 Gmail OAuth flow (`E/auth/GmailAuthManager.kt`)
- Optional Credential Manager sign-in only when `BuildConfig.GOOGLE_WEB_CLIENT_ID` (from `local.properties`) is non-blank (`:82-100`); otherwise the account picker inside `authorize()` is used.
- `AuthorizationClient.authorize` with scope `gmail.readonly`; if `hasResolution()` returns `NeedsConsent(pendingIntent)` (`:59-60`), then `completeConsent`.
- No refresh token is ever stored. Access token lifetime assumed `55 min` (`TOKEN_LIFETIME_MS`, `:129`), refreshed with a 2 min margin (`:130`) by silent re-authorize; if a resolution is needed -> `settings.setNeedsReauth(true)` (`:111-114`).
- `signOut` revokes at `https://oauth2.googleapis.com/revoke`, wipes token + key, clears Credential state (`:120-125`).

### 1.5 Credential storage
- `KeystoreSecret` (`E/auth/KeystoreSecret.kt`): AES-256-GCM key in AndroidKeyStore under an alias, no padding, 12-byte IV prefix, 128-bit tag, Base64 NO_WRAP. `open()` returns null if the key was reset (device lock removed). `deleteKey()` makes ciphertext permanently unreadable.
- Aliases: `hisaab.mail.password` (IMAP passwords, `MailAccountStore.kt:70`), `hisaab.gmail.token` (`TokenStore.kt:49`), `hisaab.statement.passwords` (`StatementPasswordStore.kt:150`).
- `MailAccountStore`: DataStore `mail_account`; one string-set entry per account as `email\u001Fsealed` (`SEP`, `:71`); reads a legacy single `email`/`password` pair as the first account (`:62-67`).
- `TokenStore`: DataStore `gmail_tokens`, keys `token` (sealed) and `expires_at`.
- Passwords "used for the call and never logged" (`MailClient.kt:57`).
- Sync run log stores counts/timing/error class only, never mail content (`E/sync/SyncActivity.kt`).

### 1.6 Sender / domain whitelist
- Setting `senders` (`GmailSettings.kt:30`): a set of lowercase addresses or domains. Default = `registry.defaultEmailSenders` (`GmailSettings.kt:63, :70`), where `ParserRegistry.defaultEmailSenders` = every `BaseBankParser.emailSenders` + `STATEMENT_SENDERS` (`parser-core/.../registry/ParserRegistry.kt:82-83`).
- `STATEMENT_SENDERS` (`ParserRegistry.kt:87-102`), grouped:
  - Registrars/depositories: camsonline.com, kfintech.com, karvy.com, nsdl.co.in, nsdl.com, cdslindia.com, cdslstatement.com, kfintech.net, camsonline.co.in, cdslindia.co.in, cdsl.co.in.
  - Brokers/apps: icicidirect.com, icicisecurities.com, hdfcsec.com, kotaksecurities.com, indmoney.com, zerodha.com, zerodha.net, groww.in, upstox.com, angelone.in, dhan.co, kuvera.in, paytmmoney.com, etmoney.com, mfcentral.com, bsestarmf.in, mfuindia.com, scripbox.com, fisdom.com.
  - EPF/NPS: epfindia.gov.in, epfo.gov.in, umang.gov.in, nps-proteantech.in, proteantech.in, npstrust.org.in, npscra.nsdl.co.in, kfintech-cra.com, camsnps.com.
  - Card issuers/neo-banks without a dedicated parser: sbicard.com, americanexpress.co.in, aexp.com, rblbank.com, indusind.com, indusind.bank.in, hsbc.co.in, sc.com, onecard.in, getonecard.app, slicepay.in, sliceit.com, jupiter.money, fi.money, scapia.cards, uni.cards, bobfinancial.com, federalbank.co.in, aubank.in, canarabank.com, unionbankofindia.co.in, citibank.com, dbs.com, paytmbank.com, bajajfinserv.in.
  - Lenders: propelld.com, adityabirlacapital.com, abcd.adityabirlacapital.com, tatacapital.com, credila.com, avanse.com, incred.com, smfgindiacredit.com, homecredit.co.in, kreditbee.in, navi.com, poonawallafincorp.com, hdbfs.com.
- Bank domains come from each bank parser's `emailSenders` (not read in this task; per-bank parsers are outside Part C scope). 55 listed banks add domains via `IndianBanks` with no duplicate claims (`ParserRegistry.kt:124-139`).
- Matching (`GmailSyncEngine.kt:195-200`): `SenderAllowList.allows(from, subject)` = any of `SenderKeys.candidates(from)` is in the set, OR the subject looks like a statement (see 1.7). Comment says subdomains match (`alerts.sbi.co.in` for `sbi.co.in`); the implementation of `SenderKeys.candidates` is outside the files read (Open Question 1).
- Editing: `setSenders` lowercases/trims and calls `forgetPosition` so older mail from new senders is re-read; `resetSenders` removes the override (`GmailSettings.kt:121-126`).

### 1.7 Statement-by-subject filter
`ParserRegistry.STATEMENT_SUBJECTS` (`ParserRegistry.kt:109-114`) feeds the Gmail query as `subject:"..."` OR-clauses (`GmailSyncEngine.kt:190-191`):
"Consolidated Account Statement", "NPS Transaction Statement", "PRAN", "EPF Passbook", "Member Passbook", "SIP installment", "SIP instalment", "units allotted", "allotment of units", "Statement of Transaction", "NPS contribution", "Holdings statement", "mutual fund statement", "Holdings report", "Balance statement", "Portfolio statement", "Holdings", "Portfolio report", "Fixed Deposit", "Term Deposit", "Recurring Deposit", "Deposit advice", "PPF statement", "Public Provident Fund", "portfolio summary".

Client-side regex `STATEMENT_SUBJECT` (`:115-120`, case-insensitive): `consolidated\s+account\s+statement|\bCAS\b|\bNPS\b.{0,40}statement|\bPRAN\b|\bEPF\b.{0,30}(?:passbook|statement)|member\s+passbook|\bSIP\b.{0,60}\b(?:instal+ment|processed|successful|allot+ed)|\bunits?\s+(?:have\s+been\s+)?allot+ed|allotment\s+of\s+units|statement\s+of\s+transactions?|\bNPS\b.{0,40}(?:contribution|holding|transaction)|\bholdings?\b|portfolio\s+(?:holdings|report)|(?:balance|portfolio|investment)\s+(?:statement|report)|mutual\s+fund\s+statement|(?:fixed|term|recurring)\s+deposit|deposit\s+advice|\bPPF\b.{0,30}statement|public\s+provident\s+fund|portfolio\s+summary`.
Note the Gmail query uses only the literal list while IMAP/incremental use the regex, so the two paths are not identical (the regex is broader: bare `\bCAS\b`, `\bholdings?\b`).

### 1.8 Sync schedule and settings
- Look-back: choices `7, 30, 90, 180, 365` days, default `90` (`GmailSettings.kt:43-44`). The same window drives SMS inbox scans. Increasing it clears the sync position (full re-read) (`:115-119`).
- Periodic: WorkManager unique periodic `gmail-sync-periodic`, every 1 day, first run at the next 02:30 local time, constraints `NetworkType.CONNECTED` + `requiresBatteryNotLow`, exponential backoff 30 s, `ExistingPeriodicWorkPolicy.UPDATE` (replaces the old hourly job) (`GmailSyncWorker.kt:74-95`). Doc comment: "The refresh button on Home syncs on demand".
- On demand: `syncNow` unique one-time `gmail-sync-now`, `REPLACE` (`:97-103`). Per CHANGELOG 2.7.0 the Home sync button also re-reads the last 14 days of SMS.
- Failure handling (`:49-62`): `AuthRequiredException`/`MailAuthException` -> set `needsReauth`, fail; `IOException` -> `retry()` up to `MAX_ATTEMPTS=5`.
- Progress published via `setProgress(KEY_EMAILS_READ)`; success sends `KEY_SUMMARY` (`:40, :48`). `notifier.onTransactionsChanged()` if `report.parsed > 0`.
- Report string format: `"<mode>: N emails, M transactions (a new, b merged, c to review) in Xs"` (`GmailSyncEngine.kt:47-51`). Modes `FULL, INCREMENTAL, FALLBACK_FULL, DISABLED`.
- Dedup of already-seen mail: `ProcessedEmailEntity(id, time, outcome)`, outcomes `PARSED / REJECTED / SKIPPED` (`GmailSyncEngine.kt:177-179`). IMAP never writes `SKIPPED` (it filters before fetching).
- `readPdfStatements` defaults true; IMAP DI hardcodes `true` (`di/EmailModule.kt:76`).
- HTTP client: Ktor Android engine, request timeout 30 s, connect 15 s, `expectSuccess=false` (`EmailModule.kt:36-43`).

### 1.9 Per-message pipeline (same shape in both engines)
`ImapSyncEngine.parse` (`:84-98`) / `GmailSyncEngine.parseEmail` (`:151-170`):
1. `registry.parse(body, from, receivedAt, EMAIL)` -> bank-alert transaction.
2. If none: `registry.loanStatus(...)` (lender message or FD/RD/PPF status) -> `sink.loanStatus`.
3. Always: `registry.cardDue(...)` -> `sink.cardDue` (statement-generated / bill-due / payment-ack; not a transaction).
4. If still no transaction and a statement handler exists: `pdf.readEmail(...)` (MF order, INDmoney summary, EPF, NPS mail).
5. If `readPdf`: for each attachment `pdf.read(bytes, StatementMeta("EMAIL", "<msgId>#pdf<i>", from, subject, filename, receivedAt, emailText))`.
Outcome stored as REJECTED when no transaction came out of steps 1,4,5 (loan/card-due outputs do not count as PARSED).

### 1.10 MIME and HTML handling
- Gmail: `MimeParser.extract` walks the `payload` tree (`E/mime/MimeParser.kt:26-60`). First `text/plain` and first `text/html` without a filename are kept; any part with a filename that is `application/pdf`, `.pdf`, a spreadsheet name, or (spreadsheet MIME with no dot in the name) is an attachment; other attachments ignored. Charset parsed from the part's `Content-Type` header by regex `charset="?([\w.:-]+)"?`, default UTF-8. base64url decode (`:76`).
- IMAP: recursive walk of `multipart/*` and `message/rfc822` (`MailClient.kt:133-156`); filename MIME-decoded via `MimeUtility.decodeText`; charset via `javaCharset`.
- Body choice (both): `text/plain` if trimmed length `>= 30` (`MIN_PLAIN_LENGTH`), else HTML converted, else short plain, else Gmail `snippet` / empty.
- `htmlToText` (Jsoup) (`MimeParser.kt:79-89`): removes `script, style, head`; inserts a newline marker before `p, div, tr, li, h1-h6, table` and after `br`; adds a space after `td, th`; trims each line; collapses blank lines. Purpose: keep field boundaries for regex parsers.
  The `LINE` marker constant renders as a space in the file as read (`:92`); the intended marker character may be a private/zero-width char lost in extraction (Open Question 2).

### 1.11 Attachment handling
- Accepted: PDF (`application/pdf` or `.pdf`), and spreadsheets by name `\.(xlsx|xlsm|xls|csv)$` (`SpreadsheetExtractor.kt:30`) or by MIME (`application/vnd.ms-excel`, `text/csv`, `application/csv`, `text/comma-separated-values`, OOXML sheet, macro-enabled sheet) (`:35-38`). IMAP additionally requires a filename or `ATTACHMENT` disposition for the spreadsheet branch (`MailClient.kt:142-145`).
- Default name if none: `statement.pdf` or `statement.xls` (`MailClient.kt:149`).
- Cap: 5 per mail for IMAP; Gmail path has no cap (all matching parts, each fetched via `attachments.get` if not inline).
- Type is decided from bytes first: `%PDF` in the first 1024 bytes, `PK\x03\x04` = XLSX, OLE magic `D0 CF 11 E0 A1 B1 1A E1` = XLS, `.csv` name or "looks like text" (no NUL, < 2% control chars in first 2048 bytes), then `.pdf` name (`SpreadsheetExtractor.kt:40-51, 297-309`).
- Statement bytes are kept in app-private never-backed-up storage (`context.noBackupFilesDir/statements/<sha256-16>.<ext>`), locked ones in `.../locked-statements/` (`StatementProcessor.kt:90-93, 96-99`). Details in 2.7.

---

## 2. Statements

Entry point: `StatementProcessor` (`E/statement/StatementProcessor.kt`, implements `StatementHandler`), which calls `StatementParser` (`S/StatementParser.kt`). Line numbers for `StatementProcessor` are file-relative.

### 2.1 Detection (what is a statement)
- By attachment: any PDF/XLS/XLSX/CSV attachment on a mail from an allowed sender or with a statement-looking subject goes to `StatementProcessor.read` (1.9 step 5). There is no separate "is this a statement" gate on attachments; content is classified after text extraction.
- By file picked from phone: `importFile` builds `StatementMeta("FILE", "file:"+sha, "File on this phone", ...)` (`:225`).
- Issuer naming for locked files and unreadable ones: `guessIssuer` regex list `ISSUERS` (`:370-382`, via sender+subject+filename): hdfc, icici, `sbi\s*card|sbicard` -> SBI Card, `\bsbi\b|state bank`, axis, kotak, idfc, indusind, amex, hsbc, `\brbl`, `yes\s*bank`, camsonline/`\bcams\b`, kfintech|karvy, nsdl, cdsl, indmoney, zerodha, groww, onecard. Fallback: sender display name if it has no `@`.
- Content classification (`StatementParser.parse`, `S/StatementParser.kt:72-92`): header = first `HEADER_LINES = 40` lines.
  - `isCard` = `CARD_STATEMENT`: `\bcredit\s+cards?\b|\bcard\s+statement\b|\bminimum\s+(?:amount|payment)\s+due\b|\btotal\s+(?:amount|payment)\s+due\b|\bcredit\s+limit\b|\bnew\s+balance\b` (`:444-447`).
  - Bank name from `BANKS` (13 regexes, `:473-480`: HDFC, ICICI, SBI/State Bank/SBI Card, Axis, Kotak -> "Kotak Mahindra Bank", IDFC -> "IDFC FIRST Bank", Yes, IndusInd, American Express, HSBC, RBL, AU Small Finance, Federal, India Post/department of posts, Standard Chartered) else the sender display name else "Statement".
  - `last4` = first group of `MASKED_NUMBER` (4 alternatives, `:447-451`) else `AccountExtractor.extract(header)`.
  - `StatementKind`: INVESTMENT if holdings found, or `INVESTMENT_STATEMENT` in header (`consolidated account statement|\bCAS\b|demat|holding statement|portfolio|mutual fund|\bfolio\b|US stocks|statement of transaction|\bPRAN\b|\bNPS\b`), or `INVESTMENT_SENDER` (camsonline, kfintech, karvy, nsdl, cdsl, indmoney, zerodha, groww, upstox, angelone, dhan.co, kuvera, icicidirect, icicisecurities, hdfcsec, kotaksecurities, paytmmoney, etmoney, mfcentral, proteantech, npscra, kfintech-cra, camsnps, npstrust); CREDIT_CARD if `isCard`; BANK if rows found or `BANK_STATEMENT` (`account statement|statement of account|savings account|current account`); else OTHER.
  - Deposits short-circuit first (`depositKind`, `:197-205`): not if card or `SAVINGS_STATEMENT`; PPF (`public provident fund|PPF account/a/c/statement/passbook`), RD (`recurring deposit|RD account...`), FD advice (`(fixed|term) deposit (advice|receipt|confirmation|certificate|statement...)|deposit advice|FD advice...|TDR|FDR`).

### 2.2 PDF text extraction
- `PdfTextExtractor` (`E/mime/PdfTextExtractor.kt`): PdfBox-Android (`com.tom_roush.pdfbox`), `PDFTextStripper` with `sortByPosition = true`; `open(bytes, password)` returns `PdfOpen.Text | Locked | Protected | Unreadable`. `InvalidPasswordException` -> Locked; `IOException`/`RuntimeException` -> Unreadable. Lazy init of `PDFBoxResourceLoader`. On-device only.
- Parser first normalises: non-breaking spaces to spaces, trims, drops empty lines (`StatementParser.kt:73`).
- Spreadsheets are converted to the same text lines, see 2.5.

### 2.3 Password candidate generation
Orchestration `StatementProcessor.openWithSaved` (`:281-297`):
1. Spreadsheet kinds -> `SpreadsheetExtractor.open` (no passwords; password-protected workbook -> `Protected`).
2. PDF opened with no password; if not Locked return.
3. Bank key from `BankKeys.of("<issuer> <sender> <subject> <filename>")`; account ids = all accounts if bank unknown, else accounts whose `BankKeys.of(bankName)` matches.
4. `passwords.attempts(cardLast4s, ids, combos = bank != null)`, each tried in order; first `Text` wins; else `Locked`.

`StatementPasswordStore.attempts` (`:132-139`): if no bank-specific details -> `PasswordGuesser.candidates(me, last4s)`; else `PasswordGuesser.forBanks(me, banks, last4s, combos)`; then append user-saved passwords; `distinct()`.

`PasswordGuesser` (`S/PasswordGuesser.kt`):
- Caps: `MAX = 240` (`candidates`), `MAX_WITH_BANKS = 300` (`forBanks`). Anything shorter than 4 chars is dropped.
- Inputs `Identity(name, dob, pan, phone, altName, altPhone, email)`; `email` is stored but not used for guesses. `BankIdentity(customerId, accountNumber, ifsc, names, phones, emails)`.
- `BankKeys` (`:34-49`): 17 keys (hdfc, icici, axis, hsbc, sbi, kotak, yes, idfc, indusind, baroda, pnb, federal, canara, union, rbl, scb, amex, au) by regex over bank name or sender.
- `exactForms(bank)` (`:86-96`): customer ID as typed and alphanumerics-only; account number and its last 4/5/6/8 digits; IFSC upper and lower.
- `candidates` order (`:98-145`):
  1. PAN upper and lower (CAS from CAMS/KFintech/NSDL/CDSL, NPS, tax docs) (10 alphanumerics).
  2. For each 4-letter prefix (from first, last and joined name parts of name then altName; prefix = first 4 letters, de-duplicated case-insensitively) in UPPER / lower / Capitalised: `+ddmm`, `+ddmmyy`, `+ddmmyyyy`, `+cardLast4`, `+last 4 of each phone`, `+birth year`.
  3. For each card last4: `ddmmyyyy+l4` (SBI Card), `ddmm+l4`, `l4+ddmm`.
  4. Pure date forms: `ddmm, ddmmyyyy, ddmmyy, yyyymmdd, mmddyyyy, mmdd, yyyy`.
  5. Phones (10 digits, last 10 of up to two): full, last 4/5/6.
  6. PAN+DOB: `PAN+ddmmyyyy` (upper and lower), `PAN[0..5]+ddmm`.
  7. `phone[-4:]+ddmm` and `ddmm+phone[-4:]`.
- `forBanks`: exact forms for every bank account first; if `combos`, per-account combination guesses using the account's own names/phones before the profile's; then profile-only guesses.
- Documented formats in the doc comment (`:51-56`): HDFC/Axis card = NAME+DDMM; ICICI/Kotak = name+DDMM; SBI Card = DDMMYYYY + last 4 of card; CAS = PAN; NPS/bank = DOB or customer details.
- Saved details are sealed (Keystore) in DataStore `statement_passwords`: saved passwords (`entries`, label+sealed), identity (7 fields name, dob ISO, PAN, phone, altName, altPhone, email, `\u001F`-separated, append-only field order), per-account details (customerId, accountNumber, ifsc, name, mobile, email) (`StatementPasswordStore.kt:24-48, 77-97, 111-125`). Account name/mobile/email fall back to the profile's when empty (`effective`, `:34-39`).
- Locked statement flow: stored locked PDF, notify once via `LockedStatementNotifier`, `unlock(id, password, remember, label)` (`:232-243`), `retryLocked()` after a password is added (`:261-270`). The email body is saved (`emailText`, capped `EMAIL_TEXT_CAP = 4000`) because "it often says what the password is" (`StatementMeta` doc, `:~42`).

### 2.4 Transaction-row parsing (card and bank PDFs/sheets)
`StatementParser.rows` (`:232-280`):
- A row = line with a `LEADING_DATE` (`^\s*(\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\d{1,2}[\s-][A-Za-z]{3}[a-z]*[\s,-]+\d{2,4})`) and at least one `AMOUNT` (`(\d{1,3}(?:,\d{2,3})*\.\d{2}|\d+\.\d{2})\s*(Cr|CR|Dr|DR|C|D)?\b`) (`:451-453`).
- `SKIP_ROW` lines (opening/closing balance, b/f, c/f, total, minimum amount, amount due, payment due, credit limit, statement date, reward, points) are skipped; an `OPENING` row seeds `previousBalance` (`:237-241`).
- Date window: reject dates after `received + 1 day` or before `received - 2 years` (`:244`).
- Description = text between date and first amount, a `SECOND_DATE` removed, trimmed of `-|` and spaces; must be `>= 2` chars.
- Bank rows with `>= 2` amounts: amount = second to last, balance = last. Card rows: last amount, no balance.
- Direction: card + `CARD_PAYMENT` words (`payment received|thank you|bbps payment|autopay|auto debit payment|neft payment|payment -`) -> `TRANSFER`; `Cr/C` -> CREDIT; `Dr/D` -> DEBIT; else balance up/down vs previous; else `CREDIT_WORDS` (refund, reversal, reversed, cashback, credit, interest credit, salary, neft cr, imps cr, by transfer, deposit) -> CREDIT; else DEBIT.
- Output `ParsedTransaction` with `source=STATEMENT`, `confidence=0.7f`, `hasExplicitTime=false`, time = noon IST of the date (`LocalTime.NOON`, `config.zone`), `transactionHash = TransactionHasher.hash(amount, type, last4, date, null)`; merchant via `MerchantNormalizer`, channel via `ChannelDetector`.
- Stored as `IncomingMessage(tx, "stmt:<key>:<i>", "<line>\n\nFrom <file>", sourceName="STATEMENT")` (`StatementProcessor.kt:310-312`), so re-reads are idempotent through the normal ingest dedup.
- Date formats `DATE_FORMATS` (`:481-485`): `d/M/uuuu, d-M-uuuu, d.M.uuuu, d/M/uu, d-M-uu, d.M.uu, d MMM uuuu, d-MMM-uuuu, d MMM uu, d-MMM-uu, d MMM, uuuu, d MMMM uuuu, uuuu-M-d`, case-insensitive, `Locale.ENGLISH`.

### 2.5 CSV / XLSX / XLS column mapping
`SpreadsheetExtractor` (`E/mime/SpreadsheetExtractor.kt`) -> rows -> `SpreadsheetLines.toText` (`S/SpreadsheetLines.kt`) -> same parser.
- XLSX: zip + `XmlPullParser` (no Apache POI): `xl/sharedStrings.xml`, `xl/styles.xml`, `xl/workbook.xml`, `xl/worksheets/sheetN.xml`; per-entry cap 40 MB, total cap 80 MB (`:311-312`); sheets sorted by number; blank row inserted between sheets (ends a holdings table). Date cells detected from style number-format ids `14..22`, `45..47` and custom formats containing d/y/m (`:189-219`) and rendered `dd/MM/yyyy` from the 1899-12-30 epoch.
- XLS: JExcelApi (`jxl`), encoding `Cp1252`, date cells rendered from GMT midnight; `PasswordException` -> Protected, `BiffException` -> Unreadable.
- Encrypted OOXML saved as OLE (`EncryptionInfo` UTF-16LE in first 1 MiB) -> `Protected` (`:109-118`). Password-protected sheets cannot be opened.
- CSV: UTF-8 strict, falls back to windows-1252; delimiter = the most frequent of `, ; \t |` in the first 20 lines; BOM stripped; quoted cells and `""` supported (`S/SpreadsheetLines.kt:106-134`).
- Numbers rendered without exponent (`BigDecimal.stripTrailingZeros().toPlainString`).
- Bank-statement sheets: header row = first row with >= 3 `HEADER_WORDS` (date, narration, description, particulars, details, remarks, withdrawal, deposit, debit, credit, amount, balance, chq, cheque, ref) (`:50, :61`). Column roles by header regex: BALANCE, DATE, DEBIT (debit/withdrawal/dr/paid out/money out), CREDIT, AMOUNT (amount/amt/transaction amount/inr/value). Rows below are formatted: debit -> `"%.2f Dr"`, credit -> `"%.2f Cr"`, amount negative -> Dr, `Cr/Dr` suffix honoured, zero in an unused debit/credit column blanked, date serial 20,000..80,000 -> `dd/MM/yyyy` (`:75-103`). Cells joined with two spaces.
- Holdings sheets (detected by `HoldingColumns.isHeader` or `isHoldingsHeader`): cells kept apart with separator `¦` (`HoldingSheet.SEP`), blank row = table end.

### 2.6 Summary totals extraction (card dues and bank totals)
`StatementParser.summary` (`:108-193`): scans the first `SUMMARY_LINES = 120` lines. Labels (`SUMMARY_LABELS`, `:410-426`): `total` (total/amount due/payable/outstanding, new balance, closing balance due, bare "amount due" with look-behinds excluding minimum/past/overdue), `min`, `due_date`, `limit` (credit limit, excluding "available"), `stmt_date`, `period`, `cash_limit`, `available`, `opening` (opening/previous (statement) balance), `closing` (closing balance not followed by "due"), `debits` (total debits/withdrawals), `credits` (total credits/deposits).
- Layouts handled: value on same line after label; several labels on one line with values between; label block (up to `LABEL_BLOCK = 8` lines) followed by value lines in the same order; period takes the end date; a `Cr` amount on total/min counts as 0.
- Table header lines (`TABLE_HEADER`: narration, particulars, description, chq, cheque, value dt, txn date, tran date) are not read as summary.
- Dates: `CardFigures.parse(s, ref, forward)` (`S/CardDue.kt:66-85`) resolves year-less dates relative to statement date (due date forward: moves to next year if it falls > 30 days before ref; statement date backward: previous year if > 30 days after).
- Amount regex `CardFigures.AMOUNT` handles Rs/INR/rupee sign/backtick, Indian grouping, Cr/Dr; `minor()` rejects values outside `0..1_000_000_000_000` paise.
- `StatementSummary` (`totalDue, minDue, dueDate, creditLimit, statementDate, opening, closing, debits, credits, available`) is saved on `StatementEntity` and used by `transactions.applyStatementToAccount(bank, last4, kind, closingBalance, creditLimit, totalDue, available, at, reconcile = msgs.isEmpty())` (`StatementProcessor.kt:318-330`). Closing balance preference: summary `closing`, else the last row's balance. `reconcile` is true only when the statement had no rows (totals only), to reveal missing transactions; otherwise gaps are filled by the stored rows.
- `at` = statement date 23:59 IST, else latest row time, else received time.
- Mail-body card dues (not PDFs): `CardDueParser` (`S/CardDue.kt:89-152`): needs word "card"; `last4` from `[x*]{2,}`, `ending (with|in|no)`, `no.`, `number`; issuer from sender's parser or 13 bank regexes; MIN and TOTAL regexes with `NUMX` (a number needs a currency sign, paise or thousands separators, so "02" in a date is never read as an amount); `DUE_DATE`, `STATEMENT_DATE`; requires a statement/bill/due word plus total or (min and due date). Failed/declined text, or missing last4, blocks the payment branch. Three `PAYMENT` regexes yield `CardDue(paymentMinor=...)`. CHANGELOG 2.9.8: reaches the right card even with "Axis"/"Axis Bank" spelling, masked/missing card number, `|` separators.

### 2.7 Holdings extraction (CAS, broker, apps, NPS, EPF)
Order inside `StatementParser.holdings` (`:291-380`):
1. `HoldingSheet.read` (cell-separated spreadsheet) using `HoldingProfiles.platformOf(sender)`.
2. EPF passbook (`EpfPassbook.isEpf`).
3. Text pass over lines: ISIN-based.
   - CAMS/KFintech CAS: scheme line with `ISIN\s*:\s*([A-Z]{2}[A-Z0-9]{9}\d)` (`ISIN_LABEL`) then `Closing Unit Balance` line; units (`CLOSING_UNITS`), NAV (`NAV on <date>: ...`), market value (`(market value|valuation) on <date>: INR x`), cost (`(total )?cost value ... x`); the figures are joined from up to 3 lines; value falls back to `round(units*nav*100)`; the same ISIN in two folios is summed; scheme code prefix `^[A-Z0-9]{2,12}-` removed; `fromClosing` rows win over table rows.
   - NSDL/CDSL demat and broker tables: a line containing an ISIN (`\b([A-Z]{2}[A-Z0-9]{9}\d)\b`, case-sensitive) with no leading date; `HoldingLines.read(before, after)`; wraps onto next 2 lines if not "consistent"; a short scheme name takes the previous line (`INF...` or non-empty `before`).
   - `kindOf(isin, name)`: ETF (`\bETF\b|\bBEES\b`) -> ETF; `INF` prefix -> MUTUAL_FUND; bond words (`bond|debenture|NCD|SGB`) -> BOND; `gold` -> GOLD; else STOCK.
   - Foreign ISINs (not `IN...`): converted at the statement's USD rate (`USD_RATE`, accepted only if within `40.0..200.0`), else omitted.
   - Only holdings with `valueMinor > 0` kept.
4. NPS Statement of Transaction (`NpsStatement.isNps`): appended to the ISIN results.
5. If nothing found: `HoldingTable.read` (Groww-style tables without ISINs, USD tables).
- `asOf` date (`:388-394`): first line in the first 120 whose label matches `AS_ON` (`holdings|statement|valuation|portfolio|balances ... as on/of/at <date>`), accepted only if within `[received - 6 months, received + 1 day]`, else `receivedAt`; stamped at noon IST.
- `HoldingLines.read` (`S/HoldingLines.kt`): trailing run of numbers/dashes/%/currency tokens; a leading all-digit token >= 6 chars among the figures is a folio, dropped; tries units at the first or second number; looks for `units x price = value` within `max(1.5% of value, Rs 1)`; right-most such pair is the value, an earlier pair (units x avg cost) or an in-between figure `< 20 x value` is "invested"; otherwise units=first, value=last, `consistent=false`. Name: part before `#` for CDSL names ("RELIANCE INDUSTRIES LIMITED#EQUITY SHARES"), serial number removed.
- `HoldingTable` (`S/HoldingTable.kt`): header found by label regexes (INVESTED, VALUE, AVG_PRICE, PRICE, UNITS, PCT, RETURNS); header may wrap onto the next line; needs VALUE plus (INVESTED or UNITS); rejects headers containing decimal numbers; per row the figures are aligned to the columns by exhaustive search, scored: `invested + returns = value` (+6, tolerance `max(1, 1%)`), `units x NAV = value` (+6, 1.5%), `units x avg = invested` (+4), penalties for unassigned tokens; `toks.size > 12` -> null. Ids: `US:<ticker>` for dollar tables, ISIN if present, `STOCK:<normalised name>` for stocks, `MF:<normalised scheme>` for funds. USD tables use `usdRate`, otherwise rows are left out. Totals rows (`TOTAL`) end the table.
- `HoldingColumns` (`S/HoldingColumns.kt`): 17 fields (NAME, SYMBOL, ISIN, AMC, CATEGORY, SUB_CATEGORY, FOLIO, SOURCE, UNITS, AVG_PRICE, INVESTED, CURRENT, PRICE, GAIN, GAIN_PCT, XIRR, AS_OF). Header normalised by `key()` (lowercase, parenthesised text dropped unless it contains `%` -> "pct", `%` -> "pct", non-alphanumerics removed), looked up in `SYNONYMS` (large per-field sets, e.g. UNITS: units, closingunitbalance, quantity, qty, netqty, shares ...; INVESTED: investedvalue, buyvalue, totalcost, valueatcost ...; CURRENT: currentvalue, marketvalue, curval, valuation, closingvalue ...), then `FRAGMENTS` (ordered; first entry `null` list ignores long-term, pledged, collateral, discrepant, day change, today's, weight, allocation). First column per field wins. `isHeader`: >= 3 known fields, a name/symbol/ISIN, a way to compute current value (CURRENT, or UNITS+PRICE, or INVESTED+GAIN), no `$`/USD header, no header cell > 60 chars; a table of dated transactions without CURRENT is not a holding.
- `HoldingSheet.read` (`S/HoldingSheet.kt`): per row: name (NAME or SYMBOL), units, gain, `current = CURRENT ?: units x PRICE ?: INVESTED + GAIN`, `invested = INVESTED ?: units x AVG_PRICE ?: current - gain` (must be > 0), ISIN validated `^[A-Z]{2}[A-Z0-9]{9}\d$`; kind: GOLD (commodity/gold/silver in category, or fundish + commodity name, not INE), ETF, MUTUAL_FUND (`INF`, folio, AMC, or fund words), else STOCK; id = ISIN, else `STOCK:<name>` or `MF:<name>`; same id summed; platform from a SOURCE column or sender; `number()` accepts `₹`, `Rs`, brackets as negative, `Cr/Dr`, ignores `%` and placeholders (`-`, NA, N/A, NIL, NULL).
- `HoldingProfiles` (`S/HoldingProfiles.kt:17-39`): 17 documented layouts, `verified=true` only for Groww MF, Groww stocks, Zerodha Console. Unverified (follow usual export, matched by header names): Zerodha Coin, Kuvera, INDmoney, Paytm Money, ET Money, Upstox, Angel One, Dhan, ICICI Direct, HDFC Securities, Kotak Securities, MFCentral, CAMS, KFintech. `platformOf(sender)` returns the first matching platform.
- `NpsStatement` (`S/NpsStatement.kt`): requires `PRAN` and one of NPS/national pension/pension fund/CRA/PFRDA in the first 60 lines; tier from "Tier I/II" headings; labels CONTRIBUTION, WITHDRAWAL, GAIN, VALUE, RETURN (XIRR ignored); scheme rows `SCHEME E/C/G/A`, `<units> <NAV> <value>` via `consistentValue`; one holding per tier `NPS:<last4>` or `NPS:<last4>:T2`; `invested = contribution - withdrawal`, else `value - gain`.
- `EpfPassbook` (`S/EpfPassbook.kt`): needs `Employees' Provident Fund|EPFO|member passbook` and `Member ID`; value = sum of last up-to-3 figures on the "Closing Balance" row (employee, employer, pension; may wrap to next line); invested = value minus the sum of "Int. Updated" rows (excluding opening rows); id `EPF:<member id alnum, uppercase>` (same key as EPFO SMS), name `EPF ••<last4>`; kind EPF; dates and `MMYYYY` month codes are stripped before number extraction.
- Deposit statements (PPF, RD, FD advice) produce no transactions; they update a deposit account via `transactions.applyLoanStatus` (`StatementProcessor.kt:299-302`): balance = summary closing, else last running balance, else "deposit/principal amount", else stated outstanding; maturity/instruction from `DepositParser.info`; account number from `DepositParser.numbered`.
- Holdings persisted: `holdings.record(r.holdings, "STATEMENT")` and a sidecar `<sha-of-key>.holdings` TSV (kind, name, id, units, value, invested, asOf) in the kept dir so the detail page can show them (`:186-205`). Old statements re-read from the kept file (`holdingsOf`).

### 2.8 Email-body investment parsing (no attachment) `StatementProcessor.readEmail` (`:129-190`)
In order: INDmoney `PortfolioSummary` (aggregate holdings `AGG:INDMONEY:<US|MF|STOCKS>`, replaced once real holdings are known, `S/PortfolioSummary.kt`); `MfOrderParser` (SIP/lumpsum confirmation: scheme, folio, amount, units, NAV, date within [received-45d, received+1d]; ignores failed, redemption, reminders); EPF mail (`EPF_MAIL = epfindia|epfo|umang|\bEPF\b.{0,40}\bpassbook\b|passbook\s+balance`) -> `InvestmentParser.parseEmail`; NPS mail (`NPS_MAIL = \bPRAN\b|\bNPS\b|npscra|proteantech|npstrust|kfintech-cra|camsnps`) -> `nps.read` contribution/holding.
- MF order dedup: key `identifier|date|amountMinor|units` stored in SharedPreferences `mf-orders` (cap `MAX_ORDER_KEYS = 500`) so Gmail+IMAP or a resend counts once; transaction suppressed if a DEBIT/INVESTMENT with the same amount exists in `[order.date - 3d, order.date + 2d]` (bank SMS usually comes first). Investment txn: type INVESTMENT, category INVESTMENT, channel AUTO_DEBIT if SIP else OTHER, confidence 0.8, bankName = platform.
- `InvestmentParser` (`S/InvestmentParser.kt`) also handles SMS: EPFO passbook balance (`passbook balance against <member> is INR x`), `EPF_ALT`, NPS value/contribution; NPS contribution accepted only if context + contribution + done words present and no NOT_DONE word (failed, pending, reminder, due, ...), date within `[received-45d, received+1d]`; keys `nps|<last4>|<tier>|<date>|<amountMinor>`; NPS SMS headers `NSDLPR, NSDLCR, NSDLNP, PROTEN, PRTEAN, PROTNC, KFINTN, KFNCRA, KFCRA, KCRA, KCRANP, CAMSNP, CAMSCR`.
- `MfOrderParser.PLATFORMS`: Groww, Zerodha Coin, Kuvera, INDmoney, Paytm Money, ET Money, CAMS, KFintech, Upstox, Angel One, Dhan, MF Central, BSE StAR MF, MF Utility, Scripbox, Fisdom.

### 2.9 Reconciliation (holdings and balances)
- Holdings check (`S/HoldingsCheck.kt`): reads stated "Total Investments / Invested value / Total cost" and "Current (portfolio/market) value / Portfolio value / Market value / Total value" in a label row over a figures row or "label  figure" rows (lines <= 160 chars, not table headers). `mismatch = |stated - rowsSum| > 100 paise (Rs 1)` for invested or value; returns null if the sheet states no totals; missing figures are null, never invented. Computed for statements that found holdings, or when no rows (`StatementParser.kt:90`).
- Effect: only a log warning ("Holdings differ from the statement's totals ...", `StatementProcessor.kt:~301-304`); rows are recorded regardless. No user-visible reconciliation UI was found in these files (Open Question 3).
- Account balance reconciliation: statement with totals only triggers `reconcile = true` in `applyStatementToAccount`; CHANGELOG 2.6.0 "Notification when a statement shows a different balance"; 2.9.5 "untracked payments detected from the next stated balance" (BalanceGaps). Implementation lives outside the files read.
- Dedup of statement rows against SMS/email rows: via `TransactionHasher.hash(amount, type, last4, date, null)` and `ingestBatch`; internals are outside Part C.

### 2.10 Limits and failure modes
- PDF: any `RuntimeException` -> `Unreadable`; locked with no matching password -> stored LOCKED, user notified; password list caps 240 / 300.
- Spreadsheet: XLSX entry cap 40 MB, total 80 MB; OOM caught -> Unreadable; password-protected xls/xlsx -> `Protected` (recorded `status=UNREADABLE`, `kind=PROTECTED`, `StatementProcessor.kt:117-122`). XLS date cells assume GMT midnight.
- Row filters: 2-year look-back, +1 day future; `amount <= 0` dropped; description < 2 chars dropped.
- Header windows: 40 lines (kind/bank/last4), 120 lines (summary and as-of), 60 lines (NPS), 40 lines (EPF).
- Holdings: `HoldingTable.align` skips rows with more than 12 figure tokens; USD tables without a rate are omitted; ISIN rows whose `INF` name is < 3 chars after joining are dropped.
- Email: 5 attachments per IMAP message; 4000 chars of email text retained per locked statement; `StatementEntity` status values `PARSED`, `EMPTY`, `LOCKED`, `UNREADABLE`.
- Same PDF is read once: `existing != null && status != LOCKED` returns empty (`StatementProcessor.kt:103-104`); key `"<msgId>#pdf<i>"` for email.
- Statements read before 1.10 were not kept, so they cannot be re-read (`canReread`, `:~257`).

---

## 3. Version history and known gaps

### 3.1 CHANGELOG highlights (`CHANGELOG.md`; numbers are not contiguous; first versioned release is 1.1.0)
| Version (date) | Highlights |
|---|---|
| 1.1.0 (2026-09-30) | Email by address + app password over IMAP with 6-digit verification code; password sealed with Keystore; Google sign-in as advanced option; one "Fetch history" window 7-365 days; month navigation; optional user balance; fixed SMS pre-filter dropping bank SMS, OTP rejection |
| 1.7.0 (2026-10-05) | Statement reading (card, bank, CAS/broker PDFs) with saved passwords; EPF/NPS from SMS; MF and stocks from CAS; multiple inboxes; budgets; recurring payments with low-balance alerts; in-app updates from GitHub Releases verified by SHA-256 |
| 1.9.0 (2026-10-05) | Redesigned Home; 91 bundled brand logos; analytics filters; personal/business accounts |
| 1.10.0 (2026-10-05) | Profile; sub-categories; email view; statements read opening/closing/debits/credits/available limit and can be re-read; app-password guide per provider |
| 1.11.0 (2026-10-05) | First-run sign-in; bills calendar; account/card/deposit tabs; nightly email sync |
| 1.12.0 (2026-10-05) | Locked statements show the mail as password hint; passwords remembered and retried on every locked/new PDF |
| 1.13.0 (2026-10-06) | Forex rates; DOB+PAN in profile drive password guesses; FD/RD maturity; statement mails picked by subject (CAS, NPS, EPF); Outlook app-password steps; balance-only alerts not credits |
| 2.0.0 (2026-10-06) | Five-tab redesign from the prototype; global Book and Period; removed goals, split and lend, credit score, manual tax inputs (rule: only features fed by SMS/email/statements/notifications) |
| 2.1.0-2.4.0 (2026-10-06/07) | Rules, tax centre overrides, Excel/CSV statements, Groww-style emails, alt name/mobile for passwords, loan tracker, themes, language packs; renamed Artha |
| 2.6.0 (2026-10-07) | Renamed DhanKosh; activity log; NBFC loans; NPS and Groww holdings; "statement shows different balance" notification; 7 language packs |
| 2.7.0 (2026-10-07) | Holdings statements from Groww etc. (Excel/CSV/email) summed per scheme and checked against sheet totals; Credit cards card on Home |
| 2.8.0 (2026-10-08) | Reversible account merge; per-account unlock details (customer ID, account no., IFSC, name, mobile, email); ~55 more banks with sender codes and mail domains |
| 2.9.0 (2026-10-10) | Spent-this-month card; card due tracking and reminders; payment-app notifications broadened; holdings read by column names |
| 2.9.5 (2026-10-11) | Untracked payments detected from next stated balance; own-account transfers record both legs; card bill payments never spend |
| 2.9.8 (2026-10-12) | Card page shows figure provenance; Tax centre FY choice and latest rules; manual edit of card figures survives older statements; statement mail reaches the right card despite name/mask differences |

CHANGELOG mentions the Gmail API path only as the advanced option; no later change to it is listed.

### 3.2 Known gaps and TODOs (`doc/PLAN.md`, `doc/SPEC_NOTES.md`, wiki)
Open `[~]` items in PLAN.md:
- 1.13.0: Outlook needs two-step verification before app passwords appear; Microsoft OAuth not built (needs an Azure app registration).
- 1.13.0: GitHub wiki pages are in `doc/wiki/`, waiting for the wiki to be enabled, then push to `hisaab_apk.wiki.git`.
- 2.4.0: Language packs (infra done; later marked translated in 2.5.0).
- 2.9.0: Transfers/payments with no message: untracked-change detection (BalanceGaps) "tests written, build unverified".
Other "unverified / not run on a device" statements:
- 2.0.0 to 2.8.0: "Built + tests pass; not yet run on a device".
- 2.9.0: card-bill detection (`CardBill.kt`) "shared/app build unverified"; Tax centre "app and TaxIncome compile unverified".
- 2.7.0: Support page needs UPI ID/QR (later marked done in 2.9.0).
- `HoldingProfiles`: only Groww MF/stocks and Zerodha Console layouts are verified against a real export (`HoldingProfiles.kt:10-11, 18-22`).
`SPEC_NOTES.md` "Ideas not built yet (tracked-data only)": bank-charges "leakage" insight; card utilisation > 30% insight; EPF missing-month insight; statement balance reconciliation tick; commerce enrichment (order email <-> UPI debit); FTS search. Out of scope by rule: goals, split and lend, credit score, manual assets, market prices, Account Aggregator.
Wiki (`doc/wiki/Email-and-statements.md`) statement coverage: card and bank statements from supported banks, CAS (CAMS, KFintech, NSDL, CDSL incl. INDmoney-forwarded), NPS (Protean, KFintech, CAMS CRA), EPF passbooks; mails picked by sender or subject; lock-guess order: saved passwords, then PAN, NAME+DDMM, name+DDMM, DDMMYYYY+last 4 of card, DOB and mobile variations. Privacy page: DOB/PAN/passwords sealed with Keystore; statement PDFs kept in app-private not-backed-up storage; uninstall deletes all.
Code-level gaps observed (not in PLAN):
- Gmail query only OR-matches the literal `STATEMENT_SUBJECTS`, while IMAP/incremental use the broader regex (1.7).
- IMAP downloads from `\All` folder or INBOX only, no label/folder choice; date-only comparison means up to a day of overlap each run (intentional).
- No Outlook/Yahoo OAuth; app-password only (`appPasswordUrl` shown in UI).
- Password-protected spreadsheets cannot be opened.
- Holdings mismatch is logged but not surfaced in the UI from these files.
- README-level wiki/docs still say "Hisaab"; the code, release title and CHANGELOG use DhanKosh (and "Artha" briefly), but `sendToSelf` uses from-name "DhanKosh" and subject "DhanKosh verification code" while package id remains `com.hisaab.app`.

---

## 4. v2 spec (`v2_design/Hisaab_Product_Spec.md`, 883 lines, "Version 2.0 draft, October 2026") and prototype

### 4.1 Declared targets and decisions
- Audience line (`:6`): "Hisaab v2 (Android and iOS, **Kotlin Multiplatform**)". Chart libs: Vico (Compose) plus custom Canvas for donut, sankey, treemap, heatmap, "all of them work in **Compose Multiplatform**" (`:446`). Phase 5 is "KMP iOS app" (`:834`).
- The spec never mentions Flutter (grep for "flutter": no hits). The Flutter plan is therefore a deviation from the spec's declared target; the spec's choice of KMP rests on reusing the existing Kotlin `parser-core` ("`parser-core` already does this on the JVM", `:269`).
- Storage: SQLCipher-encrypted Room DB with key in Keystore/Keychain (`:797`); SQLite FTS5 for search; Paging 3; Baseline Profiles; WorkManager/BGTaskScheduler (`:783-789`). Vico, Room, WorkManager are Android/Kotlin-specific names.
- Privacy: no server, no account, no analytics; only network calls = email (IMAP/OAuth) + public price files (AMFI, NSE/BSE, gold rate) (`:800`). OTPs "detected and never stored" (`:803`).
- Play Store note: `READ_SMS` is restricted; needs a Permissions Declaration or sideload distribution (`:806`).
- iOS: no SMS or notification listener; uses Shortcuts "Message received" bridge via App Intents (`:63`).

### 4.2 Principles (8)
Zero manual entry by default; one transaction recorded once; private by design; fast (Home < 400 ms, cold start < 1.2 s, charts < 100 ms); explainable numbers; CA-grade accuracy (transfers, refunds, capital gains by tax year, GST/TDS); personal + business (+ Family) books; customisable not cluttered.

### 4.3 Data sources (section 2)
Source matrix: SMS (Android only), Email (IMAP app password or Gmail OAuth; 15 min to hourly sync), app notifications (Android only), statement import (PDF/CSV/XLS), iOS Shortcuts bridge, share sheet, receipt OCR (ML Kit/Vision), optional Account Aggregator (phase 4, needs FIU/TSP and a server), market prices (daily AMFI NAV, NSE/BSE bhavcopy, gold), manual entry.
Statement formats priority list (16): bank account, credit card, MF CAS, depository CAS, broker contract notes/P&L, EPF passbook, NPS SOT, PPF, FD/RD advice, loan statements, insurance schedules, AIS/TIS/26AS, Form 16/16A, GSTR-2B, SGB.
Password handling: per-issuer pattern library (editable), try known patterns on PAN/DOB/name/card numbers, ask only if all fail, remember the working pattern.
Sender registry (`:92-108`): versioned JSON per sender with `sms_headers`, `email_domains`, `notification_packages`, `statement_parsers` (e.g. `hdfc_savings_pdf_v3`), `password_patterns` (`{CUSTID}`, `{NAME4}{DDMM}`). DLT headers `XX-HDFCBK-S`: strip prefix/suffix, drop `-P` promotional.

### 4.4 Data model (section 4, `:204-222`)
```
Book (Personal | Business | Family member)
 └ Account (bank, card, wallet, cash, loan, investment, deposit, retirement)
    └ Transaction: amount, currency, direction, date-time, value date;
       type EXPENSE|INCOME|TRANSFER|INVESTMENT|REDEMPTION|LOAN_EMI|REFUND|FEE|TAX;
       category, sub-category, tags[], merchant, counterparty; book_id,
       excluded_from_totals, split[]; gst{gstin,taxable,cgst,sgst,igst,itc_eligible} (business);
       evidence[] -> RawMessage(sms|email|notification|statement_line); confidence 0-1, needs_review
Holding (instrument, units, lots[], cost, current value, price_date)
Lot (buy date, units, price, charges) -> FIFO capital gains
Recurring (merchant, amount band, period, next_due)
Budget (category|tag|merchant, period, limit, rollover)
Goal (target, date, linked holdings)
Rule (conditions -> actions)
Insight (type, severity, payload, dismissed_at)
```
Pre-aggregated tables: `daily_category_totals`, `monthly_account_totals`, `holding_daily_value`; `insights` and `forecasts` tables read by UI (`:595, :783`).
Key rules: own-account transfers matched by amount, +-2 days, reference no.; card bill payment is a transfer; refund linked to original debit (reduces category, not income); investments shown in Invested not Spend; every transaction links to source messages.
Dedup fingerprint `hash(account_mask, amount, direction, date +-1 day, ref_no?)`; statement line matches -> verified tick and fill gaps; statement line with no match -> insert; SMS with no statement line after close -> "Unverified"; two identical txns kept if different ref or time gap > 2 min.
Balance reconciliation: statement closing vs computed (opening + credits - debits): green tick or "Rs X unexplained".
Classification order: user rules, user history, built-in merchant dictionary (~5,000 merchants, MCC), keyword heuristics, uncategorised -> Review queue. Rules engine: ~14 condition fields, operators equals/contains/regex/between/>/</in-list, actions incl. split %, rename merchant, mark recurring, ignore; "apply to past" with live preview count.

### 4.5 Navigation and UI (sections 7-11, 17; prototype)
- 5 tabs: Home, Transactions, Portfolio, Analysis, More. Global: Book switcher (Personal / Business / Family / All books), Period chip (This week, This month, Last month, This FY, Last FY, Last 12 months, Custom), privacy eye, global search. FAB on Transactions: Add expense/income, Transfer, Scan bill, Import statement, Split with friend.
- Home widgets (12): Net worth hero, Cash flow, Safe-to-spend, Upcoming 7 days, Insights carousel, Spend donut, Accounts strip, Recent transactions (default on); Budget rings, Goals, Credit score, Market today (default off). Presets: Minimal, Spender, Investor, Business owner, CA mode, Reset.
- Transactions: summary strip, filter chips (account, category, type, source, tag, book, amount range, status), review banner with swipe accept/change, day-grouped list with verified tick, row swipe, multi-select bulk edit, detail sheet with Evidence, views List / Calendar heatmap / By merchant / By category.
- Portfolio: header with XIRR, allocation donut with target overlay, net worth stacked area, holdings list, retirement corpus, liabilities, maturity calendar; optional MF analytics, stock analytics, capital gains, family view; holding detail with price chart and lots.
- Analysis sub-tabs: Spending, Cash flow, Trends, Budgets, Forecast, Compare (the prototype has only Spending, Cash flow, Forecast, Compare).
- More: Budgets, Goals, Bills & subscriptions, Tax centre, Business, Split & lend, Rules, Data sources, Customise, Security.
- 19-chart catalogue; universal drilldown KPI -> group -> category -> merchant -> transaction -> evidence with breadcrumb; cross-filtering on Analysis; three separate controls: show/hide (visual), exclude from calculations, book separation; calculation settings table (month start, FY, number format, count investments as savings/expense, card spend on txn vs bill date, ignore below).
- Design tokens (`:664-678`): bg `#F7F7F5/#0E0F12`, surface `#FFFFFF/#17191E`, surface-2 `#F0F0EC/#20232A`, text `#16181D/#ECEDEF`, text-2 `#5D626C/#A1A6B0`, border `#E6E6E1/#2A2D35`, accent `#2F5BEA/#7C9BFF`, positive `#13895A/#3CCB8B`, negative `#D2453B/#FF7B70`, warning `#C98A0B/#F2B84B`, transfer `#7A808A/#8B919C`; category palette 8 colours; Inter/SF Pro, tabular numerals; card 16 px radius/padding, 1 px border, no heavy shadows; list row 56 px, avatar 36 px; chip 32 px; motion 200/300/400 ms; contrast >= 4.5:1; "View as table" for every chart; up to 200% font scale.
- Performance budget (`:765-779`): cold start < 1.2 s, warm < 400 ms, tab switch < 100 ms, chart < 50 ms, 60 fps with 50,000 rows, search < 150 ms, initial SMS scan of 10,000 < 20 s, 10-page statement PDF < 3 s, APK < 20 MB, battery < 1%/day, memory < 150 MB.
- Prototype (`Hisaab_UI_Prototype.html`, 465 lines, single-file dummy-data HTML/JS): phone frame with top bar (Book pill, Period pill, privacy eye, theme moon, calculation-settings gear), bottom nav 5 tabs, `home()` with edit mode and presets, `txns()` with chips All/Expense/Income/Transfer/Investment/Needs review, In/Out/Net strip, review banner, List/Calendar/By merchant, `portfolio()` (value, XIRR, allocation donut, net worth 1M/6M/1Y/3Y/All, holdings groups, maturity calendar), `analysis()` segments Spending/Cash flow/Forecast/Compare (sankey, month bars, heatmap, top merchants, fan chart, goal ETA, cash 30 days, diverging bars), `more()` list of 10 rows, bottom sheets `openCat/openMerch/openTx/openMonth/openSettings/openPick`. Persists widget order/hidden in `localStorage` key `hisaab_w`.

### 4.6 Insights, forecasts, business, tax, alerts
- Insights (rule-based, incremental, <= 5 on Home, cooldowns): spending (category spike > 1.3 x 3-mo avg and > Rs 2,000, merchant habit >= 12 in 30 days, late-night > 35%, small leaks), recurring (price hike > 5%, unused, duplicates), cards (utilisation > 30%, only minimum paid, due soon <= 3 days, forex markup), banking (idle cash > 3x expenses for 60 days, bank charges, low balance), investments (regular plan drag, overlap > 50%, concentration > 15%, SIP missed within 3 days, allocation drift > 5 pts), retirement (EPF missing month, 80CCD(1B) < 50k by Jan, PPF reminder), tax (80C, LTCG harvesting, advance tax dates, TDS mismatch vs AIS/26AS), positive.
- Forecasts (<20 ms, on-device, cached): month-end spend with P25-P75 band (daily discretionary median of last 90 days x days left + known recurring), safe-to-spend/day, 30-day cash projection, bill prediction, recurring period detection (7/30/90/365 days +- tolerance), goal ETA (equity 11%, debt 7%), net worth projection, FIRE number (x25, inflation 6%), loan payoff with prepayment, anomaly z-score > 3.
- Business: P&L, client receipts, receivables ageing (0-30/31-60/61-90/90+), payables, expense claims, GST (GSTIN, CGST/SGST/IGST, ITC, GSTR-2B reconcile, due reminders), TDS (194J) vs 26AS/AIS, presumptive 44AD/44ADA, cash vs digital receipts, KPIs (revenue MTD, burn, runway, DSO).
- Tax centre: versioned config (not code), "Income-tax Act 2025 replaces 1961 Act from 1 April 2026", income summary by head, deductions tracker (80C, 80CCD(1B)/(2), 80D, 80E, 80G, 80TTA/TTB, 24(b)), regime comparison, capital gains (FIFO, 31 Jan 2018 grandfathering, schedule 112A CSV), AIS/26AS reconciliation, advance tax (15 Jun 15%, 15 Sep 45%, 15 Dec 75%, 15 Mar 100%; 234B/C), documents vault, ITR export pack.
- Alerts (11) with quiet hours and max 3 notifications per hour.
- Roadmap (`:826-834`): P1 Spend core (95% parse rate on golden corpus for top 20 banks) -> P2 Cards & bills (card statement reconciliation within +-Rs 1) -> P3 Portfolio (XIRR within 0.1% of CAS) -> P4 Tax & Business (capital gains match broker P&L) -> P5 iOS + polish (KMP iOS, Shortcuts bridge, widgets, forecasts, family books, optional AA). P1 is labelled "current Hisaab ++".
- Acceptance checklist: 13 items (transfer never spend; card bill not double-counted; refund reduces category; SMS+email+statement -> one record with 3 evidence links; every segment drills down; hide widget vs exclude category; app-wide filters; Indian format; cold start < 1.2 s with 50k txns; works in flight mode; View as table + screen-reader labels; OTPs never stored; tax limits from config).

---

## 5. Planned (v2) versus existing app: delta

Legend: **E** = exists in `hisaab_apk` today (per code/CHANGELOG), **P** = proposed in the v2 spec only, **~** = partially present.

### 5.1 Platform and architecture
| Item | Existing | v2 spec |
|---|---|---|
| Platforms | Android only (APK, GitHub Releases) | Android + iOS (**P**) |
| Stack | Kotlin, Hilt, Room, DataStore, WorkManager, JavaMail, Ktor, PdfBox-Android, Jsoup, JExcelApi, Compose (per prior files); `parser-core` is a pure JVM module | Kotlin Multiplatform + Compose Multiplatform (**P**); Flutter not mentioned |
| DB | Room (DB v15 at 2.8.0 per PLAN); encryption of the DB itself not shown in files read | SQLCipher-encrypted Room (**P**) |
| Search | basic search bar with match count (1.9.0) | FTS5 (**P**; listed as unbuilt in SPEC_NOTES) |
| Sender registry | Kotlin classes per bank parser (`senderKeys`, `emailSenders`), `STATEMENT_SENDERS` list in code | Versioned JSON registry incl. notification packages and statement parsers per sender (**P**) |
| Statement password library | Code (`PasswordGuesser`) plus user-saved ones; "remember the working pattern" not implemented (it retries all patterns each time) | Editable per-issuer pattern library, remember working pattern (**P**) |
| Backup/export | Not covered in files read | Encrypted backup (local, Drive, iCloud), CSV/XLSX/PDF export (**P**) |
| SMS DLT `-P` drop | Not verified (outside files read) | Spec rule (**P**) |

### 5.2 Data sources
| Item | Existing | v2 |
|---|---|---|
| SMS inbox + live | E (Android) | E |
| Email IMAP app password with verification code | E (multi-inbox, 7 provider presets) | E |
| Gmail OAuth (gmail.readonly) | E (advanced option) | E |
| Email sync interval | once nightly ~02:30 + manual | 15 min to hourly (**P** change) |
| App notifications (PhonePe, GPay, Paytm, Samsung/WhatsApp Pay ...) | E | E |
| Statement import PDF/XLS/XLSX/CSV | E (email attachment or file picker) | E |
| iOS Shortcuts bridge, share sheet, receipt OCR | not present | **P** |
| Account Aggregator | explicitly out of scope | optional **P** (phase 4/5) |
| Market prices (NAV, bhavcopy, gold) | out of scope (SPEC_NOTES); news RSS only (2.3.0) | **P** (once a day) |
| Manual entry | ~ (manual card/account, loans, transactions) | E+ (cash, real estate, jewellery, vehicles **P**) |

### 5.3 Statements and instruments
| Item | Existing | v2 |
|---|---|---|
| Card/bank statement rows | E | E |
| MF CAS (CAMS/KFintech), NSDL/CDSL CAS | E (holdings with units, value, cost) | E; lots and XIRR **P** |
| EPF passbook, NPS SOT, PPF/RD/FD | E (balance and maturity; EPF employee/employer/pension sum) | E; EPS pension, UAN, employer change **P** |
| Broker holdings sheets | E (17 profiles, 3 verified) | E; contract notes, P&L, tax lots **P** |
| Lots / FIFO capital gains / XIRR | not present (holdings snapshots only: units, value, invested) | **P** |
| Loan statements | ~ (lender SMS/email, EMI tracker, amortisation) | E+ (statement parsing, prepayment simulator **P**) |
| Insurance policies/premiums | ~ (insurance renewals from 1.7.0) | policy schedule parsing **P** |
| AIS/TIS/26AS, Form 16, GSTR-2B | not present | **P** |
| SGB, bonds, crypto, ESOP, US stocks | US stocks via INDmoney (USD table with statement FX rate); SGB name heuristic -> BOND; others no | **P** (full coverage) |
| Statement balance reconciliation tick | partial (unexplained-gap detection, notification); UI tick listed as "not built" in SPEC_NOTES | **P** (tick + "Rs X unexplained") |

### 5.4 Data model
| Item | Existing | v2 |
|---|---|---|
| Transaction types | CREDIT, DEBIT, TRANSFER, INVESTMENT (seen in parser; plus categories) | 9-type enum incl. REDEMPTION, LOAN_EMI, REFUND, FEE, TAX (**P**) |
| Books | Personal / Business (global Book chip) | + Family member books (**P**) |
| Evidence | source messages kept per transaction ("View Details"/source text) | E (as `evidence[]`) |
| Tags, notes, receipt photo, splits | not seen | **P** |
| GST fields | not present | **P** (Business only) |
| Lots / Recurring / Budget / Goal / Rule / Insight entities | Budgets, recurring, rules exist; goals removed in 2.0.0 | Goal restored **P** |
| Confidence / needs_review | `confidence` field and review queue (E) | E |
| Pre-aggregated tables | not seen | **P** |

### 5.5 Product features
| Feature | Existing | v2 |
|---|---|---|
| 5-tab layout, Book + Period chips, eye mask, widget edit + presets | E (2.0.0) | E |
| Home widgets | net worth (moved to Portfolio in 2.9.0), spent-this-month, credit card dues, upcoming, insights, donut, recent, budget rings; Safe-to-spend removed in 2.9.0 | Net worth hero and Safe-to-spend **P** on Home |
| Goals, Split & lend, Credit score | deliberately removed 2.0.0 | restored **P** (More, Forecast, Home off-by-default widget) |
| Transactions: search, type chips, review, List/Calendar/By merchant | E; filters changed to Type/Bank/Source dropdowns (2.7.0) | E; adds By category, bulk edit, swipe actions, amount/tag/status filters **P** |
| Analysis | Spending, Cash flow, Forecast, Compare (2.0.0) | + Trends, Budgets sub-tabs **P**; 19-chart catalogue (some **~**) |
| Insights | ~ (generic insights; list of unbuilt ones in SPEC_NOTES) | full rule set with cooldowns **P** |
| Forecasts | month-end fan, cash 30 days (E) | + bill prediction, goal ETA, FIRE, net worth projection, anomaly **P** |
| Tax centre | E (latest FY rules, old vs new regime, income from data, what-if, shareable image/PDF) | + capital gains FIFO, AIS reconciliation, advance tax, vault, ITR pack **P** |
| Business mode | ~ (Business book only; Business tab "Business book" listed, no GST/receivables) | full Business finance mode **P** |
| Card dues, bill reminders (5/2/0 days, overdue), billed/unbilled, billed estimates | E (2.9.0+) | E (spec: 5 days, 1 day) |
| Loans tracker | E | E |
| Forex rates and per-card markup | E | markup insight **P** |
| Commerce enrichment (Swiggy order email <-> UPI debit) | not built | **P** |
| Language packs (7 languages) | E (download on demand) | not mentioned in spec |
| Themes (many incl. Hero, Cinema, soft palettes) | E | spec: Light/Dark/System + 6 accent presets, density, cover style |
| Alerts | card bill reminders, low-balance, budget thresholds, new-transaction notifications | 11-alert table, quiet hours, <= 3 per hour **P** |
| Accessibility ("View as table", TalkBack labels, 200% font) | text size 4 options (capped) | **P** |
| App lock | E ("App lock keeps the current screen", Security & backup) | E |
| Support/donate page, in-app updates from GitHub Releases (SHA-256) | E | not in spec |

### 5.6 Roadmap mapping
Existing app roughly equals spec phases P1 and parts of P2 (card statements, bills, budgets, notification listener, Spending/Cash flow/Forecast/Compare) and P3 (CAS, EPF, NPS, PPF, FD/RD, net worth, allocation), but without prices, XIRR, lots. Not started: P4 (capital gains, AIS, Business/GST, receivables), P5 (iOS), Account Aggregator.

---

## Open Questions
1. `SenderKeys.candidates(from)` (parser-core `registry/SenderKeys`) was not in scope. The doc comment says subdomains match (`alerts.sbi.co.in` for `sbi.co.in`), but how it builds candidates from a display-name+address From header is unconfirmed.
2. `MimeParser.LINE` (`E/mime/MimeParser.kt:92`) shows as a plain space in the extracted source. If that is literal, `replace(LINE, "\n")` would turn every space into a newline; the real file very likely uses a special marker character lost in transcription. Needs a byte-level check.
3. Where (if anywhere) a `HoldingsCheck.mismatch` reaches the user. In `StatementProcessor.messages` it is only logged (`java.util.logging` warning). PLAN 2.7.0 says "check against the sheet's totals" but the UI side is outside the files read.
4. Default bank email domains (`BaseBankParser.emailSenders`) are not enumerated here; they live in per-bank parsers outside Part C.
5. `StatementEntity` / `ProcessedEmailEntity` / `HoldingRepository.record` internals and the `ingestBatch` dedup/merge logic (shared module) were not read, so the exact statement-row vs SMS/email merge rule is unverified.
6. Whether the Gmail API path is still actively used: PLAN/CHANGELOG describe IMAP as the main connect flow; `GmailSettingsStore.connection` falls back to GOOGLE only for installs that pre-date IMAP. No UI file was read to confirm the Google button is still offered.
7. The user's v2 target is "Flutter" (per the task framing and the `hisaab_flutter` folder), but the spec says Kotlin Multiplatform; no document read here records the decision to switch. Treat as undecided until the Flutter plan document is read.
8. Spec says email sync "15 min to hourly"; the existing nightly 02:30 schedule is a deliberate battery choice (`GmailScheduler` comment). Whether v2 intends to reverse that is not stated.
9. `StatementProcessor` constant `EPF_MAIL`/`NPS_MAIL` apply only to emails not already matched as MF orders; whether EPF/NPS statement PDFs sent by those senders also arrive as attachments handled through `read()` is inferred from `EpfPassbook`/`NpsStatement` existing in `StatementParser`, not from a sender-specific test.
10. Spec section 15 claims the Income-tax Act 2025 replaces the 1961 Act from 1 April 2026; this was not verified against the existing Tax centre code (`TaxRules` is in `shared/insight`, not read).
