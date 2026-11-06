# PennyWise parity plan and issue list

Created 2026-11-06. Branch `claude/awesome-einstein-f5ydxe`. Status is kept current in section 4 as each issue lands.

## 1. How this was done

- PennyWise (`com.pennywiseai.tracker`, Kotlin) was read from source at commit `a77e5355` (458 Kotlin files, Room schema v67): navigation routes, preference keys, manifest, workers, entities and string resources, not the README.
- DhanKosh was read from its 37 memory files and `app/lib/features/**`.
- Every PennyWise feature got a verdict: **DK better**, **PW better**, **Equal**, **DK missing**, or **Note only** (conflicts with a DhanKosh rule). DhanKosh is left alone where it is better or equal. Only PW better and DK missing become issues.
- Research reports (kept outside the repo, in the session scratchpad): capture pipeline, statements/accounts/dedup, bank coverage, full feature matrix.

### Licence rule (important)

PennyWise is **AGPL-3.0**; DhanKosh is **proprietary** (`LICENSE`, ADR-0006). Nothing from PennyWise is copied: no code, regexes, string literals or UI text. Its behaviour was written up as a clean-room specification and DhanKosh's code is written independently on top of DhanKosh's own extractors. Facts (a bank's name, an SMS sender id) are recorded as facts only.

### Rules that bound the work (CLAUDE.md)

Single ledger write path (the transaction repository), money in paise, parsers are pure functions, no off-device financial data without consent, features never import another feature's `data` or `presentation`, a memory file per feature, `check_memory.py` and `check_architecture.py` pass.

## 2. Verdict matrix

| # | PennyWise feature | Verdict | Issue |
|---|---|---|---|
| 1 | Notification capture (allow-list, closed-app, retry, health) | Equal, DK needed hardening | I-01 |
| 2 | Track Other Apps (user-picked apps) | Equal (Watched apps, F-04) | done 2026-11-05 |
| 3 | Generic extractor with confidence for unknown senders | DK missing | I-02 |
| 4 | Unrecognised-message review queue | PW better | I-02 |
| 5 | Learned senders after one confirmation, "Spent X at Y?" alert | DK missing | I-02 |
| 6 | Share text into the app | DK missing | I-03 |
| 7 | Statement import: column mapping, preview, balance check | PW better for spreadsheets; DK better for PDFs, cards, holdings, passwords | I-04 |
| 8 | Cross-source dedup | DK better for SMS/email/notification; PW better on UPI reference, linked card, deleted-row blocking | I-05 |
| 9 | Auto-discovered accounts | DK better overall; PW better on Ignore account, 3-vs-4-digit merge memory, balance history, Cash type, card utilisation bands | I-06 |
| 10 | Bank SMS coverage (172 banks, 26 countries, 57 Indian claimed) | PW wider; true numbers verified in I-07 | I-07 |
| 11 | Languages: file catalogue, plurals, CI checks | PW better (process) | I-08 |
| 12 | Statement unlock shows the mail subject and mail content | requested by owner | I-10 |
| 13 | Exclude from analytics, merchant alias, refund/budget impact | DK missing / PW better | I-11 |
| 14 | Tags (free-form, filter, analytics by tag) | DK missing | I-12 |
| 15 | Quick add (tile, shortcut, deep link, overlay) | DK missing | I-13 |
| 16 | Subscription lifecycle, bill reminders with actions, price-change alert | PW better | I-14 |
| 17 | Receipt photo on a transaction | DK missing | I-15 |
| 18 | Budget cycle start day, safe to spend, daily summary | DK missing / PW better | I-16 |
| 19 | Recurring entries that create transactions | DK missing (reverses FR-12-04, needs ADR) | I-17 |
| 20 | Scheduled encrypted folder backup | DK missing | I-18 |
| 21 | Smart rules: many fields, AND/OR, Block, JSON import/export | PW better | I-19 |
| 22 | Budgets v2: Limit/Target/Expected, weekly/monthly/one-time, history | PW better | I-20 |
| 23 | Widgets (7 vs 1) | PW better | I-21 |
| 24 | Split with people, lent/borrowed, UPI request | DK missing (needs ADR) | I-22 |
| 25 | Transaction groups, split into categories | DK missing (needs ADR) | I-23 |
| 26 | Shake to hide, date format, low-balance alert, recap card | DK missing | I-24 |
| 27 | Contact names for UPI ids, online exchange rates | PW convenience; both need a consent-safe design | I-25 |
| 28 | Analytics, forecast, backup encryption, app lock, CSV, themes, category detail, budget alerts | **DK better** | no change |
| 29 | Accounts list, profiles/Book, notes, transaction notification, balance gap, SMS scan window | Equal | no change |
| 30 | On-device AI chat, MCP relay, webhooks, Pro licensing, report-to-website | Note only: send data off-device or not applicable | not built, by rule |

## 3. Issues and working plan

Order: owner-named issues first, then the rest by value over effort. Each issue is one or more commits with tests, its memory file updated (or created and registered with one `plan.md` row), and `CHANGELOG.md` under Unreleased.

### I-01 PhonePe (notification-only) payment not captured
**Causes found.** (a) A notification that arrived with the app closed was queued natively and only ingested at the next app open, because unlike SMS it never woke a background job. (b) A notification has no account and usually no reference, so its hash is only amount, direction and day; a second same-amount payment that day was flagged and left out of totals.
**Plan.** Headless `notifications.drain` job; Context-based notifications channel; listener health line; APP-vs-APP dedup rule; own hash for a different payment. Memory F-04, F-07.

### I-02 Generic extractor, review queue, learned senders (new feature F-38)
**Plan.**
1. `GenericExtractor` in `parser_core`: amount, direction, account digits, payee, balance/limit, reference; confidence 50 + 20 + 20 + 10 + 5; hard rejects (OTP, failed, promo, due, future debit, request, EMI invite, voucher, phone-number sender).
2. Encrypted tables `unrecognised_messages` and `learned_senders`; statuses new, added, dismissed, ignored sender, expired; hard-delete after 30 days with a tombstone so a handled message does not come back.
3. Queue screen with "Looks like" line, Add, Dismiss, Ignore sender; masked amounts when hidden; count on More.
4. Add goes through the single ledger write path with the original message id, so a later parser or rescan never books it twice.
5. Learned senders: one confirmation teaches the sender and its account; later messages from it raise a "Spent X at Y?" alert; a Learned senders list with Forget.
6. Inputs: inbox scan for missed messages (user-initiated), learned senders live, and watched-app notifications the strict parser rejected for "no payment wording" or "no amount" but that carry a currency amount.
7. Differences from PennyWise, on purpose: no raw-SMS report off the device; provenance kept; undo; forget.

### I-03 Share text into the app
`ACTION_SEND text/plain` intent filter; shared text goes through `GenericExtractor` (amount, direction, payee, date) to a pre-filled Add form; the whole text kept as the note; cross-currency amounts not pre-filled; balance figures never taken as the amount.

### I-04 Statement import: column mapping and balance check
Pure column-mapping parser in `parser_core` (header-row detection, keyword guesses, date and amount formats, Dr/Cr, split debit/credit, brackets, ₹/Rs, serial-number first column); per-sheet reading with limits; mapping screen with a live sample; saved layout per bank; dry-run preview through the ledger (new vs already in app); closing-balance check against the account on that day and a row-by-row running-balance check. Memory F-05.

### I-05 Dedup: more checks
From the dedup study: normalised UPI/UTR reference across all sources within a window; each notification app its own source; debit card linked to its account; balance-after equal means the same payment and balance minus the amount means two payments; safeguards for genuine same-amount repeats; reversal and refund linked but never merged; deleted rows block their twins; identical message re-delivered later. Needs an ADR because it goes beyond Kotlin parity. Memory F-07.

### I-06 Accounts
Ignore account (drop at ingest, unlike Hide); remembered 3-vs-4-digit merge; Cash account type; card utilisation bands; unlinked cards; editable credit limit and statement day; per-account low-balance alert. Memory F-13, F-14.

### I-07 Bank SMS coverage
Verify PennyWise's claim against its code. Add every verified Indian bank or service DhanKosh lacks, each with synthetic fixtures. Foreign banks only where sender ids can be verified; otherwise documented as not done. Memory F-06.

### I-08 Localisation
All UI text in YAML files, one per language, key to text, bundled with the app; runtime lookup that rebuilds the UI on language change; plurals; per-string fallback to English; a tool that checks every key used in code exists, placeholders match, and reports coverage per language. Screens converted to keys. Memory F-29.

### I-10 Statement unlock shows the mail subject, and the mail can be opened
When a statement asks for a password, show the subject line of the email it came from. For every statement, an option to open the content of that mail. (`statements.subject` and `statements.email_text` already exist.) Memory F-05, F-03.

### I-11 to I-25
Exclude-from-analytics, merchant alias, budget impact; tags; quick add; subscription lifecycle and reminders; receipts; budget cycle day, safe to spend, daily summary; recurring auto-post; scheduled backup; smart rules v2; budgets v2; widgets; people split and IOUs; groups and category split; shake to hide, date format, low-balance alert, recap card; contact-free UPI names and opt-in exchange rates. Each is built only after the owner-named issues, each with its own memory file and tests. Those that reverse a written scope rule (FR-12-04, FR-17-23, FR-34-07/08) get an ADR first.

## 4. Status

| Issue | Status |
|---|---|
| I-01 | Done and pushed (`bcdf26e`) |
| I-02 | Done except the "Spent X at Y?" alert and device verification (F-38) |
| I-03 | Done (FR-08-27); device verification pending |
| I-04 | Done: column mapping, saved layouts, balance check (FR-05-28, 29, 31). Not done: dry-run preview with untick, one-to-one statement matching (moves to I-05) |
| I-05 | Done: FR-07-19..22 (references, two apps, stated balances/times, late mail). Deferred as I-05b (ADR needed): D4, D6, D8, D9, D10, D12, D14, one-to-one statement matching |
| I-06 | Partly done: Ignore account (FR-13-22, schema v8). Left as I-06b: remembered 3-vs-4-digit merge, Cash type, card utilisation bands, editable limit/statement day, low-balance alert |
| I-07 | Done for India: FR-06-22/23. True counts: 172 parsers, 57 Indian, 27 countries. Not done (I-07b): wallet account kind (JioPay, Amazon Pay/JUSPAY, Pluxee, LazyPay), Cashfree, mutual-fund SMS, mandate records, balance-only updates, per-currency decimals, foreign banks (no verifiable sender data) |
| I-08 | Done: bundled YAML catalogues, `t()` on screens, `tools/check_l10n.py`, FR-29-05..19. Left: strings built with `$value` (need placeholders), enum labels, background notifications, native-speaker review |
| I-10 | Done (FR-05-30) |
| I-11 to I-25 | Pending |
