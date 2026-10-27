# ADR-0011: Total expense is on a cash basis; card purchases stay visible

- **Status:** Accepted
- **Date:** 2026-10-27

## Context

The original app counted a credit card purchase as spend when it was swiped and ignored the later bill payment. The owner wants every transaction listed and shown by category, including credit card purchases, but wants the headline total expense to leave out card purchases and count the payments made to the cards instead (money that actually left the bank). See [memory 10](../../memory/10_expense_tracking.md) and [08](../../memory/08_transactions_ledger.md).

## Decision

1. **Listing and categories show everything.** The Transactions tab lists every transaction, bank and card. Category views, the category donut and category budgets include card purchases. Rows are tagged Card or Account, and a filter chip offers All, Accounts and Cards.
2. **Total expense is cash basis.** Home "Spent", the Transactions Expenses figure, the Analysis headline, Net, savings rate and cash flow count: account spends (excluding own-account transfers and investments as before) plus **credit card bill payments**. Card purchases are excluded from these totals.
3. **A card payment is counted once.** The bank-side leg counts. If the paying account is not tracked, the card-side payment record counts instead. The card-side credit never counts as income.
4. **Card refunds** reduce that category on the card and are not income.
5. Screens that show both a headline and a category breakdown say so in one line ("Expenses exclude card purchases and include card bill payments") and show the card purchases figure beside it.
6. The rule lives in one place (`SpendCalc` in the expense domain) and every consumer calls it: Home, Transactions summary, Analysis, Income and cash flow, widget payload, PDF reports, weekly summary, alerts.

## Consequences

Totals match money leaving the bank. Category totals can exceed the headline when card bills are unpaid. This differs from the Kotlin app's behaviour (parity exception recorded in memory 10).

## Alternatives considered

- **Keep the original app's accrual rule.** Rejected by the owner.
- **A global switch.** Deferred: one rule keeps every screen consistent; a switch can be added in Settings later if wanted.
