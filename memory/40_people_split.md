# Split with People

| Field | Value |
|---|---|
| Feature ID | F-40 |
| Status | Done (Phase 5) |
| Priority | P2 |
| Phase | 5 |
| Last Updated | 2026-11-09 |

## 1. Description
Share one payment with other people, equally or by amounts, and keep track of who owes what until they pay back.

## 2. What This Feature Will Do
- People are added by name (trimmed, 40 characters, unique ignoring case).
- Split with people (transaction detail) picks people and shares equally or by amount; each share is money that person owes the user; the user's part is what is left.
- Equal split gives each person the same whole-paise share and the user keeps the remainder.
- Splitting a payment again replaces its earlier shares; Remove split clears them.
- The People screen (More > People and splits) shows the net and each person's balance (Owes you / You owe / Settled).
- A person screen shows the entries, and records They paid back, I lent and I borrowed; swipe removes an entry; deleting a person deletes their entries.
- A UPI pay-request link is not built.

## 3. Behaviour in Existing App
New in the rebuild; adapted from the PennyWise comparison (behaviour only, no code).

## 4. User Stories
- As a user, I want share one payment with other people, equally or by amounts, and keep track of who owes what until they pay back.

## 5. Functional Requirements (FR-XX-01 ...)
- FR-40-01: People are added by name (trimmed, 40 characters, unique ignoring case).
- FR-40-02: Split with people (transaction detail) picks people and shares equally or by amount; each share is money that person owes the user; the user's part is what is left.
- FR-40-03: Equal split gives each person the same whole-paise share and the user keeps the remainder.
- FR-40-04: Splitting a payment again replaces its earlier shares; Remove split clears them.
- FR-40-05: The People screen (More > People and splits) shows the net and each person's balance (Owes you / You owe / Settled).
- FR-40-06: A person screen shows the entries, and records They paid back, I lent and I borrowed; swipe removes an entry; deleting a person deletes their entries.
- FR-40-07: A UPI pay-request link is not built.

## 6. Non-Functional Requirements (performance, battery, privacy, offline)
- Everything stays on the phone; nothing is sent anywhere.
- Money is paise; lists are small and load in one query.

## 7. UI / Screens & User Flow
More > People and splits; a person opens a screen with balance, buttons and entries; the split sheet opens from the transaction detail.

## 8. Data Models (Dart entities, fields, types)
`Person`, `PersonEntry`, `SplitMath`, `PeopleRepository`.

## 9. Database Tables / Changes
`people(id, name unique, created_at)` and `person_entries(id, person_id, amount_minor, note, transaction_id, created_at)` (schema v15). Positive: they owe the user.

## 10. Business Rules & Logic (regex, algorithms, thresholds, formulas)
Balance is the sum of entries. Shares above the total are refused in the sheet.

## 11. Platform / Native Requirements (permissions, channels, background work)
None.

## 12. Dependencies (links to other feature files; packages)
[Transactions Ledger](08_transactions_ledger.md), [Expense Tracking](10_expense_tracking.md).

## 13. Folder Location (lib/features/<name>/...)
`lib/features/people_split/{domain,data,presentation}`.

## 14. Edge Cases & Error Handling
A zero entry is ignored. Deleting the payment keeps the entries (the link is cleared).

## 15. Test Cases (unit / widget / integration + fixtures)
`test/features/groups_people/groups_people_test.dart` (SplitMath, split, repayment, delete).

## 16. Acceptance Criteria
Splitting a dinner shows each friend's share owed and clears when they pay back.

## 17. Open Questions
Custom per-person notes and reminders are not built.

## 18. Implementation Notes
Split sheet is composed into the transaction detail by `app/ledger_shell.dart`.

## 19. Change Log (date | change | reason)
| Date | Change | Reason |
|---|---|---|
| 2026-11-09 | Created and built | PennyWise comparison, W17b |
