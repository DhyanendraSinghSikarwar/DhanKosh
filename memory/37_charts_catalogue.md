# Charts Catalogue

| Field | Value |
|---|---|
| Feature ID | F-37 |
| Status | In Progress (Analysis charts C1, C3, C4, C5, C9, C10, C11, C13 built 2026-10-27; Home, Portfolio, Account, Loan charts pending) |
| Priority | P1 |
| Phase | 5 |
| Last Updated | 2026-10-27 |

## 1. Description
The Kotlin app draws about twenty charts across Home, Analysis, Portfolio, Account detail and Loan detail. Their data and rules live in the owning feature files; this file is the one place that lists every chart, where it appears, how it behaves and whether the Flutter app has it. It exists so chart work is planned once and the shared chart components are built once.

## 2. What This Feature Will Do
- Lists every chart and visual in the Kotlin app with its screen and source.
- Defines the shared chart components and their interactions (selection, tap-to-read, animation).
- Tracks Flutter status per chart so gaps are visible.

### 2.1 Inputs
Aggregates produced by the owning features (analytics, portfolio, accounts, loans, dashboard).

### 2.2 Processing
1. The owning feature builds the series in domain code (paise integers).
2. A shared chart widget draws it with masked labels when amounts are hidden.

### 2.3 Outputs
Charts on the screens in section 7.

### 2.4 Out of Scope
Data maths (owned by features 10, 11, 15, 16, 18), the planned 19-chart catalogue and "View as table" ([34_planned_insights_backlog.md](34_planned_insights_backlog.md)), and `StackedArea`, `AreaLineChart`, `GroupedBarChart`, which exist in Kotlin but have no caller in 2.9.8.

## 3. Behaviour in Existing App
Components in `app/src/main/kotlin/com/hisaab/app/ui/charts/`:
- `Charts.kt`: `DonutChart` (73; selectable slice, centre label and value, thickness), `GroupedBarChart` (162, unused), `AreaLineChart` (233, unused), shared `tooltip` (316).
- `ProtoCharts.kt`: `Sparkline` (52; self-drawing line, soft fill, dot on last value), `ProgressRing` (72), `StackedMonthBars` (91; optional average line, tap), `StackedArea` (144, unused), `Sankey` (176), `FanChart` (228), `HeatGrid` (277; tap a cell), `DivergingRow` (304).

Usage by screen (callers confirmed by search):
| Id | Chart | Kotlin screen and source |
|---|---|---|
| C1 | `CategoryDonutCard` PieChart with tap-select, legend rows, drill-down, Back, Open category | Done |
| C2 | Category donut, top 7 plus Others, percent legend | `home/HomeWidgets.kt:410` |
| C3 | `CategoryDetailScreen` sub-category donut (`/category/:id`) | Done |
| C4 | `MonthlyTrendCard` stacked rods Essentials, Lifestyle, Other, dashed average line, tap reads a month | Done |
| C5 | `HeatmapCard` tappable 7x8 grid with slot labels and readout | Done |
| C6 | Top merchants list | `analytics/AnalyticsScreen.kt:356` |
| C7 | Budget rings (amber at 80%, red at 100%) | `home/HomeWidgets.kt:452` |
| C8 | Budget progress | Analysis Budgets card, `/budgets` |
| C9 | `IncomeFlowCard` Sankey `CustomPainter` (`SankeyPainter`) with figures below | Done |
| C10 | `SavingsRateCard` monthly line with average | Done |
| C11 | `ForecastCard` fan `CustomPainter` (`FanPainter`: actual, expected, band, budget line) | Done |
| C12 | 30-day cash balance sparkline | `analytics/AnalyticsSegments.kt:162` |
| C13 | `CompareCard` diverging bars | Done |
| C14 | Net worth history line with 1M, 6M, 1Y, 3Y, All | `home/HomeWidgets.kt:204`, `invest/PortfolioSections.kt:305` |
| C15 | Net worth split bar by account and class with legend | `invest/WorthBreakdown` (`PortfolioSections.kt`) |
| C16 | Asset allocation donut with class filter | `invest/PortfolioSections.kt:238` |
| C17 | Holding row sparkline | `invest/PortfolioSections.kt:560` |
| C18 | Account spend and income lines, 6M / 1Y / All, tap a month | `accounts/AccountDetailScreen.kt:240, 276` |
| C19 | Running line, this month against last month, cumulative | `home/SpentThisMonth.kt:259-282` |
| C20 | Cash-flow split bar income, spent, invested, saved | `home/HomeWidgets.kt` cash-flow widget |
| C21 | Loan next-EMIs stacked principal and interest | `loans/LoansScreen.kt:618` |
| C22 | Income against spend bars | Flutter addition (Income screen), no Kotlin counterpart |

A daily-spend "Safe to spend" ring exists in `HomeWidgets.kt:273` but is not in the Kotlin FEATURES.md and is excluded by FR-17-23.

## 4. User Stories
1. As a user I see where my money went as a donut and tap a slice to focus the screen on it.
2. As a user I see my month-end projection as a range, not a single number.
3. As a user I read a value by tapping a bar, point or cell.

## 5. Functional Requirements (FR-37-01 ...)
1. FR-37-01: Every chart reads paise integers and formats with en-IN grouping; labels and tooltips are masked when amounts are hidden.
2. FR-37-02: A shared donut supports slice selection, centre label and value, and a legend; selection state is owned by the screen.
3. FR-37-03: Selecting a donut slice on Analysis cross-filters Top merchants and the 12-month trend to that category (FR-18-20); a second tap clears it; sub-categories drill down.
4. FR-37-04: 12-month bars are stacked Essentials, Lifestyle, Other, show an average line, and open that month on tap.
5. FR-37-05: The heat grid shows 7 days by 8 slots; tapping a cell shows its total, a second tap clears.
6. FR-37-06: The Sankey and fan chart are drawn with `CustomPainter` (no `fl_chart` equivalent); if the Sankey is judged too costly the bars in `IncomeFlowCard` stay and the decision is recorded here.
7. FR-37-07: The Home Spent card draws this-month and last-month cumulative lines over the days of the month.
8. FR-37-08: Net worth shows a line with 1M, 6M, 1Y, 3Y, All ranges on Home and Portfolio, plus a split bar by account and class.
9. FR-37-09: Account detail shows spend and income lines over 6 months, a year or all time; tap reads a month.
10. FR-37-10: Loan detail shows next EMIs as stacked principal and interest bars.
11. FR-37-11: Every chart exposes a semantic label (category, amount, percent) and an empty state; no chart draws with fewer than two points.
12. FR-37-12: Charts use theme tokens, not fixed colours, so every palette stays legible in light, dark and pure-black modes.

## 6. Non-Functional Requirements (performance, battery, privacy, offline)
- Aggregation runs outside the build method; a chart redraws only when its series changes.
- Animations honour reduce-motion ([28_theming_customisation.md](28_theming_customisation.md)).
- No network use; all data on the phone.

## 7. UI / Screens & User Flow
Screens: Home, Analysis (Spend, Cash, Forecast, Compare), Portfolio, Account detail, Category detail, Loan detail, Income. Flutter status per chart:

| Id | Flutter implementation | Status |
|---|---|---|
| C1 | `CategoryDonutCard` PieChart; no selection or drill-down | Partial |
| C2 | None | Missing |
| C3 | None (no Category detail) | Missing |
| C4 | `MonthlyTrendCard` BarChart, single series, average as text | Partial |
| C5 | `HeatmapCard` container grid, not tappable | Partial |
| C6 | `TopMerchantsCard` | Done |
| C7 | `HomeBudgetsCard` CircularProgressIndicator | Done |
| C8 | `BudgetsCard`, `/budgets` | Done |
| C9 | `IncomeFlowCard` bars | Partial |
| C10 | `SavingsRateCard` figures only | Partial |
| C11 | `ForecastCard` text only | Partial |
| C12 | `CashProjectionCard` LineChart | Done |
| C13 | `CompareCard` percent text | Partial |
| C14 | `NetWorthChart` LineChart on Portfolio; none on Home | Partial |
| C15 | None | Missing |
| C16 | `_Allocation` proportion bar and list | Partial |
| C17 | None | Missing |
| C18 | None | Missing |
| C19 | None | Missing |
| C20 | `HomeCashFlowCard` figures | Partial |
| C21 | None | Missing |
| C22 | `income_tracking_screen.dart` BarChart | Done |

## 8. Data Models (Dart entities, fields, types)
N/A - series types are owned by the features that produce them (`HeatGrid`, `MonthlyTotal`, `NetWorthPoint`).

## 9. Database Tables / Changes
N/A - no tables; charts read existing aggregates.

## 10. Business Rules & Logic (regex, algorithms, thresholds, formulas)
- Budget ring colour: below 80% positive, 80% to below 100% warning, 100% and over negative (FR-17-13).
- Average line excludes the current partial month ([18_analytics.md](18_analytics.md)).
- Heat peak, forecast range and savings-rate rules are owned by [18_analytics.md](18_analytics.md) and [11_income_tracking.md](11_income_tracking.md).

## 11. Platform / Native Requirements (permissions, channels, background work)
N/A - Dart only.

## 12. Dependencies (links to other feature files; packages)
[10_expense_tracking.md](10_expense_tracking.md), [11_income_tracking.md](11_income_tracking.md), [13_accounts_management.md](13_accounts_management.md), [15_loans.md](15_loans.md), [16_portfolio.md](16_portfolio.md), [17_dashboard_home.md](17_dashboard_home.md), [18_analytics.md](18_analytics.md), [09_categorization.md](09_categorization.md). Package: `fl_chart`.

## 13. Folder Location (lib/features/<name>/...)
Shared widgets in `lib/shared/widgets/charts/`; feature-specific wrappers stay in each feature's `presentation`.

## 14. Edge Cases & Error Handling
- Fewer than two points: show the empty state, not a flat line.
- All-zero series: draw axes only, no divide by zero.
- Very large amounts use compact labels; negative net worth keeps the negative colour.

## 15. Test Cases (unit / widget / integration + fixtures)
1. TC-37-01 (FR-37-03): selecting a donut slice filters merchants; second tap clears.
2. TC-37-02 (FR-37-04): stacked bars sum to the month total; average excludes the current month.
3. TC-37-03 (FR-37-05): heat cell tap shows its total.
4. TC-37-04 (FR-37-01): masked mode shows no digits in labels.
5. TC-37-05 (FR-37-11): one point shows the empty state.
6. TC-37-06 (FR-37-07): cumulative series is non-decreasing and ends at the month spend.

## 16. Acceptance Criteria
- AC-37-01: Every chart in section 7 marked Missing or Partial is either built to its FR or has a recorded decision to simplify.
- AC-37-02: Charts work in all palettes and modes with amounts masked.
- AC-37-03: `docs/FEATURES.md` chart table matches section 7.

## 17. Open Questions
1. Closed 2026-10-27: Sankey drawn with a custom painter (figures kept below it).
2. Should `StackedArea` and `GroupedBarChart` (unused in Kotlin) be ported? Default: no.
3. Does Home show the net worth line, as the Kotlin Home card does, given the new Flutter net worth card?

## 18. Implementation Notes
Analysis charts built 2026-10-27 in `features/analytics/presentation/analytics_chart_cards.dart` (builders in `domain/chart_data.dart`) and `features/categorization/presentation/category_detail_screen.dart`. Audit text above otherwise. Existing charts: `app/lib/features/analytics/presentation/analytics_cards.dart`, `portfolio/presentation/net_worth_chart.dart`, `income_tracking/presentation/income_tracking_screen.dart`.

## 19. Change Log (date | change | reason)

| Date | Change | Reason |
|---|---|---|
| 2026-10-27 | Created from the Kotlin chart audit | Kotlin parity audit |
| 2026-10-27 | C1, C3, C4, C5, C9, C10, C11, C13 built (FR-37-02..06); status table updated | Kotlin parity |
