# Transaction Groups

| Field | Value |
|---|---|
| Feature ID | F-39 |
| Status | Done (Phase 5) |
| Priority | P2 |
| Phase | 5 |
| Last Updated | 2026-11-09 |

## 1. Description
Bundle transactions into a named group, such as a trip or an event, and see what the group cost. A transaction can be in several groups.

## 2. What This Feature Will Do
- A group has a name; groups are listed newest first with their transaction count and spend.
- The Groups screen (More > Groups) lists groups and makes a new one; each group opens its own screen.
- A group screen shows Spent, Received and Count, lists its transactions (swipe to take one out), adds transactions from the latest 150, renames and deletes the group; deleting keeps the transactions.
- The transaction detail has a Groups row to tick groups or make a new one.
- Totals count debits and credits that are not transfers, review rows or left-out rows, in rupees.

## 3. Behaviour in Existing App
New in the rebuild; adapted from the PennyWise comparison (behaviour only, no code).

## 4. User Stories
- As a user, I want bundle transactions into a named group, such as a trip or an event, and see what the group cost.

## 5. Functional Requirements (FR-XX-01 ...)
- FR-39-01: A group has a name; groups are listed newest first with their transaction count and spend.
- FR-39-02: The Groups screen (More > Groups) lists groups and makes a new one; each group opens its own screen.
- FR-39-03: A group screen shows Spent, Received and Count, lists its transactions (swipe to take one out), adds transactions from the latest 150, renames and deletes the group; deleting keeps the transactions.
- FR-39-04: The transaction detail has a Groups row to tick groups or make a new one.
- FR-39-05: Totals count debits and credits that are not transfers, review rows or left-out rows, in rupees.

## 6. Non-Functional Requirements (performance, battery, privacy, offline)
- Everything stays on the phone; nothing is sent anywhere.
- Money is paise; lists are small and load in one query.

## 7. UI / Screens & User Flow
More > Groups opens the list; a group opens its detail with totals and transactions.

## 8. Data Models (Dart entities, fields, types)
`TxGroup(id, name, count, spentMinor, incomeMinor)`; `TxGroupRepository`.

## 9. Database Tables / Changes
`tx_groups(id, name, created_at)` and `tx_group_members(group_id, transaction_id)`, both cascade on delete (schema v15).

## 10. Business Rules & Logic (regex, algorithms, thresholds, formulas)
A blank name is refused. Adding a transaction twice is once. `LedgerFilter.groupId` lists a group's rows.

## 11. Platform / Native Requirements (permissions, channels, background work)
None.

## 12. Dependencies (links to other feature files; packages)
[Transactions Ledger](08_transactions_ledger.md), [Expense Tracking](10_expense_tracking.md).

## 13. Folder Location (lib/features/<name>/...)
`lib/features/transaction_groups/{domain,data,presentation}`; wiring in `app/di/groups_people_providers.dart`.

## 14. Edge Cases & Error Handling
Deleting a group never deletes transactions; deleting a transaction removes it from its groups.

## 15. Test Cases (unit / widget / integration + fixtures)
`test/features/groups_people/groups_people_test.dart` (groups: totals, filter, membership, delete).

## 16. Acceptance Criteria
A trip group shows what it cost and lists its payments.

## 17. Open Questions
CSV export of a group is not built.

## 18. Implementation Notes
Routes `/groups` and `/groups/:id`; the transaction rows are composed in `app/`.

## 19. Change Log (date | change | reason)
| Date | Change | Reason |
|---|---|---|
| 2026-11-09 | Created and built | PennyWise comparison, W17b |
