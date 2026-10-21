# Scan 6: Screens below the route level (dialogs, sheets, menus, gestures, components)

Paths relative to `hisaab_apk/app/src/main/kotlin/com/hisaab/app/ui/` (U/). Coverage checked by grepping `memory/*.md` for class names and t("...") labels. Route list is in scan_1_ui.md and not repeated.

| # | Screen/dialog/sheet/menu action | Where found (file:line) | Memory file | Coverage | Action | Notes |
|---|---|---|---|---|---|---|
| 1 | Welcome: choose / details modes ("Continue with email/phone", "Use email instead", "Skip for now", "Finish") | U/onboarding/WelcomeScreen.kt:131-179 | 01 | Full | None | |
| 2 | EmailConnectDialog (provider list, guide, 6-digit code, "Resend code", "Too many wrong tries") | U/settings/EmailConnect.kt:145; AppPasswordGuide.kt | 03 | Full | None | Welcome passes onUseGoogle=null |
| 3 | SMS permission card + blocked state ("Open App settings", "Not now") | U/components/SmsPermission.kt | 01, 17 | Full | None | |
| 4 | ProfileSetupSheet ("Later") | U/profile/ProfileScreen.kt:332 | 01, 27 | Full | None | |
| 5 | LockScreen ("DhanKosh is locked", Unlock) | U/lock/LockScreen.kt:25 | 25 | Full | None | |
| 6 | Home header: greeting, eye toggle, Accounts icon, bell badge | U/home/HomeParts.kt:48-99 | 17 | Full | None | |
| 7 | NotificationsSheet | U/home/HomeParts.kt:111 | 17 (also 07) | Full | None | |
| 8 | Home FAB "Sync everything" | U/home/HomeScreen.kt:278 | 17 | Full | None | |
| 9 | Home RecurringSheet launch | U/home/HomeScreen.kt:120 | 12, 17 | Full | None | |
| 10 | Home widgets: Spent this month, Credit card dues, Cash flow, Safe to spend, Upcoming + "Calendar ›", Insights (Heads up/Dismiss), By category + Trends, Recent, Budgets | U/home/HomeWidgets.kt, SpentThisMonth.kt | 17 (+12, 28) | Full | None | ProgressRing/Sparkline not named as components but behaviour specced |
| 11 | Section move up/down, hide; presets Minimal/Spender/Investor/Business/Everything | U/home/HomeWidgets.kt:124, U/settings/CustomizeTabsScreen.kt | 28 | Full | None | |
| 12 | Customise: theme mode, palettes (Classic/Hero/Cinema), pure black, text size | U/settings/CustomizeTabsScreen.kt | 28 | Full | None | |
| 13 | Transactions filter chips + DropdownMenu (type/bank/source) | U/transactions/TransactionViews.kt:155-170 | 20, 08 | Full | None | |
| 14 | Period sheet incl. custom date-range DatePickerDialog; Book sheet | U/ledger/FilterChips.kt:64-129 | 20 | Full | None | |
| 15 | Long-press multi-select (Select all, Merge, Change category, Delete, Cancel), merge Undo snackbar | U/transactions/TransactionsScreen.kt:137-310 | 08 | Full | None | Bulk-category picker title "Category for {n}" covered |
| 16 | Needs-review strip, Bills shortcut, Add FAB | U/transactions/TransactionViews.kt:241; TransactionsScreen.kt:149-157 | 08, 07 | Full | None | |
| 17 | Daily heat calendar + By-merchant view | U/transactions/TransactionViews.kt:108-463 | 08 | Full | None | |
| 18 | TxSummaryStrip | U/transactions/TxSummaryStrip.kt | 08 | Full | None | |
| 19 | Transaction detail: delete AlertDialog, "Account for this payment" dialog with "Remember for {payee}", note Save, forex "In rupees", category/sub-category sheets, split out | U/transactions/TransactionDetailScreen.kt:102-271 | 08 | Full | None | |
| 20 | MessageView: "Copy text" icon, "Show all/Show less/Show full email", "The original text wasn't kept for this one.", source captions | U/components/MessageView.kt:82-140 | 08 (mentions MessageView), 07 | Partial | Expand file (08) | No FR for copy-to-clipboard action, collapse/expand lines, or the "original text not kept" empty state |
| 21 | Add transaction: segmented Payment/Transfer/Money received, date + TimePicker AlertDialog, account dropdown, category sheet, screenshot fill | U/add/AddTransactionScreen.kt:271-449 | 08 | Full | None | |
| 22 | Gap prompt (Assign / Looks like) + GapCard | U/accounts/GapCard.kt | 13 | Full | None | |
| 23 | Review: Compare / Keep both / Merge | U/review/ReviewScreen.kt:99-228 | 07 | Full | None | |
| 24 | CategorySheet + create category (NewItemDialog name/icon/colour); IconLibrary | U/components/CategorySheet.kt:44-103 | 09 | Full | None | |
| 25 | SubcategorySheet / "New sub-category" dialog | U/category/CategoryParts.kt:115-183 | 09 | Full | None | |
| 26 | Rules: ExtendedFAB, edit sheet, nested category/new sub-category | U/more/RulesScreen.kt:189-377 | 09 | Full | None | |
| 27 | BudgetDialog (add/edit/delete) + ExtendedFAB "Budget" | U/budgets/BudgetsScreen.kt:136-258 | 10 | Full | None | |
| 28 | Analytics: donut tap/long-press, MonthSheet, top-merchants sheet (latest 60), heatmap | U/analytics/AnalyticsScreen.kt:213-395 | 18 | Full | None | |
| 29 | Analytics segments: Sankey, savings-rate chart, FanChart forecast, cash projection, period compare, budgets pace | U/analytics/AnalyticsSegments.kt, AnalyticsBudgets.kt | 18, 11 | Full | None | FanChart/StackedArea/HeatGrid not named, behaviour specced |
| 30 | ProtoCharts.kt (Sparkline, ProgressRing, StackedMonthBars, StackedArea, Sankey, FanChart, HeatGrid) | U/charts/ProtoCharts.kt | 18, 11, 17 | Partial | None | Not dead (used by Analytics/Home/Loans); no shared chart-component spec, only per-feature. Low risk |
| 31 | Accounts: FAB, overflow "Restore missing accounts", 3 tabs | U/accounts/AccountsScreen.kt:303-316 | 13 | Full | None | |
| 32 | AddAccountSheet (segmented account/card, bank chips, type, network, deposit MaturityAction, maturity DatePicker) | U/accounts/AccountForms.kt:88-181 | 13 | Full | None | |
| 33 | EditSheet (usage segmented, nickname, hide, type chips), MergeDialog, DeleteAccountDialog | U/accounts/AccountsScreen.kt:398-846 | 13 | Full | None | |
| 34 | BankDetailsSheet | U/accounts/BankDetailsSheet.kt | 13, 05 | Full | None | |
| 35 | Account detail segmented control + CardAmountsSheet + due-date picker | U/accounts/AccountDetailScreen.kt:208; CardAmountsSheet.kt:83 | 13, 14 | Full | None | |
| 36 | CardBill / CardDueActions (Mark paid, Remind tomorrow) | U/accounts/CardDueActions.kt | 14, 21 | Full | None | |
| 37 | Portfolio FAB, HoldingSheet (kind chips), PPF/EPF/NPS section, loans section | U/invest/InvestmentsScreen.kt:172-236; PortfolioSections.kt | 16 | Full | None | |
| 38 | Statements: UnlockDialog (remember pw), AddPasswordDialog, StatementDetail | U/invest/StatementsScreen.kt:231-340 | 05 | Full | None | |
| 39 | Loans: FAB, AddLoanSheet, TermsSheet, MergeIntoSheet, RemoveLoanDialog, LinkSheet, LoanLinkSheet prompt | U/loans/LoansScreen.kt:216-869; LoanLinkSheet.kt | 15 | Full | None | LoanDismissals covered |
| 40 | Bills: FAB, RecurringSheet (Expense/Income, monthly/yearly, month + account dropdowns) | U/plan/BillsScreen.kt:105-114; RecurringEditor.kt:71-165 | 12 | Full | None | |
| 41 | Tax: TaxEditSheet (Calculate/Reset/Back to calculated), share "Share with amounts?" dialog + share sheet | U/more/TaxWhatIf.kt:92; TaxShare.kt:68-93 | 19 | Full | None | |
| 42 | Data sources: SendersDialog, EmailConnect, "Disconnect email?" | U/more/DataSourcesScreen.kt:314-376 | 26, 03 | Full | None | |
| 43 | Activity log clear dialog | U/more/ActivityLogScreen.kt:177 | 22 | Full | None | |
| 44 | Forex RateDialog (currency chips, date picker) + FAB | U/settings/ForexRatesScreen.kt:101-198 | 23 | Full | None | |
| 45 | Profile + PhotoCropDialog; StatementDetails (PAN/DOB date picker) | U/profile/PhotoCrop.kt:140; StatementDetails.kt:106 | 27 | Full | None | |
| 46 | WhatsNew sheet | U/more/WhatsNew.kt:130 | 31 | Full | None | |
| 47 | Support (UPI Pay with, QR) | U/more/SupportScreen.kt, QrCode.kt | 31 | Full | None | |
| 48 | InfoButton (i) dialogs | U/components/InfoButton.kt:31 | 03, 10, 26 | Partial | Expand file (shared component) | Referenced per feature; no single shared-component spec listing every info text/placement. Low risk |
| 49 | More hub entries and live subtitles (e.g. "{active} active . {near} near limit", "{n} need a password") | U/more/MoreScreen.kt:197-337 | 26, 28 (partial) | Partial | Expand file (26 or 17) | Hub subtitle logic and "You're all caught up" footer are not confirmed as FR-ids; verify |
| 50 | Brand logos (BankLogo, AppLogos) | U/components/BankLogo.kt | 09, 20 | Full | None | |
| 51 | Haptics on long-press | U/analytics/AnalyticsScreen.kt:217 | 17, 18 | Full | None | |
| 52 | ParserBenchScreen (dev, unreachable) | U/bench/ParserBenchScreen.kt | 06 | Full | None | Documented as dev-only |
| 53 | Theme/Backdrop/Motion helpers | U/theme/Backdrop.kt, components/Motion.kt | 28 | Full | None | |

Counts: 53 rows; Full 49, Partial 4 (rows 20, 30, 48, 49), Missing 0.

## Gaps
1. MessageView "Copy text" action, expand/collapse ("Show all/Show less/Show full email") and "original text wasn't kept" empty state: add FRs to 08 (shared by 07 and 05).
2. More hub per-entry live subtitles and footer: confirm an FR exists (26 or 17); otherwise add.
3. Shared chart components (ProtoCharts: FanChart, StackedArea, HeatGrid, ProgressRing) and InfoButton lack a cross-feature component note; per-feature specs exist. Optional: note in plan.md architecture, not a new file.
4. No screen found that is entirely unspecified; no Create new file needed.

## Screens-index reverse check
All 64 rows of `assets_reference/_screens_index.md` map to an existing file in `memory/` (01, 03, 05, 07, 08, 09, 10, 12-31 subset as listed). Unmapped rows: 0. Reverse direction (UI surfaces not in the index): Statement-detail dialogs, MergeDialog, DeleteAccountDialog, MergeIntoSheet, RemoveLoanDialog, InfoButton, MessageView, NotificationsSheet variants, More hub, Profile setup sheet, Time picker and several confirm dialogs have no GIF row; each is specified in a feature file, so only GIF-index additions (optional) apply. Memory files with no screens-index row: 02, 04, 06, 11 (engine/ingestion features with no dedicated screen; expected).
