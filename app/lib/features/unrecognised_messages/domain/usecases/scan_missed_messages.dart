import 'package:hisaab/features/sms_ingestion/domain/sms_ports.dart';
import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_message.dart';
import 'package:hisaab/features/unrecognised_messages/domain/usecases/offer_unrecognised.dart';
import 'package:parser_core/parser_core.dart';

/// What a scan for missed messages found.
class MissedScan {
  /// Creates a result.
  const MissedScan({required this.read, required this.queued});

  /// Messages from senders no parser claims that were looked at.
  final int read;

  /// Messages that look like payments and now wait in the queue.
  final int queued;
}

/// The user's own "find missed messages": reads the inbox once for senders no
/// parser claims and queues what looks like a payment (FR-38-04). Nothing is
/// added, and nothing from a promotional header, a phone number or a bank the
/// app already reads is looked at.
class ScanMissedMessages {
  /// Creates the use case. [knownSender] is the parsers' own sender test.
  const ScanMissedMessages({
    required SmsInboxSource inbox,
    required OfferUnrecognised offer,
    required bool Function(String sender) knownSender,
  })  : _inbox = inbox,
        _offer = offer,
        _known = knownSender;

  final SmsInboxSource _inbox;
  final OfferUnrecognised _offer;
  final bool Function(String) _known;

  /// Reads messages newer than [sinceMs].
  Future<MissedScan> call({required int sinceMs}) async {
    var read = 0;
    var queued = 0;
    await _inbox.readBatches(
      since: sinceMs,
      batchSize: 200,
      accept: (sender) =>
          !_known(sender) && GenericExtractor.isCandidateSender(sender),
      onBatch: (batch) async {
        for (final sms in batch) {
          read++;
          final r = await _offer.sms(
            NewUnrecognised(
              source: UnrecognisedSource.sms,
              sender: sms.sender,
              sourceMessageId: sms.messageId,
              body: sms.body,
              receivedAt: sms.receivedAt,
            ),
            requireLearned: false,
          );
          if (r != OfferResult.skipped) queued++;
        }
      },
    );
    return MissedScan(read: read, queued: queued);
  }
}
