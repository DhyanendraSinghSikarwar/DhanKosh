import 'package:parser_core/src/statement/table/statement_table.dart';

/// The closing balance a statement states and the day it is as of.
class ClosingBalance {
  /// Creates a closing balance.
  const ClosingBalance({required this.minor, required this.epochDay});

  /// The stated balance, paise (negative for an overdraft).
  final int minor;

  /// The day of the row it was read from.
  final int epochDay;
}

/// The result of comparing a statement's closing balance with the app's
/// (FR-05-29).
class BalanceComparison {
  /// Creates a comparison.
  const BalanceComparison({
    required this.statementMinor,
    required this.asOfEpochDay,
    this.appMinor,
  });

  /// The balance the statement states.
  final int statementMinor;

  /// The day it is as of.
  final int asOfEpochDay;

  /// The app's balance at the end of that day; null when the app has nothing
  /// to compare with.
  final int? appMinor;

  /// Statement minus app, paise; null when the app balance is unknown.
  int? get differenceMinor =>
      appMinor == null ? null : statementMinor - appMinor!;

  /// The two agree to the paisa.
  bool get matches => differenceMinor == 0;
}

/// Compares a statement with the account it was imported into (FR-05-29).
abstract final class StatementBalanceCheck {
  /// The closing balance of the rows of [s]: the last row with a balance when the file
  /// runs oldest first, the first when newest first. Null when no row carries
  /// a balance.
  static ClosingBalance? closing(MappedStatement s) {
    final withBalance = [
      for (final r in s.rows)
        if (r.balanceMinor != null) r,
    ];
    if (withBalance.isEmpty) return null;
    final r = s.continuity.oldestFirst ? withBalance.last : withBalance.first;
    return ClosingBalance(minor: r.balanceMinor!, epochDay: r.epochDay);
  }

  /// The comparison of [closing] with [appMinor].
  static BalanceComparison compare(ClosingBalance closing, int? appMinor) =>
      BalanceComparison(
        statementMinor: closing.minor,
        asOfEpochDay: closing.epochDay,
        appMinor: appMinor,
      );

  /// Whether a statement can be offered as the account's new balance: its
  /// running balances add up, so a wrong column choice is ruled out.
  static bool trustworthy(MappedStatement s) => s.continuity.addsUp;
}
