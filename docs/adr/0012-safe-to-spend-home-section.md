# ADR-0012: "Safe to spend" returns as an optional Home section

- **Status:** Accepted
- **Date:** 2026-11-09

## Context

The Kotlin app showed a "Safe to spend" block on Home; the rebuild dropped it (memory 17 FR-17-23, backlog 34 FR-34-11). The PennyWise comparison scored it high on decision value and fit: it needs only data already on the phone (balances, bills, budgets) and nothing leaves the device.

## Decision

1. Home gets one more section, **Safe to spend**, **hidden by default**. The user turns it on in Customise, so Home looks the same for everyone who does nothing.
2. The figure is computed on the phone by one pure rule (`SafeToSpend`):
   - spendable = balance of liquid accounts, minus the user's unpaid bills, EMIs and card dues that fall due before the month ends;
   - if budgets exist, the amount is capped by the budget left this month (limits minus spent);
   - per day = spendable, never below zero, divided by the days left this month including today.
3. It uses the cash-basis spend of ADR-0011 for the budget side and the existing paid-this-cycle rule for bills.
4. Amounts hide with the Home hide switch. The card says what it counts in one line.

## Consequences

FR-17-23 ("never shows Safe to spend") is replaced by a hidden-by-default section. An account whose balance is unknown is left out, and with no known balance the card says so instead of showing zero.

## Alternatives considered

- **Visible by default.** Rejected: the owner removed it once; opt-in respects that.
- **Per-currency figures.** Deferred; only INR is summed.
