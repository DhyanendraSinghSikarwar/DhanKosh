import 'dart:isolate';

import 'package:hisaab/features/sms_ingestion/domain/entities/inbox_sms.dart'
    as sms;
import 'package:hisaab/features/sms_ingestion/domain/entities/sms_scan.dart';
import 'package:hisaab/features/transactions_ledger/domain/ingest.dart' as led;
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
  })  : _ledger = ledger,
        _tails = ownNumberTails,
        _customRegistry = registry != null,
        _registry = registry ?? ParserRegistry.standard();

  final TransactionRepository _ledger;
  final Future<Set<String>> Function()? _tails;
  final ParserRegistry _registry;
  final bool _customRegistry;

  /// Cheap sender pre-filter (FR-02-02).
  bool accepts(String sender) => _registry.accepts(sender);

  /// Matches the SmsIngest typedef: SMS in, outcome out.
  Future<IngestOutcome> call(sms.InboxSms message) async =>
      (await detail(message)).outcome;

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
    return Isolate.run(() => parseRows(rows));
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
    if (tx == null) {
      return MessageIngestDetail(IngestOutcome.rejected, result);
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
}
