# Scan 2: data sources and parsing logic

Angle: ingestion sources and parsers in the Kotlin app `hisaab_apk` (parser-core, email, app/sms, app/notify, shared/repo) checked against `memory/NN_*.md`.
Method: read the Kotlin source, then grepped and read the memory files for the behaviour (not just the name). Coverage = Full only where the spec states the behaviour.
Paths are relative to `hisaab_apk/`; line numbers are approximate starts.

| # | Capability | Where found (file:line) | Memory file | Coverage | Action | Notes |
|---|---|---|---|---|---|---|
| 1 | SMS live receiver (multipart join, sender-only pre-filter, goAsync, NPS branch, loan/card-due branch) | app/.../sms/SmsReceiver.kt:26-110 | 02 | Full | None | Open question on arrival-time vs PDU time already logged |
| 2 | SMS inbox scan / backfill (cursor, 500 batches, parallel parse, 14-day look-back) | app/.../sms/OptimizedSmsReaderWorker.kt:203-305, SmsInboxSource.kt:127 | 02 | Full | None | |
| 3 | SMS scheduling (app start, refresh, nightly 02:30) | sms/SmsScanScheduler.kt, sync/NightlySync.kt | 02 | Full | None | |
| 4 | SmsIds message-id idempotency | sms/SmsInboxSource.kt:165 | 02 | Full | None | |
| 5 | Email via IMAP (JavaMail, All Mail folder, envelope-first fetch, max 5 PDFs) | email/.../imap/ImapSyncEngine.kt, MailClient.kt:44-200 | 03 | Full | None | |
| 6 | Email via Gmail API (history sync, fallback full, 8 parallel, backoff) | email/.../sync/GmailSyncEngine.kt:54-200, api/GmailApi.kt | 03 | Full | None | |
| 7 | Gmail OAuth (Credential Manager, AuthorizationClient, gmail.readonly, revoke) | email/.../auth/GmailAuthManager.kt | 03 | Full | None | |
| 8 | Provider server table (Gmail, Outlook, Yahoo, iCloud, Zoho, Rediff, AOL, generic) | email/.../imap/MailServers.kt:21-52 | 03 | Full | None | |
| 9 | Mail address verification code (6 digit, 10 min, 5 tries, send-to-self) | email/.../imap/MailVerification.kt, MailConnector.kt | 03 | Full | None | |
| 10 | Keystore sealing: mail passwords, Gmail token, statement passwords | email/.../auth/KeystoreSecret.kt, TokenStore.kt, imap/MailAccountStore.kt | 03, 05 | Full | None | |
| 11 | Email sender allow-list, Gmail query builder, STATEMENT_SENDERS, STATEMENT_SUBJECTS regex | parser-core/.../registry/ParserRegistry.kt:87-122, email/.../sync/GmailSyncEngine.kt:183-200 | 03 | Full | None | Lists reproduced in 03 2.7/2.8 |
| 12 | MIME walk, HTML-to-text, attachment typing by bytes | email/.../mime/MimeParser.kt, MailClient.kt:111-160 | 03, 05 | Full | None | |
| 13 | Email sync schedule, retry, processed-id store, report modes | email/.../sync/GmailSyncWorker.kt, GmailSettings.kt | 03 | Full | None | |
| 14 | Payment-app notification listener (PAYMENT_APPS 20 keys, ongoing/summary drop, field order, dedup id) | app/.../notify/PaymentNotificationListener.kt:98-145 | 04 | Full | None | |
| 15 | WhatsApp payment-only guard (isChatPayment) | notify/PaymentNotificationListener.kt | 04 | Full | None | |
| 16 | Statement files from phone picker (PDF, XLS, XLSX, CSV) | ui/invest/StatementsScreen.kt:182, email/.../statement/StatementProcessor.kt:225 | 05 | Full | None | |
| 17 | Statement attachments from email | StatementProcessor.kt:102-125 | 05, 03 | Full | None | |
| 18 | Email-body investment mails (MF order, INDmoney summary, EPF, NPS) pipeline | StatementProcessor.kt:129-163 | 05 (2.9) | Partial | Expand 05 | Order of checks and MF dedup key present; holdings-side effects (`recordMfOrder`) not stated (see 63) |
| 19 | Screenshot OCR (ML Kit Latin, offline) into draft | app/.../ui/add/AddTransactionScreen.kt:183-190, parser FreeTextParser.kt:51 | 08, 06 (2.14) | Full | None | |
| 20 | Manual entry / manual transfer legs | ui/add/*, shared/db/TransferLegs.kt | 08, 07 | Full | None | Outside this angle, spot-checked |
| 21 | CSV import / export (header, by-name columns, dedup) | app/.../csv/CsvTransfer.kt | 24 | Full | None | |
| 22 | EPFO / NPS CRA SMS (accepts, EPF balance + contribution, NPS value and contribution) | parser-core/.../statement/InvestmentParser.kt:37-145 | 06 (2.13), 16 | Full | None | Spec gives shapes, not every regex (EPF_ALT fallback only as `EPF:default`); acceptable for port |
| 23 | Card statement / bill-due SMS and email (CardDueParser, CardFigures) | parser-core/.../statement/CardDue.kt:25-153 | 05 (2.7), 14 | Full | None | |
| 24 | Lender non-payment status (disbursal, outstanding, EMI reminder) | bank/LenderParser.kt:100 | 06 (2.13), 15 | Full | None | |
| 25 | Untracked-payment detection from stated balances | shared/insight/BalanceGaps.kt, repo/UntrackedGapFinder.kt | 13 (2.8) | Full | None | |
| 26 | SenderKeys (SMS header, email candidates) | parser-core/.../registry/SenderKeys.kt | 06 (2.3) | Full | None | |
| 27 | ParserRegistry (order, accepts, loanStatus, cardDue, duplicate-key guard) | registry/ParserRegistry.kt:30-140 | 06 (2.1), 02 | Full | None | |
| 28 | Core 10 bank template sets (HDFC, ICICI, SBI, Axis, Kotak, IDFC, Yes, BoB, PNB, AU) | bank/Banks.kt:1-141 | 06 (2.5) | Full | None | Templates verbatim |
| 29 | Listed banks (no templates): public, private, SFB, foreign, payments, co-op | bank/IndianBanks.kt:14-85 | 06 (2.5), 02 | Full | Expand 06/02 (counts) | Source has 51; 06 text/FR-06-08 say 50 (table has 51 rows); 02 says "~55" |
| 30 | GenericBankParser fallback (BANKISH_HEADER, CARD_ISSUERS) | bank/GenericBankParser.kt | 06 (2.3), 02 | Full | None | |
| 31 | Lender parsers (17 lenders, EMI receipt as DEBIT, PAID/DISBURSED rules) | bank/LenderParser.kt:38-178 | 06 (2.5, 2.13) | Full | Expand 02 (count) | 02 says "16 parsers"; source and 06 say 17 |
| 32 | PaymentAppParser (SMS headers, email domains, app name from sender) | bank/PaymentAppParser.kt | 06 (2.5), 04 | Full | None | |
| 33 | TextNormalizer, trimEmail footer cut, Guarded, rx helpers | text/TextNormalizer.kt, Rx.kt | 06 (2.2) | Full | None | |
| 34 | RejectionRules (otp, failed, future, mandate, collect, promo, reminder, balance) | rules/RejectionRules.kt:1-91 | 06 (2.6) | Full | None | Order and soft reasons stated |
| 35 | CardBill recogniser (inText, isPayee, paidToCard, VPA tokens, mark) | rules/CardBill.kt:1-84 | 06 (2.9) | Full | None | |
| 36 | TypeClassifier (transfer-first, OUTGOING, debit/credit verbs, looksLikeInvestment) and ChannelDetector | extract/TypeClassifier.kt:8-92 | 06 (2.7) | Full | None | |
| 37 | AmountExtractor, BalanceExtractor, Money parsing (currency allow-list, ceiling) | extract/AmountExtractor.kt, Money.kt | 06 (2.7) | Full | None | |
| 38 | AccountExtractor (labelled, masked, short ending, phone/VPA/other-party rejection) | extract/AccountExtractor.kt:10-105 | 06 (2.7) | Full | None | |
| 39 | ReferenceExtractor (slashed, labelled, digit rule, normalise) | extract/ReferenceExtractor.kt | 06 (2.7) | Full | None | |
| 40 | DateTimeExtractor and resolveTime (earliest date, 45-day back-date window) | extract/DateTimeExtractor.kt, BaseBankParser.kt:724 | 06 (2.4, 2.7) | Full | None | |
| 41 | MerchantExtractor (ordered patterns) and GenericPhrases UI-phrase list | extract/MerchantExtractor.kt, GenericPhrases.kt | 06 (2.7) | Full | None | |
| 42 | MerchantNormalizer and MerchantDirectory (entries match source one for one) and keyword fallback | merchant/MerchantNormalizer.kt, MerchantDirectory.kt | 06 (2.8) | Full | None | Directory table verified against source |
| 43 | Subcategory regex catalogue | shared/insight/Subcategories.kt:18-147 | 09 (2.3) | Full | None | 06 2.10 defers to 09; 06 "Open Questions" wording is stale |
| 44 | TransactionHasher | hash/TransactionHasher.kt | 06 (2.12), 07 (2.1) | Full | None | |
| 45 | DuplicateMatcher (reference, hash, fuzzy, statement window, rounded app amounts, merchantsAgree, last4Match) | dedup/DuplicateMatcher.kt:60-182 | 07 (2.2-2.3) | Full | None | Matches source |
| 46 | Merge rules (mergedWith) and ingest-side card-bill mark | shared/repo/Merge.kt, TransactionRepository.kt | 07 (2.4-2.5) | Full | None | |
| 47 | FreeTextParser.readNotification (reject rules, SIGNAL, PROMO, UI_TEXT, CALL_TO_PAY, payee, bank list, UTR, UPI_APPS) | parser-core/.../FreeTextParser.kt:83-259 | 04 (2.5-2.6) | Full | None | |
| 48 | FreeTextParser.draft / toParsed (screenshot) | FreeTextParser.kt:51-187 | 06 (2.14) | Full | None | |
| 49 | DepositParser (FD, RD, PPF, India Post) and aboutDepositOnly | bank/Deposits.kt:39-164 | 06 (2.13), 05 (2.8) | Full | None | DepositTerms in 13 |
| 50 | StatementParser: kind detection, bank/last4, row parsing, direction rules, date window | statement/StatementParser.kt:72-290 | 05 (2.2, 2.5) | Full | None | |
| 51 | StatementParser.summary (labels, layouts, year-less dates) and apply to account | StatementParser.kt:96-197, StatementProcessor.kt:299 | 05 (2.7), 14 | Full | None | |
| 52 | SpreadsheetExtractor (xlsx XML, xls BIFF, CSV delimiter, encrypted OOXML = Protected) | email/.../mime/SpreadsheetExtractor.kt | 05 (2.6) | Full | None | |
| 53 | SpreadsheetLines (header roles, Dr/Cr suffix, Excel serial dates, parseCsv) | statement/SpreadsheetLines.kt | 05 (2.6) | Full | None | |
| 54 | PDF text via PdfBox, Locked/Protected/Unreadable outcomes | email/.../mime/PdfTextExtractor.kt | 05 (2.3) | Full | None | Flutter uses Kotlin `pdf` channel per CLAUDE.md |
| 55 | Holdings readers: HoldingSheet, HoldingColumns, HoldingTable, HoldingLines, HoldingProfiles (17), HoldingsCheck | statement/Holding*.kt | 05 (2.8, 2.10), 16 | Full | None | |
| 56 | NpsStatement and EpfPassbook PDFs | statement/NpsStatement.kt, EpfPassbook.kt | 05 (2.8) | Full | None | |
| 57 | Password candidates (PAN, name+DDMM, DOB forms, phones, bank exact forms) and BankKeys | statement/PasswordGuesser.kt:51-153 | 05 (2.4) | Full | None | Caps 240/300 stated |
| 58 | MfOrderParser (SIP / purchase confirmation emails) | statement/MfOrderParser.kt:35-160 | 05 (2.9), 06 (2.13) | Partial | Expand 05 | Only summarised: no ABOUT_FUNDS / PURCHASE / DONE / NOT_DONE / REDEMPTION gates, scheme label and sentence patterns, units/NAV/amount/folio/date regexes, amount fallback units x NAV, platformOf text fallback, STOP_WORDS list |
| 59 | PortfolioSummary (INDmoney portfolio email to AGG holdings) | statement/PortfolioSummary.kt:17-77 | 05 (2.9), 16 | Partial | Expand 05 | Only the AGG id and replacement rule stated; missing IS_SUMMARY gate, class label regexes (US, MF, STOCKS), labelled-vs-positional figure logic, `currentFirst` header test, 31-day as-of window |
| 60 | Locked statement flow (store, notify once, unlock, retry) and per-account unlock details | StatementProcessor.kt:102-300, StatementPasswordStore.kt | 05 (2.4, 2.11) | Full | None | |
| 61 | Statement keep/re-read, holdings sidecar | StatementProcessor.kt:183-260 | 05 (2.1) | Full | None | |
| 62 | HoldingMatch: cross-source identity of one holding (ISIN vs `MF:` vs `STOCK:`, STOP / MARKERS / AMC_WORDS, EPF member-id normalise, aggregate coverage, preferredId) | shared/repo/HoldingMatch.kt:14-131 | none | Missing | Expand 16 | No hit for the class, sameName, preferredId or aggregatesCovered anywhere in memory. FR-16-09 says "upsert by identifier", which is wrong: source matches the same fund under a different key |
| 63 | HoldingRepository.record / dedupe / recordMfOrder (units + invested added, value = units x NAV, skipped if statement newer) | shared/repo/HoldingRepository.kt:24-179 | 16, 05 | Partial | Expand 16 | 16 line 79 states MF orders produce transactions "not holdings"; source also updates the fund holding. EPF contribution adds to invested, older snapshot ignored, aggregate gating and dedupe not stated |
| 64 | NpsContributions (claim-once key set, recordNpsContribution, bank-debit suppression window -4d..+2d, INVESTMENT txn merchant "NPS Tier I/II", confidence 0.8) | shared/repo/NpsContributions.kt:19-84, HoldingRepository.kt:145 | 06 (2.13), 05 | Partial | Expand 16 (or 05) | Key format and SMS/email dedup stated; holding update rules and the generated transaction fields are not |
| 65 | AccountGuess and ensureAccount rules (card type, network, lender LOAN, phone-tail guard, APP no-create) | shared/repo/AccountGuess.kt | 06 (2.11), 04 (2.7) | Full | None | |
| 66 | DepositTerms (maturity day and action to account) | shared/repo/DepositTerms.kt | 13 | Full | None | |
| 67 | Parser bench debug screen | app/.../ui/bench/ParserBenchScreen.kt:77 | 06 (UI table) | Full | None | Dev-only |

Counts: 67 capabilities found; Full 61; Partial 5 (#18, 58, 59, 63, 64); Missing 1 (#62). Rows 29 and 31 are Full with a small count-consistency fix.

## Gaps

1. HoldingMatch (Missing): add to `16_portfolio.md` the same-investment rules (identifier equality, EPF member-id normalisation, kind families, ISIN vs ISIN never equal, US vs Indian, sameName with STOP words, MARKERS must agree, AMC_WORDS allowance, preferredId order, aggregate coverage map, dedupe keeps statement copy then newest). Correct FR-16-09.
2. Holdings side effects of MF orders and NPS contributions (Partial): `recordMfOrder`, `recordNpsContribution`, and the `record()` update rules (older asOf ignored, previousValue kept, EPF contribution added to invested, manual rows untouched) belong in `16_portfolio.md`; fix line 79 (MF orders do update the holding).
3. MfOrderParser (Partial): add its regex families and gates to `05_statement_import.md` 2.9 so the Dart port is not written from a summary.
4. PortfolioSummary (Partial): add detection and figure-reading rules to `05_statement_import.md` 2.9.
5. Count and wording inconsistencies: listed banks 51 in source and in the 06 table (06 text says 50; 02 says about 55); lenders 17 (02 says 16 parsers).
6. 06 2.10 "Open Questions" note that subcategory regexes are not enumerated is stale; they are in 09 2.3.
7. No source capability was found with no home at all beyond #62; no extra ingestion source (no share-intent, clipboard or other import path) exists in the Kotlin app. Deep links (`hisaab://statements?unlock=`) are covered in 05.
