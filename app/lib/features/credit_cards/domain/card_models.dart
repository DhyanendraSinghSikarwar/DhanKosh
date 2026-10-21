import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:parser_core/parser_core.dart' show TransactionType;

/// Where a card bill figure came from.
enum CardDueSource { sms, email, statement, manual }

/// Reminder stages (FR-14-10): [offsetDays] before the due day.
enum DueStage {
  days5(5),
  days2(2),
  dueDay(0),
  overdue(-1);

  const DueStage(this.offsetDays);

  /// Days from the due date at which the stage is reached.
  final int offsetDays;
}

/// A card movement (FR-14-17): rupee value of a ledger row.
class CardFlow {
  /// Creates a movement.
  const CardFlow(this.timestampMs, this.type, this.inrMinor);

  final int timestampMs;
  final TransactionType type;
  final int inrMinor;
}

/// A bill or payment record used to work out a card position: a row of
/// `card_due_notices` or a CREDIT_CARD statement.
class CardRow {
  /// Creates a row.
  const CardRow({
    required this.source,
    required this.receivedAt,
    required this.processedAt,
    this.isPayment = false,
    this.bankName,
    this.last4,
    this.totalDueMinor,
    this.minDueMinor,
    this.dueEpochDay,
    this.creditLimitMinor,
    this.statementEpochDay,
    this.availableMinor,
    this.paymentMinor,
  });

  final CardDueSource source;

  /// True for a payment acknowledgement (`paymentMinor`, day in
  /// `statementEpochDay`).
  final bool isPayment;
  final String? bankName;
  final String? last4;

  /// Epoch ms.
  final int receivedAt;
  final int processedAt;
  final int? totalDueMinor;
  final int? minDueMinor;
  final int? dueEpochDay;
  final int? creditLimitMinor;
  final int? statementEpochDay;
  final int? availableMinor;
  final int? paymentMinor;

  /// Arrival time: `receivedAt` when set, else `processedAt`.
  int get arrivalMs => receivedAt > 0 ? receivedAt : processedAt;

  /// A bill row carries a total or a due date.
  bool get carriesBill =>
      !isPayment && (totalDueMinor != null || dueEpochDay != null);
}

/// The user's manual figures for one card (FR-14-07).
class CardOverride {
  /// Creates an override; an all-null one is ignored.
  const CardOverride({
    required this.cardKey,
    required this.setAt,
    this.billedMinor,
    this.minDueMinor,
    this.dueEpochDay,
    this.unbilledMinor,
    this.outstandingMinor,
  });

  /// `<bank lower>:<last4>`.
  final String cardKey;

  /// Epoch ms.
  final int setAt;
  final int? billedMinor;
  final int? minDueMinor;
  final int? dueEpochDay;
  final int? unbilledMinor;
  final int? outstandingMinor;

  /// Nothing overridden.
  bool get isEmpty =>
      billedMinor == null &&
      minDueMinor == null &&
      dueEpochDay == null &&
      unbilledMinor == null &&
      outstandingMinor == null;
}

/// Worked-out figures of a card (FR-14-02). Money in paise, days as epoch
/// days.
class CardPosition {
  /// Creates a position.
  const CardPosition({
    this.billedMinor,
    this.minDueMinor,
    this.dueDay,
    this.statementDay,
    this.limitMinor,
    this.unbilledMinor,
    this.outstandingMinor,
    this.estimated = false,
    this.billedEdited = false,
    this.minDueEdited = false,
    this.dueEdited = false,
    this.unbilledEdited = false,
    this.outstandingEdited = false,
    this.calculated,
    this.source,
    this.sourceAtMs,
  });

  final int? billedMinor;
  final int? minDueMinor;
  final int? dueDay;
  final int? statementDay;
  final int? limitMinor;
  final int? unbilledMinor;
  final int? outstandingMinor;
  final bool estimated;
  final bool billedEdited;
  final bool minDueEdited;
  final bool dueEdited;
  final bool unbilledEdited;
  final bool outstandingEdited;

  /// The position beneath an override.
  final CardPosition? calculated;
  final CardDueSource? source;
  final int? sourceAtMs;

  /// Any figure manually edited.
  bool get edited =>
      billedEdited ||
      minDueEdited ||
      dueEdited ||
      unbilledEdited ||
      outstandingEdited;

  /// Billed + unbilled when either is known, else the outstanding figure.
  int? get totalMinor => (billedMinor != null || unbilledMinor != null)
      ? (billedMinor ?? 0) + (unbilledMinor ?? 0)
      : outstandingMinor;

  /// Billed if > 0, else outstanding if > 0, else 0 (net worth liability).
  int get owedMinor => (billedMinor ?? 0) > 0
      ? billedMinor!
      : ((outstandingMinor ?? 0) > 0 ? outstandingMinor! : 0);

  /// Limit left: `max(0, limit - total)` when billed, unbilled or
  /// outstanding was edited, else the stated [availableMinor] (FR-14-14).
  int? limitLeft(int? limit, int? availableMinor) {
    if ((billedEdited || unbilledEdited || outstandingEdited) &&
        limit != null &&
        totalMinor != null) {
      final left = limit - totalMinor!;
      return left < 0 ? 0 : left;
    }
    return availableMinor;
  }
}

/// A credit card with its figures, for Home, the card page and net worth.
class CardLimit {
  /// Creates a card view.
  const CardLimit({
    required this.id,
    required this.name,
    required this.bankName,
    required this.last4,
    required this.position,
    required this.paid,
    this.availableMinor,
    this.availableEstimated = false,
    this.network,
  });

  /// Account id of the card.
  final int id;
  final String name;
  final String bankName;
  final String last4;
  final CardPosition position;

  /// Marked paid for the current due date (FR-14-09).
  final bool paid;

  /// Current available limit.
  final int? availableMinor;
  final bool availableEstimated;
  final CardNetwork? network;

  int? get limitMinor => position.limitMinor;
  int? get billedMinor => position.billedMinor;
  int? get unbilledMinor => position.unbilledMinor;
  int? get minDueMinor => position.minDueMinor;
  int? get outstandingMinor => position.outstandingMinor;
  int? get dueDay => position.dueDay;
  bool get estimated => position.estimated;

  /// Counted as a liability in net worth (FR-14-16).
  int get owedMinor => position.owedMinor;

  /// Limit left per FR-14-14.
  int? get limitLeftMinor => position.limitLeft(limitMinor, availableMinor);
}

/// A bill or payment notice to record (FR-14-06).
class NewCardNotice {
  /// Creates a notice.
  const NewCardNotice({
    required this.isPayment,
    required this.source,
    required this.receivedAt,
    required this.processedAt,
    this.bankName,
    this.last4,
    this.totalDueMinor,
    this.minDueMinor,
    this.dueEpochDay,
    this.creditLimitMinor,
    this.statementEpochDay,
    this.availableMinor,
    this.paymentMinor,
  });

  final bool isPayment;

  /// SMS, email or statement.
  final CardDueSource source;
  final int receivedAt;
  final int processedAt;
  final String? bankName;
  final String? last4;
  final int? totalDueMinor;
  final int? minDueMinor;
  final int? dueEpochDay;
  final int? creditLimitMinor;

  /// Statement day; for a payment the day it was acknowledged.
  final int? statementEpochDay;
  final int? availableMinor;
  final int? paymentMinor;
}
