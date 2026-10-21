# ADR-0005: Money is integer paise

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

Floating point rounds. A ledger that shows the wrong paisa loses trust.

## Decision

Store and compute all money as integer minor units (paise). Never `double`. Format with en-IN grouping at the edge. Foreign spends keep their currency plus an INR value ([feature 23](../../memory/23_forex_rates.md)).

## Consequences

Parsers must convert decimal text exactly. `tools/check_architecture.py` flags `double` in `domain`.

## Alternatives considered

- **`Decimal` package.** Rejected: slower, serialises poorly, integers already suffice.
