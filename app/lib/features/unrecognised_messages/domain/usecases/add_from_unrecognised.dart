import 'package:hisaab/features/transactions_ledger/domain/ingest.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_message.dart';
import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_repository.dart';
import 'package:parser_core/parser_core.dart';

/// What the user confirmed on the pre-filled form.
class ConfirmedPayment {
  /// Creates a confirmed payment.
  const ConfirmedPayment({
    required this.amountMinor,
    required this.type,
    required this.timestamp,
    this.currency = 'INR',
    this.accountId,
    this.accountBank,
    this.accountLast4,
    this.merchant,
    this.upiId,
    this.category = Category.other,
    this.reference,
    this.note,
    this.channel = Channel.other,
  });

  /// Amount in paise.
  final int amountMinor;

  /// Debit, credit or investment.
  final TransactionType type;

  /// Time, epoch ms.
  final int timestamp;

  /// ISO currency.
  final String currency;

  /// Chosen account, if any.
  final int? accountId;

  /// Bank and last digits of the chosen account, to remember for the sender.
  final String? accountBank;

  /// Last digits of the chosen account.
  final String? accountLast4;

  /// Payee.
  final String? merchant;

  /// UPI id.
  final String? upiId;

  /// Category.
  final Category category;

  /// Reference number.
  final String? reference;

  /// Note.
  final String? note;

  /// Payment rail.
  final Channel channel;
}

/// Adds a queued message as a transaction through the single ledger write
/// path, keeping the message's source and id, then teaches the app the sender
/// (FR-38-07, FR-38-11).
class AddFromUnrecognised {
  /// Creates the use case.
  const AddFromUnrecognised({
    required UnrecognisedRepository queue,
    required TransactionRepository ledger,
  })  : _queue = queue,
        _ledger = ledger;

  final UnrecognisedRepository _queue;
  final TransactionRepository _ledger;

  /// Adds [m] as [c].
  Future<IngestResult> call(UnrecognisedMessage m, ConfirmedPayment c) async {
    final result = await _ledger.addFromMessage(
      source: m.source == UnrecognisedSource.app ? Source.app : Source.sms,
      sourceMessageId: m.sourceMessageId,
      sender: m.sender,
      rawText: m.body,
      amountMinor: c.amountMinor,
      type: c.type,
      timestamp: c.timestamp,
      currency: c.currency,
      accountId: c.accountId,
      merchant: c.merchant,
      upiId: c.upiId,
      category: c.category,
      reference: c.reference,
      note: c.note,
      channel: c.channel,
    );
    await _queue.markAdded(m.id, transactionId: result.transactionId);
    if (m.source == UnrecognisedSource.sms) {
      // Latest booking wins. The account is kept only when the text does not
      // name other digits: a form the user corrected is not evidence about
      // the sender (FR-38-07).
      final textLast4 = GenericExtractor.read(m.sender, m.body)?.last4;
      final keep = c.accountLast4 != null &&
          (textLast4 == null || textLast4 == c.accountLast4);
      await _queue.learn(
        m.senderKey,
        bankName: keep ? c.accountBank : null,
        last4: keep ? c.accountLast4 : null,
        currency: keep ? c.currency : null,
      );
    }
    return result;
  }
}
