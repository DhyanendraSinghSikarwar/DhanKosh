# PennyWise vs DhanKosh: how "better" is decided, and the work list

Date 2026-11-06. Source: the 59-row feature matrix (behaviour described in our own words; no PennyWise code, strings or regexes are copied, as PennyWise is AGPL-3.0).

## 1. What DhanKosh is for

Offline-first personal finance for India. It builds **one ledger** from bank SMS, email, payment-app notifications and statements, so each payment is recorded **once**, with the least typing. Everything runs on the phone; nothing leaves it without consent.

## 2. How "better" is decided

A feature is better when it serves that objective better, not when it has more options. Each candidate is scored on six questions (yes = 1):

| # | Question | Why |
|---|---|---|
| Q1 | Does it make the ledger more complete or accurate without the user typing? | Core promise |
| Q2 | Does it save the user a daily or weekly task (notice, decide, sort)? | Low friction |
| Q3 | Does it help the user decide something about money (spend, save, pay on time)? | Value of the data |
| Q4 | Does it work fully on the phone, with no off-device data? | Privacy rule |
| Q5 | Does it fit the single ledger write path and the paise rule? | Architecture |
| Q6 | Is it small enough to ship with tests (S under 3 days, M under 2 weeks)? | Effort |

Rules of thumb:
- Q4 or Q5 = no means "note only" unless an ADR relaxes it.
- Manual-entry features (receipts, groups, IOUs) score low on Q1 and Q2, so they come after automation and alerts.
- Where DhanKosh already scores the same or higher, nothing changes.
- A tie goes to the smaller change.

## 3. Verdicts and scores (only rows that are not "Equal / DK better / note only")

| ID | Feature | Verdict | Q1 | Q2 | Q3 | Q4 | Q5 | Q6 | Score | Order |
|---|---|---|---|---|---|---|---|---|---|---|
| W1 | Exclude a transaction from analytics | PW better | 1 | 1 | 1 | 1 | 1 | 1 | 6 | 1 |
| W2 | Merchant alias | PW better | 1 | 1 | 0 | 1 | 1 | 1 | 5 | 2 |
| W3 | Per-account low-balance alert | DK missing | 0 | 1 | 1 | 1 | 1 | 1 | 5 | 3 |
| W4 | Daily summary notification (opt-in) | PW better | 0 | 1 | 1 | 1 | 1 | 1 | 5 | 4 |
| W5 | Bill reminder with Mark paid / Skip | PW better | 0 | 1 | 1 | 1 | 1 | 1 | 5 | 5 |
| W6 | Date format setting | DK missing | 0 | 0 | 0 | 1 | 1 | 1 | 3 | 6 |
| W7 | Safe to spend (needs ADR, FR-17-23) | DK missing | 0 | 1 | 1 | 1 | 1 | 0 | 4 | 7 |
| W8 | Tags | DK missing | 0 | 1 | 1 | 1 | 1 | 0 | 4 | 8 |
| W9 | Quick add (tile, shortcut, deep link) | PW better | 1 | 1 | 0 | 1 | 1 | 0 | 4 | 9 |
| W10 | Subscription lifecycle, price-change alert | PW better | 1 | 1 | 1 | 1 | 1 | 0 | 5 | 10 |
| W11 | Budget cycle start day | DK missing | 0 | 0 | 1 | 1 | 1 | 0 | 3 | 11 |
| W12 | Recurring auto-post (ADR) | DK missing | 1 | 1 | 0 | 1 | 0 | 0 | 3 | 12 |
| W13 | Scheduled folder backup | DK missing | 0 | 1 | 0 | 1 | 1 | 0 | 3 | 13 |
| W14 | Monthly recap card | PW better | 0 | 0 | 1 | 1 | 1 | 0 | 3 | 14 |
| W15 | Home-screen widgets | PW better | 0 | 1 | 1 | 1 | 1 | 0 | 4 | 15 |
| W16 | Smart rules v2, budgets v2 | PW better | 1 | 1 | 1 | 1 | 1 | 0 | 5 | 16 |
| W17 | Receipts, groups, category split, people split | DK missing | 0 | 0 | 0 | 1 | 0 | 0 | 1 | 17 |
| W18 | Shake to hide | DK missing | 0 | 0 | 0 | 1 | 1 | 1 | 3 | later |

Not built: AI chat, MCP, webhooks, report-to-website, Pro licensing (off-device data or not applicable).
Already done in this branch: column-mapped statement import, share text, generic extractor, review queue, learned senders, dedup rules, ignore account, Indian sender coverage, YAML languages, "Spent X at Y?" alert.

## 4. Work list, one at a time

Each item: memory file read first and updated after, FR-ids, tests, `check_memory.py`, `check_architecture.py`, analyze, full tests, commit, push.

Status is kept in section 5.

## 5. Status

| ID | Status |
|---|---|
| W1 | Done (FR-10-24, schema v9) |
| W2 | Done (FR-09-20, schema v10); backup of aliases left out |
| W3 | Done (FR-13-23, schema v11); backup of the threshold left out |
| W4 | Done (FR-21-29); the Sort buttons are not added, tap opens Transactions |
| W5 | Done (FR-21-30) |
| W6 | Done for the main screens (FR-28-31); calendar, budgets, bills, portfolio, statements still use the Auto form |
| W7 | Done (FR-17-48, ADR-0012) |
| W8..W18 | Pending |
