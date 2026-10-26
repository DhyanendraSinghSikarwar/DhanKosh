/// How often a SIP instalment is made (FR-12-17). Extends the bills
/// frequency model (monthly) with daily, weekly and quarterly; yearly is not
/// a SIP.
enum SipFrequency {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  quarterly('Quarterly');

  const SipFrequency(this.label);

  /// Display name.
  final String label;

  /// Frequencies a user can set up (detection also finds quarterly).
  static const List<SipFrequency> manual = [daily, weekly, monthly];
}

/// One recorded instalment: an INVESTMENT ledger row or an MF order
/// (FR-12-18). Money in paise, [atMs] epoch ms.
class SipEvent {
  /// Creates an event.
  const SipEvent({
    required this.name,
    required this.atMs,
    required this.amountMinor,
  });

  final String name;
  final int atMs;
  final int amountMinor;
}

/// A detected or user SIP for display (FR-12-17..20). Dates are IST calendar
/// dates as UTC midnight `DateTime`s.
class Sip {
  /// Creates a SIP view.
  const Sip({
    required this.name,
    required this.amountMinor,
    required this.frequency,
    required this.nextDate,
    required this.totalInvestedMinor,
    required this.instalments,
    this.lastDate,
    this.manualId,
    this.dayOfMonth,
    this.weekday,
    this.startDay,
  });

  final String name;
  final int amountMinor;
  final SipFrequency frequency;
  final DateTime nextDate;

  /// Sum of the recorded instalments (detected) or the instalments due so
  /// far (user SIP without records).
  final int totalInvestedMinor;
  final int instalments;
  final DateTime? lastDate;

  /// Set for user SIPs.
  final int? manualId;
  final int? dayOfMonth;
  final int? weekday;
  final int? startDay;

  /// Found from the ledger or orders, not added by the user.
  bool get detected => manualId == null;
}

/// A persisted user SIP (FR-12-17).
class SipItem {
  /// Creates an item.
  const SipItem({
    required this.id,
    required this.name,
    required this.amountMinor,
    required this.frequency,
    required this.startDay,
    required this.createdAt,
    this.dayOfMonth,
    this.weekday,
  });

  final int id;
  final String name;
  final int amountMinor;
  final SipFrequency frequency;
  final int? dayOfMonth;

  /// 1 (Monday) .. 7 (Sunday).
  final int? weekday;

  /// Epoch day (IST) of the first instalment.
  final int startDay;
  final int createdAt;
}

/// Input for adding or editing a SIP.
class SipDraft {
  /// Creates a draft.
  const SipDraft({
    required this.name,
    required this.amountMinor,
    required this.frequency,
    required this.startDay,
    this.dayOfMonth,
    this.weekday,
  });

  final String name;
  final int amountMinor;
  final SipFrequency frequency;
  final int startDay;
  final int? dayOfMonth;
  final int? weekday;

  /// Null when valid, else a short reason.
  String? validate() {
    if (name.trim().isEmpty) return 'Name required';
    if (amountMinor <= 0) return 'Amount must be above 0';
    if (!SipFrequency.manual.contains(frequency)) return 'Pick a frequency';
    if (frequency == SipFrequency.monthly &&
        (dayOfMonth == null || dayOfMonth! < 1 || dayOfMonth! > 31)) {
      return 'Day must be 1 to 31';
    }
    if (frequency == SipFrequency.weekly &&
        (weekday == null || weekday! < 1 || weekday! > 7)) {
      return 'Pick a weekday';
    }
    return null;
  }
}

/// User SIPs store (FR-12-17). Tracking only.
abstract interface class SipRepository {
  /// All user SIPs, oldest first.
  Stream<List<SipItem>> watchAll();

  /// Adds a validated [draft]; returns the id. Throws [ArgumentError] when
  /// invalid.
  Future<int> add(SipDraft draft);

  /// Replaces SIP [id] with [draft].
  Future<void> update(int id, SipDraft draft);

  /// Deletes SIP [id].
  Future<void> delete(int id);
}
