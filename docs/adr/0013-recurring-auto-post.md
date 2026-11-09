# ADR-0013: A regular payment can add itself on its due day

- **Status:** Accepted
- **Date:** 2026-11-09

## Context

DhanKosh records only what a bank message, mail, notification or statement reports, or what the user types (the old scope rule, memory 34). Some real payments never produce any message: rent paid in cash, a maid's salary, a chit instalment, a salary credited without an SMS. PennyWise adds such rows from "recurring templates". The PennyWise comparison scored this feature high on completeness and low on effort once dedup exists (ADR-0010 style merge of a manual row with the bank's own alert).

## Decision

1. Each regular payment the user added (Bills, "Add regular payment") gets a switch **Add automatically**, **off by default**. Detected payments and loan EMIs are never auto-posted.
2. When on, the daily job and every alert check book one manual transaction for the most recent due date that has passed (never before the item was created, and no older than 35 days), at 09:00 IST, with the item's amount, payee, category and account.
3. Each due date is booked once: the row carries the id `recurring:<item id>:<date>`, so a repeated run adds nothing. Deleting the row does not bring it back (the tombstone stays).
4. The row goes through the single ledger path like any manual entry, so dedup merges it with the bank's own message if one arrives later.
5. Nothing is sent anywhere; the user can turn the switch off at any time.

## Consequences

The ledger may contain a row the user never saw a message for, and the user chose that per item. Amounts are fixed: a bill that varies should stay on reminders (W5) and Mark paid.

## Alternatives considered

- **Auto-post detected subscriptions too.** Rejected: they already arrive by message; a second source adds duplicates.
- **Ask on each due date.** That is the bill reminder with Mark paid (FR-21-30).
