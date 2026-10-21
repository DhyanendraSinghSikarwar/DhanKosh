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
        _registry = registry ?? ParserRegistry.standard();

  final TransactionRepository _ledger;
  final Future<Set<String>> Function()? _tails;
  final ParserRegistry _registry;

  /// Cheap sender pre-filter (FR-02-02).
  bool accepts(String sender) => _registry.accepts(sender);

  /// Matches the SmsIngest typedef: SMS in, outcome out.
  Future<IngestOutcome> call(sms.InboxSms message) async =>
      (await detail(message)).outcome;

  /// Ingests [message]; [source] is SMS or email. [messageId] defaults to the
  /// SMS id.
  Future<MessageIngestDetail> detail(
    sms.InboxSms message, {
    Source source = Source.sms,
    String? messageId,
  }) async {
    final result = parse(
      source,
      message.sender,
      message.body,
      message.receivedAt,
      registry: _registry,
    );
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
