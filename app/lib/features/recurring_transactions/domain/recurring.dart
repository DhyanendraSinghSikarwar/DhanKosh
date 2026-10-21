import 'package:parser_core/parser_core.dart';

/// Repeat cadence of a user item (FR-12-03).
enum RecurringFrequency { monthly, yearly }

/// A detected or user recurring payment (FR-12-02). Dates are IST calendar
/// dates as UTC midnight `DateTime`s; money in paise.
class Recurring {
  /// Creates a recurring entry.
  const Recurring({
    required this.name,
    required this.amountMinor,
    required this.dayOfMonth,
    required this.category,
    required this.nextDue,
    required this.occurrences,
    this.accountId,
    this.lastPaid,
    this.manualId,
    this.income = false,
    this.yearly = false,
    this.loanKey,
  });

  final String name;
  final int amountMinor;
  final int dayOfMonth;
  final Category category;
  final int? accountId;
  final DateTime? lastPaid;
  final DateTime nextDue;
  final int occurrences;

  /// Set for user-added items.
  final int? manualId;
  final bool income;
  final bool yearly;
  final String? loanKey;
}

/// A persisted user item (FR-12-03).
class RecurringItem {
  /// Creates an item.
  const RecurringItem({
    required this.id,
    required this.name,
    required this.amountMinor,
    required this.income,
    required this.frequency,
    required this.dayOfMonth,
    required this.category,
    required this.createdAt,
    this.month,
    this.accountId,
  });

  final int id;
  final String name;
  final int amountMinor;
  final bool income;
  final RecurringFrequency frequency;

  /// 1..31.
  final int dayOfMonth;

  /// 1..12 for yearly.
  final int? month;
  final Category category;
  final int? accountId;
  final int createdAt;
}

/// Input for adding or editing an item.
class RecurringDraft {
  /// Creates a draft.
  const RecurringDraft({
    required this.name,
    required this.amountMinor,
    required this.frequency,
    required this.dayOfMonth,
    required this.category,
    this.income = false,
    this.month,
    this.accountId,
  });

  final String name;
  final int amountMinor;
  final bool income;
  final RecurringFrequency frequency;
  final int dayOfMonth;
  final int? month;
  final Category category;
  final int? accountId;

  /// Null when valid, else a short reason (day 1..31, month 1..12 for yearly,
  /// name and positive amount).
  String? validate() {
    if (name.trim().isEmpty) return 'Name required';
    if (amountMinor <= 0) return 'Amount must be above 0';
    if (dayOfMonth < 1 || dayOfMonth > 31) return 'Day must be 1 to 31';
    if (frequency == RecurringFrequency.yearly &&
        (month == null || month! < 1 || month! > 12)) {
      return 'Month must be 1 to 12';
    }
    return null;
  }
}
