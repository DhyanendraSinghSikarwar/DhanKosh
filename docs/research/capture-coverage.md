# Capture coverage matrix

Dated 2026-10-25. What the Flutter app records from each kind of input, established by reading the code and by running `app/test/e2e/capture_matrix_test.dart` (66 tests, all green) against the real pipeline: parsers, `IngestMessage`, dedup, `TransactionRepository`, `HoldingRepository`, `CardDueRepository`, `ImportStatement`, `SyncEmail` wiring and `HandleAppNotification`, over an in-memory Drift database. All documents in the tests are fictional or masked. Fixtures: `app/test/e2e/fixtures.dart`.

## What the tests fake and what they prove

| Faked at the native edge | Real behind it |
|---|---|
| PDF text (PdfBox): a `TaggedPdf` returns the text a PDF would yield, can demand a password or report "scanned" | Password tries, LOCKED flow, text parser, ledger, holdings, card dues, account effects |
| IMAP server: `FakeImap` serves `RawEmail` objects through the real sender whitelist | `SyncEmail`, processed-mail marking, ingest, statement attachment hand-off, body-only portfolio summaries |
| Notification stream: tests call `HandleAppNotification` with an `AppNotification` | Package filter, chat filter, source toggle, free-text parser, ingest |
| SMS inbox / receiver: tests call `IngestMessage` with `InboxSms` | Sender registry, bank parsers, rejection rules, dedup, ledger |

Not faked: `.xlsx` (real workbooks built with the `excel` package and read by the real `SheetReaderImpl`), `.csv`.

A test passing here proves the Dart logic. It does not prove the Kotlin side, a real PDF, or a real device. See "Unverified on a device".

## Verdict by category

| # | Category | Supported | Short reason |
|---|---|---|---|
| a | Transactions from SMS, email, notifications | Yes | 10 bank parsers + 51 listed banks + 17 lenders + payment apps; SMS and email of one payment merge |
| b | Statements by mail or file (bank, card) | Partial | Text PDFs, CSV, XLSX parse; scanned PDF and `.xls` refused; real PDF text unverified |
| c | Mutual funds | Partial | CAS (CAMS, CDSL, NSDL), Groww/other platform sheets, INDmoney summary mail yes; SIP/order mails not recorded |
| d | Stocks and ETFs | Partial | Holdings statements and sheets yes; contract notes and trade SMS no |
| e | PF / EPF | Yes | EPFO SMS and passbook PDF share one holding key |
| f | NPS | Partial | Statement and holding-value SMS yes; contribution SMS parsed but not recorded |
| g | FD / RD / PPF and loans | Partial | From statements and advices yes; FD/loan SMS and mail not recorded; EMI receipts yes |
| h | Card due notices | Yes | SMS, mail and statements; app notifications deliberately excluded |

## a. Bank and card transactions

Supported: **Yes**.

Covered (from `ParserRegistry.standard()`, 79 parsers):
- Ten bank parsers: HDFC Bank, ICICI Bank, SBI, Axis Bank, Kotak Mahindra Bank, IDFC FIRST Bank, Yes Bank, Bank of Baroda, Punjab National Bank, AU Small Finance Bank. Corpus: 199 anonymised samples (138 SMS, 61 email, 48 expected rejections) in `packages/parser_core/test/corpus`.
- 51 listed banks via `ListedBankParser` (generic bank grammar, bank name from the sender): Central Bank of India, Bank of Maharashtra, Canara, Union Bank, Bank of India, Indian Bank, IOB, UCO, Punjab & Sind, IDBI, IndusInd, Federal, South Indian, Karur Vysya, City Union, CSB, DCB, TMB, J&K Bank, Dhanlaxmi, Nainital, Karnataka Bank, RBL, Bandhan, Equitas / Ujjivan / Jana / Suryoday / Utkarsh / ESAF / Capital small finance banks, HSBC, Standard Chartered, Citibank, DBS, Paytm / Airtel / India Post / Fino / Jio payments banks, and co-operative banks (Nagrik, Saraswat, Cosmos, SVC, Abhyudaya, TJSB, Bharat, Kalupur, NKGSB, Janata, Apna). These have no per-bank corpus: the test sends one generic UPI debit per bank header and checks it is stored, which proves the sender is routed and the generic grammar matches, not that every bank's real wording is covered.
- Seventeen lenders (see g). `UPI app` parser: PhonePe, Google Pay, Paytm, CRED, MobiKwik, Amazon Pay, Freecharge, super.money receipts by mail or SMS.
- Notifications (`PaymentApps`): Google Pay, PhonePe, Paytm, BHIM, CRED, Amazon Pay, MobiKwik, Navi, super.money, Freecharge, BHIM SBI Pay, YONO SBI, HDFC Bank, ICICI iMobile, Axis Mobile, Kotak, Samsung Wallet / Pay Mini, WhatsApp (chat-guarded). 75 notification layouts in `notification_cases.dart`.
- Dedup: an SMS and an email for the same payment merge; a payment-app receipt and the bank's UPI SMS merge on the UPI reference.
- Rejected: OTP, promo/loan offers, failed or declined, future-dated mandates ("will be debited"), unknown senders, newsletters from bank domains, chat messages in WhatsApp, failed payment notifications.

Evidence (`capture_matrix_test.dart`): `a1 ... the ten corpus banks end to end` (10 tests, one per bank: every accepted sample stored with expected amount, type and last4; every reject empty), `SMS and email of the same payment are one ledger row`, `credit card spend is a card row with the available limit`, `a2 ... every listed bank sender is accepted and a debit is stored`, `a3` group (PhonePe email + bank SMS = one row; PhonePe, Google Pay, Paytm debit and PhonePe credit notifications; toggle off; unwatched app; failed payment; WhatsApp chat; card bill from notification not recorded), `negative cases` group (OTP, promo, failed, future, unknown sender, no-payment bank mail).

Limitations:
- Only messages whose sender code or mail domain is in the registry are read. A bank not in the 79 parsers is ignored.
- Bank wording changes break parsers silently; the corpus is anonymised from the Kotlin app, not from live 2026 traffic.
- A card payment received SMS is stored as a TRANSFER on the card, not a spend (by design).
- Notifications need the user to enable the source toggle and grant notification access.

## b. Statements (bank and card)

Supported: **Partial**.

Covered: text-layer PDFs (after native text extraction), `.csv`, real `.xlsx`. Layouts exercised: HDFC credit card, SBI account (direction from running balance), HDFC account rows as CSV/XLSX; card due layouts recognised for 14 issuers (HDFC, ICICI, SBI Card, Axis, Kotak, IDFC FIRST, Yes, AU, IndusInd, RBL, Federal, HSBC, Standard Chartered, American Express: `card_dues_test.dart`). Statement mails: attachments are handed to the importer by `SyncEmail` (PDF/xlsx/csv under the size cap); a statement mail from a non-whitelisted sender is not fetched unless the subject looks like a statement (`ParserRegistry.statementSubjects`). Password: none, derived from profile/PAN/card last4, saved, then prompt; a locked mail attachment is held LOCKED. A statement row equal to an earlier SMS merges with it. Re-importing the same file or re-syncing the same mail adds nothing.

Evidence: `b statements` group: `credit card statement PDF: rows, due notice, card limit`, `bank account statement PDF: direction from running balance`, `statement row equal to an earlier SMS merges`, `same file twice is refused`, `password-protected PDF is held LOCKED` (and unlock), `scanned (image-only) PDF is unsupported`, `legacy .xls is unsupported`, `bank statement as CSV`, `bank statement as real XLSX`, `statement PDF attached to a bank mail is imported once by sync`, `statement mail from a sender outside the whitelist is not fetched`.

Limitations:
- Scanned/image PDFs: unsupported (no OCR).
- `.xls`: refused with a reason; only `.xlsx`/`.csv`.
- Password-protected spreadsheets: refused.
- Statement text is parsed with generic table heuristics. Only the layouts above are tested; any other bank's PDF may yield zero or partial rows. Real statement PDFs vary by month and product.
- Statement body links ("download your statement") are not followed: only attachments.

## c. Mutual funds

Supported: **Partial**.

Covered:
- CAS text (CAMS closing-balance blocks with ISIN and value, CDSL CAS MF section, NSDL CAS folio rows) gives mutual fund holdings with units, value and invested amount. Verified: CAMS text via PDF import; CAS attached to a CAMS mail via sync; re-read adds no duplicate.
- Platform holdings sheets by column names (profiles): Groww (MF and stocks), Zerodha Coin, Kuvera, INDmoney, Paytm Money, ET Money; MFCentral/CAMS/KFintech by sender. Verified in the app with a real `.xlsx` Groww MF sheet (equity MF plus a gold fund classified as gold).
- INDmoney-style portfolio summary mail (body only) records aggregate holdings.
- A SIP debit SMS from the bank is an INVESTMENT transaction (not a spend).

Evidence: `c mutual funds` group (CAMS CAS PDF, CAS re-read, CAS by mail, Groww XLSX, INDmoney summary mail, SIP debit SMS, SIP mail limitation). Parser-level: `cas_holdings_test`, `holding_platforms_test`, `holdings_sheet_test`, `statement_to_holdings_test`.

Limitations:
- **Not recorded: SIP/order confirmation mails** (Groww, INDmoney, etc.). `MfOrderParser` exists in parser_core and is tested there, but no app code calls it. Test `LIMITATION: SIP / order confirmation mail records nothing` pins this. Holdings update only from statements, sheets and summaries.
- No transaction history for funds (CAS transaction rows are not turned into ledger rows); holdings are snapshots by identifier.
- Zerodha Coin, Kuvera, Paytm Money, ET Money profiles are tested at parser level only (and Groww in-app); the layouts are not confirmed from live exports.
- Value is as of the statement date, not live NAV.

## d. Stocks and ETFs

Supported: **Partial**.

Covered: CDSL CAS demat holdings by ISIN (stock and ETF); Groww stocks holdings PDF text; Zerodha-style holdings CSV (Kite `Instrument, Qty., Avg. cost, LTP, Cur. val`); profiles for Zerodha Console, Upstox, Angel One, Dhan, ICICI Direct, HDFC Securities, Kotak Securities; INDmoney US stocks (valued at the statement's own USD/INR rate, left out without one).

Evidence: `d stocks and ETFs` group (CDSL CAS, Zerodha CSV, Groww stocks PDF, contract-note limitation); parser-level `holding_platforms_test`.

Limitations:
- Contract notes, trade confirmation SMS/mail and order SMS are not parsed (`LIMITATION: a trade contract note...`). Only holdings snapshots.
- Broker holdings layouts other than Groww, Zerodha and CDSL CAS are covered by profiles but not run through the app here.
- Holdings are snapshots; realised P&L, dividends and corporate actions are not tracked.
- ETF classification from a CDSL row may be reported as ETF or fund by name; the test accepts either.

## e. PF / EPF

Supported: **Yes**.

Covered: EPFO SMS ("passbook balance against MH/BAN/..."), member passbook PDF text. Both give an EPF holding with the same key `EPF:<member id>`, so the passbook updates the SMS holding instead of duplicating (`passbook PDF updates the same EPF holding (one key)`). No transaction rows are created.

Evidence: `e PF / EPF` group (2 tests); `statement_to_holdings_test` EPF passbook.

Limitations: EPFO SMS sender codes beyond `EPFOHO` are routed by registry only if listed; the UMANG/EPFO web passbook must be saved as a text PDF; scanned passbook unsupported. Contribution months are not ledgered.

## f. NPS

Supported: **Partial**.

Covered: NPS statement of transactions PDF text (Tier I holding by PRAN last 4, value and total contribution); holding-value SMS from CRA/NPS Trust senders (`NPSTRS`, `NPSCRA`, `PFRDAI`, `NSDLPR`, `KFINTN`, `CAMSNP`).

Evidence: `f NPS` group (holding SMS, statement PDF, contribution limitation).

Limitations:
- **A contribution SMS alone records nothing** (`InvestmentParser.npsContribution` exists and is unit-tested but is not called by ingest). Test `LIMITATION: a contribution SMS alone records nothing`.
- Tier II appears only when the statement lists it; the test statement covers Tier I.
- Contributions are not ledgered as transactions.

## g. Deposits (FD, RD, PPF) and loans

Supported: **Partial**.

Covered:
- FD advice PDF text creates an FD account (balance = principal, maturity date and action), no transaction. PPF statement PDF sets a PPF account balance. RD uses the same path (parser-level tests in `deposit_messages_test`, `statement_to_holdings_test`).
- Lender EMI receipts by SMS or mail are DEBIT rows on the loan account with the EMI category. Lenders: Propelld, Aditya Birla Capital, Bajaj Finance, Tata Capital, HDFC Credila, Avanse, InCred, SMFG India Credit, Home Credit, KreditBee, Navi, Poonawalla Fincorp, HDB Financial, L&T Finance, Hero FinCorp, Cholamandalam, Mahindra Finance. Loan statements apply the outstanding balance to a loan account.
- Loan reminders ("EMI due on ...") are not transactions.

Evidence: `g deposits and loans` group (FD advice PDF, PPF PDF, FD SMS limitation, lender EMI SMS, lender EMI mail, EMI reminder limitation).

Limitations:
- **FD/RD/PPF booking SMS and mails are not recorded**: `registry.loanStatus` parses them but `IngestMessage` never calls it; only statements feed deposit and loan accounts. Test `LIMITATION: FD booking SMS is not recorded as a deposit`.
- Loan disbursal or outstanding-balance SMS are likewise parser-only.
- Interest credits on FDs appear only as bank-account credits if the bank SMS is read.
- Only the HDFC FD SMS, ICICI FD advice and SBI PPF layouts are tested.

## h. Card due notices

Supported: **Yes**.

Covered: bill SMS or mail ("Total payment due ... Minimum ... Due date ...") records a notice with total due, minimum due, due date and card last 4, no transaction; card statements record a notice (plus credit limit and statement date); the same bill twice is one notice; a payment-received message is a card TRANSFER, not a spend; notices come from SMS, email and statements only.

Evidence: `h card due notices` group (Axis SMS, bill + statement, duplicate bill, payment received); `a3 ... an app notification never records a card bill`; parser-level `card_dues_test`, `card_bill_test`.

Limitations: only SMS/mail wording tested for Axis; issuer layouts for statements are tested at parser level for 14 issuers; due dates in an unusual format are skipped.

## Unverified on a device

- **PDF text extraction is native (PdfBox via the `pdf` platform channel) and was not run here.** All PDF tests feed text through a fake reader. Real statement PDFs vary: column order, wrapped lines, `₹` glyph mapped to `C`/`Rs`, page headers inside tables.
- **Scanned PDFs are unsupported**; the only evidence is that the app refuses them when the reader reports "scanned".
- **`.xls` is unsupported** (refused), `.xlsx` and `.csv` work.
- **Gmail OAuth is not built.** Email is IMAP with an app password only (Gmail needs 2-step verification and an app password; Outlook/others per IMAP settings). Sender whitelist applies; unlisted senders are skipped unless the subject looks like a statement.
- **Email body vs attachment**: bodies are parsed as transactions, bank alerts and portfolio summaries; attachments (PDF/xlsx/csv) go to the statement importer. Links in mails are not followed. HTML-only mails use the HTML-to-text path; a heavily styled mail may lose its figures.
- **SMS**: the READ_SMS/RECEIVE_SMS permission, the live receiver and the background/nightly wake are Kotlin code that has not been compiled or run on a device (CI builds the APK only). OEM battery restrictions can delay or drop background delivery. The inbox scan relies on the device's SMS provider.
- **Notification access** is a user-granted special permission; the `NotificationListenerService` is device-dependent, and some OEMs kill it. Only the Dart handling is tested.
- Sender header formats (`VM-HDFCBK`, `AX-ICICIB`) vary by operator and region; the registry matches on the header's core code.
- Corpus data is anonymised and derived from the Kotlin app's samples, not from live current messages.

## Bugs found by this work

None. No production code was changed.
