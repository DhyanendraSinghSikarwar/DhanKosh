# Category Split

| Field | Value |
|---|---|
| Feature ID | F-41 |
| Status | Done (Phase 5) |
| Priority | P2 |
| Phase | 5 |
| Last Updated | 2026-11-09 |

## 1. Description
Split one payment into two or more categories that add up to the total, such as a shop bill that is part groceries and part household.

## 2. What This Feature Will Do
- A payment in rupees from a bank account can be split into two or more parts; each part has a category and an amount above zero.
- The parts must add up exactly to the amount and use each category once; otherwise saving is refused with the reason.
- A split payment counts in each part's category in category lists and budgets instead of its own category.
- Remove split restores the single category.
- Analytics charts still use the payment's own category.

## 3. Behaviour in Existing App
New in the rebuild; adapted from the PennyWise comparison (behaviour only, no code).

## 4. User Stories
- As a user, I want split one payment into two or more categories that add up to the total, such as a shop bill that is part groceries and part household.

## 5. Functional Requirements (FR-XX-01 ...)
- FR-41-01: A payment in rupees from a bank account can be split into two or more parts; each part has a category and an amount above zero.
- FR-41-02: The parts must add up exactly to the amount and use each category once; otherwise saving is refused with the reason.
- FR-41-03: A split payment counts in each part's category in category lists and budgets instead of its own category.
- FR-41-04: Remove split restores the single category.
- FR-41-05: Analytics charts still use the payment's own category.

## 6. Non-Functional Requirements (performance, battery, privacy, offline)
- Everything stays on the phone; nothing is sent anywhere.
- Money is paise; lists are small and load in one query.

## 7. UI / Screens & User Flow
Transaction detail > Split into categories opens a sheet with rows, Add part, what is left to place and Save.

## 8. Data Models (Dart entities, fields, types)
`TxPart(category, amountMinor)` with `TxPart.validate`; `LedgerTx.parts`.

## 9. Database Tables / Changes
`tx_parts(transaction_id, category, amount_minor)`, cascade on delete (schema v15).

## 10. Business Rules & Logic (regex, algorithms, thresholds, formulas)
At least two parts, none zero, no repeated category, sum equals the amount. Rupee, non-card payments only.

## 11. Platform / Native Requirements (permissions, channels, background work)
None.

## 12. Dependencies (links to other feature files; packages)
[Transactions Ledger](08_transactions_ledger.md), [Expense Tracking](10_expense_tracking.md).

## 13. Folder Location (lib/features/<name>/...)
`features/transactions_ledger/{domain/tx_part.dart,presentation/category_split_sheet.dart}`; budget SQL in `expense_tracking/data`.

## 14. Edge Cases & Error Handling
A currency other than INR is refused; changing the payment amount later is not possible, so the parts stay valid.

## 15. Test Cases (unit / widget / integration + fixtures)
`test/features/groups_people/groups_people_test.dart` (validation, list grouping, budget totals).

## 16. Acceptance Criteria
A 2,000 bill split 1,200 Food and 800 Bills counts 1,200 and 800 in those budgets.

## 17. Open Questions
Analytics and PDF reports still use the single category.

## 18. Implementation Notes
`groupByCategory` and the budget category SQL read the parts.

## 19. Change Log (date | change | reason)
| Date | Change | Reason |
|---|---|---|
| 2026-11-09 | Created and built | PennyWise comparison, W17b |
