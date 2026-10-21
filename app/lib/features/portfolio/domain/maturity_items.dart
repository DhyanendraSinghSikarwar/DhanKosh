import 'package:hisaab/features/accounts_management/domain/account.dart';

/// A deposit maturing within a year (FR-16-12).
class MaturityItem {
  /// Creates an item.
  const MaturityItem({
    required this.accountId,
    required this.name,
    required this.day,
    required this.daysLeft,
    required this.soon,
    required this.type,
  });

  final int accountId;
  final String name;

  /// Epoch day of maturity.
  final int day;
  final int daysLeft;

  /// Due within 30 days (amber).
  final bool soon;
  final AccountType type;
}

/// FD, RD and PPF accounts with `maturityDay` in `[today, today + 365]`,
/// soonest first. [maturityDays] maps account id to its maturity epoch day
/// (the accounts table owns that column).
List<MaturityItem> maturityItems(
  List<Account> accounts,
  Map<int, int> maturityDays,
  int today,
) {
  final out = <MaturityItem>[];
  for (final a in accounts) {
    final t = a.accountType;
    final d = maturityDays[a.id];
    if (d == null || a.hidden || a.mergedIntoId != null) continue;
    if (t != AccountType.fd && t != AccountType.rd && t != AccountType.ppf) {
      continue;
    }
    final left = d - today;
    if (left < 0 || left > 365) continue;
    out.add(
      MaturityItem(
        accountId: a.id,
        name: a.label,
        day: d,
        daysLeft: left,
        soon: left <= 30,
        type: t!,
      ),
    );
  }
  out.sort((x, y) => x.day.compareTo(y.day));
  return out;
}
