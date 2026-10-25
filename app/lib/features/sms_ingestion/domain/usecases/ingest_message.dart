import 'dart:isolate';

import 'package:hisaab/features/credit_cards/domain/card_due_repository.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/portfolio/domain/asset_class.dart' as pf;
import 'package:hisaab/features/portfolio/domain/holding.dart' as pf;
import 'package:hisaab/features/portfolio/domain/holding_repository.dart';
import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart'
    as sms;
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/statement_import/domain/usecases/apply_statement_accounts.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart' as led;
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:parser_core/parser_core.dart';

/// What happened to one message: the pipeline outcome plus the parse result.
class MessageIngestDetail {
  /// Creates a detail.
  const MessageIngestDetail(this.outcome, this.parse);

  /// Pipeline outcome (rejected when nothing was stored).
  final IngestOutcome outcome;

  /// Parser verdict; [Parsed] carries the transaction.
  final ParseResult parse;
}

/// One message through parse, categorise and ledger (FR-02-02, FR-02-04).
///
/// Category comes from the parser's merchant directory; learned and manual
/// rules are applied by the ledger inside the ingest transaction (FR-09-10).
class IngestMessage {
  /// Creates the use case. [ownNumberTails] feeds the account guard.
  IngestMessage({
    required TransactionRepository ledger,
    Future<Set<String>> Function()? ownNumberTails,
    ParserRegistry? registry,
    CardDueRepository? cardDues,
    HoldingRepository? holdings,
    ApplyStatementAccounts? accounts,
  })  : _ledger = ledger,
        _accounts = accounts,
        _cardDues = cardDues,
        _holdings = holdings,
        _tails = ownNumberTails,
        _customRegistry = registry != null,
        _registry = registry ?? ParserRegistry.standard();

  final TransactionRepository _ledger;
  final CardDueRepository? _cardDues;
  final HoldingRepository? _holdings;
  final ApplyStatementAccounts? _accounts;
  final Future<Set<String>> Function()? _tails;
  final ParserRegistry _registry;
  final bool _customRegistry;

  /// Cheap sender pre-filter (FR-02-02).
  bool accepts(String sender) => _registry.accepts(sender);

  /// Matches the SmsIngest typedef: SMS in, outcome out.
  Future<IngestOutcome> call(sms.InboxSms message) =>
      detail(message).then((d) => d.outcome);

  /// Batches at least this large are parsed on a worker isolate (FR-02-10).
  static const isolateThreshold = 50;

  /// Parses [batch] without storing anything. Large batches with the standard
  /// registry run on a worker isolate so the UI isolate stays free; results
  /// equal the sequential [parse] (FR-02-10).
  Future<List<ParseResult>> parseAll(List<sms.InboxSms> batch) async {
    if (batch.length < isolateThreshold || _customRegistry) {
      return [for (final m in batch) _parse(m)];
    }
    final rows = [
      for (final m in batch) (m.sender, m.body, m.receivedAt),
    ];
    return await Isolate.run(() => parseRows(rows));
  }

  /// Parses [batch] off the UI isolate, then stores each message in order on
  /// this isolate (the ledger owns the DB, FR-02-10).
  Future<List<MessageIngestDetail>> ingestBatch(
    List<sms.InboxSms> batch,
  ) async {
    final results = await parseAll(batch);
    return [
      for (var i = 0; i < batch.length; i++)
        await _store(batch[i], results[i], Source.sms, null),
    ];
  }

  /// Pure parse of one row, usable inside a worker isolate (FR-02-10).
  static List<ParseResult> parseRows(List<(String, String, int)> rows) => [
        for (final (sender, body, at) in rows)
          parse(Source.sms, sender, body, at),
      ];

  ParseResult _parse(sms.InboxSms m, [Source source = Source.sms]) =>
      parse(source, m.sender, m.body, m.receivedAt, registry: _registry);

  /// Ingests [message]; [source] is SMS or email. [messageId] defaults to the
  /// SMS id.
  Future<MessageIngestDetail> detail(
    sms.InboxSms message, {
    Source source = Source.sms,
    String? messageId,
  }) =>
      _store(message, _parse(message, source), source, messageId);

  Future<MessageIngestDetail> _store(
    sms.InboxSms message,
    ParseResult result,
    Source source,
    String? messageId,
  ) async {
    final tx = result.transaction;
    final side = await _recordSide(
      message,
      source,
      messageId ?? message.messageId,
      hasTransaction: tx != null,
    );
    if (tx == null) {
      return MessageIngestDetail(
        side ? IngestOutcome.inserted : IngestOutcome.rejected,
        result,
      );
    }
    final r = await _ledger.ingest(
      led.IngestItem(
        parsed: tx,
        sourceMessageId: messageId ?? message.messageId,
        rawText: message.body,
        phoneLast4s: await _tails?.call() ?? const {},
      ),
    );
    final outcome = switch (r.outcome) {
      led.IngestOutcome.inserted => IngestOutcome.inserted,
      led.IngestOutcome.merged => IngestOutcome.merged,
      led.IngestOutcome.flagged => IngestOutcome.flagged,
      led.IngestOutcome.skipped => IngestOutcome.skipped,
    };
    return MessageIngestDetail(outcome, result);
  }

  /// Records a card due notice (FR-14-06) and an EPF/NPS holding (FR-06-15)
  /// from [message]; neither is a transaction. Both run independently of the
  /// transaction parse, so a message can feed more than one. Notifications
  /// (Source.app) never carry either. True when something was stored.
  Future<bool> _recordSide(
    sms.InboxSms message,
    Source source,
    String messageId, {
    required bool hasTransaction,
  }) async {
    if (source == Source.app) return false;
    final at = message.receivedAt;
    var stored = false;
    final dues = _cardDues;
    if (dues != null) {
      final d = parseCardDue(message.body, message.sender, at);
      if (d != null) {
        stored = await dues.recordNotice(
              NewCardNotice(
                isPayment: d.paymentMinor != null,
                source: source == Source.email
                    ? CardDueSource.email
                    : CardDueSource.sms,
                receivedAt: at,
                processedAt: DateTime.now().millisecondsSinceEpoch,
                bankName: d.bank,
                last4: d.last4,
                totalDueMinor: d.totalDueMinor,
                minDueMinor: d.minDueMinor,
                dueEpochDay: d.dueEpochDay,
                statementEpochDay: d.statementEpochDay,
                paymentMinor: d.paymentMinor,
              ),
            ) ||
            stored;
      }
    }
    final holdings = _holdings;
    if (holdings != null) {
      // FR-16-21: an NPS contribution adds to the tier's invested total.
      final c = InvestmentParser.npsContribution(message.body, at);
      if (c != null) {
        return await _recordNps(c, message, source, messageId, holdings) ||
            stored;
      }
      // FR-16-19: a fund purchase confirmation (SIP instalment, units
      // allotted) when no bank transaction was read from the message.
      if (!hasTransaction) {
        final o = parseMfOrder(message.body, null, message.sender, at);
        if (o != null &&
            await holdings.recordMfOrder(
              MfOrderEntry(
                schemeName: o.schemeName,
                identifier: o.identifier,
                at: _orderTime(o.date, at),
                platform: o.platform,
                folio: o.folio,
                amountMinor: o.amountMinor,
                units: o.units,
                nav: o.nav,
              ),
              claimKey: messageId,
            )) {
          return true;
        }
      }
      final h = source == Source.email
          ? parseInvestmentEmail(message.body, at)
          : parseInvestmentSms(message.body, message.sender, at);
      if (h != null) {
        final n = await holdings.record(
          [
            pf.HoldingSnapshot(
              kind: pf.HoldingKind.values.byName(h.kind.name),
              name: h.name,
              identifier: h.identifier,
              asOf: h.asOf,
              units: h.units,
              valueMinor: h.valueMinor,
              investedMinor: h.investedMinor,
              contributionMinor: h.contributionMinor,
              platform: h.platform,
            ),
          ],
          source == Source.email
              ? pf.HoldingSource.email
              : pf.HoldingSource.sms,
        );
        stored = stored || n > 0;
      }
    }
    // FR-13-19, FR-15-13: a lender's or bank's status message (loan
    // outstanding, FD/RD/PPF booking or maturity). Mail only when it is not
    // also a transaction.
    final accounts = _accounts;
    if (accounts != null && (source == Source.sms || !hasTransaction)) {
      final st = _registry.loanStatus(message.body, message.sender, at, source);
      if (st != null &&
          !(await _tails?.call() ?? const {}).contains(st.last4)) {
        if (await accounts.applyDeposits([st]) > 0) stored = true;
      }
    }
    return stored;
  }

  static const _istMs = 19800000;

  /// Order time: the message time when dated that day, else noon IST.
  static int _orderTime(CivilDate d, int receivedAt) {
    final today = ((receivedAt + _istMs) / 86400000).floor();
    return d.toEpochDay() == today
        ? receivedAt
        : d.toEpochDay() * 86400000 + 12 * 3600000 - _istMs;
  }

  /// Adds [c] to its holding once, and records an INVESTMENT transaction
  /// unless the bank already reported a debit of that amount (FR-16-21).
  Future<bool> _recordNps(
    NpsContribution c,
    sms.InboxSms message,
    Source source,
    String messageId,
    HoldingRepository holdings,
  ) async {
    final at = _orderTime(c.date, message.receivedAt);
    final fresh = await holdings.recordNpsContribution(
      NpsContributionEntry(
        identifier: c.identifier,
        name: InvestmentParser.npsName(c.pranLast4, c.tier),
        amountMinor: c.amountMinor,
        at: at,
        key: c.key,
      ),
    );
    if (!fresh) return false;
    const day = 86400000;
    final near = await _ledger
        .watch(
          LedgerFilter(
            fromMs: at - 4 * day - 12 * 3600000,
            toMs: at + 2 * day + 12 * 3600000,
          ),
        )
        .first;
    final already = near.any(
      (t) =>
          t.amountMinor == c.amountMinor &&
          (t.type == TransactionType.debit ||
              t.type == TransactionType.investment),
    );
    if (!already) {
      await _ledger.ingest(
        led.IngestItem(
          parsed: ParsedTransaction(
            amountMinor: c.amountMinor,
            currency: 'INR',
            type: TransactionType.investment,
            bankName: 'NPS',
            accountLast4: null,
            accountKind: AccountKind.account,
            merchant: c.tier == 2 ? 'NPS Tier II' : 'NPS Tier I',
            upiId: null,
            referenceNumber: null,
            channel: Channel.other,
            balanceMinor: null,
            availableLimitMinor: null,
            transactionTime: at,
            hasExplicitTime: at == message.receivedAt,
            category: Category.investment,
            source: source,
            sender: message.sender,
            messageTimestamp: message.receivedAt,
            confidence: 0.8,
            transactionHash: TransactionHasher.hash(
              c.amountMinor,
              TransactionType.investment,
              null,
              c.date,
              null,
            ),
          ),
          sourceMessageId: '$messageId#nps',
          rawText: message.body,
        ),
      );
    }
    return true;
  }
}
