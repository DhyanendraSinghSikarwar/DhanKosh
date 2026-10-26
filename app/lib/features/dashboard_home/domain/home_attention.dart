/// What a "Needs attention" row is about (FR-17-25).
enum AttentionKind { duplicates, bill, statement, card }

/// One tappable row of the Needs attention block.
class AttentionItem {
  /// Creates a row.
  const AttentionItem({
    required this.kind,
    required this.title,
    required this.detail,
    required this.route,
  });

  final AttentionKind kind;
  final String title;
  final String detail;

  /// Route opened on tap.
  final String route;
}

/// A named thing due in `days` days (0 = today).
typedef DueIn = ({String name, int days});

/// Days within which a bill or card due counts as soon (FR-17-25).
const int attentionDays = 7;

String _when(int days) => switch (days) {
      < 0 => 'Overdue',
      0 => 'Due today',
      1 => 'Due tomorrow',
      _ => 'Due in $days days',
    };

/// Builds the Needs attention rows in fixed order: duplicates, bills,
/// statements, cards. Empty groups are left out (FR-17-25). Names only, never
/// amounts.
List<AttentionItem> buildAttention({
  required int reviewCount,
  required List<DueIn> bills,
  required int lockedStatements,
  required int unreadableStatements,
  required List<DueIn> cards,
}) {
  bool soon(DueIn d) => d.days <= attentionDays;
  final due = [...bills.where(soon)]..sort((a, b) => a.days.compareTo(b.days));
  final cardsDue = [...cards.where(soon)]
    ..sort((a, b) => a.days.compareTo(b.days));
  final badStatements = lockedStatements + unreadableStatements;
  return [
    if (reviewCount > 0)
      AttentionItem(
        kind: AttentionKind.duplicates,
        title: '$reviewCount to review',
        detail: 'Possible duplicates',
        route: '/review',
      ),
    if (due.isNotEmpty)
      AttentionItem(
        kind: AttentionKind.bill,
        title: due.length == 1 ? due.first.name : '${due.length} bills due',
        detail: due.length == 1
            ? _when(due.first.days)
            : 'Next: ${due.first.name} · ${_when(due.first.days)}',
        route: '/bills',
      ),
    if (badStatements > 0)
      AttentionItem(
        kind: AttentionKind.statement,
        title: badStatements == 1
            ? '1 statement needs attention'
            : '$badStatements statements need attention',
        detail: lockedStatements > 0 ? 'Locked or unreadable' : 'Unreadable',
        route: '/statements',
      ),
    if (cardsDue.isNotEmpty)
      AttentionItem(
        kind: AttentionKind.card,
        title: cardsDue.length == 1
            ? cardsDue.first.name
            : '${cardsDue.length} cards due',
        detail: _when(cardsDue.first.days),
        route: '/cards',
      ),
  ];
}

/// Net worth change against the latest recorded point before today.
class NetWorthChange {
  /// Creates a change.
  const NetWorthChange(this.deltaMinor, this.percentTenths);

  /// Current minus previous, paise.
  final int deltaMinor;

  /// Change in tenths of a percent (integer math); null when the previous
  /// value is not positive.
  final int? percentTenths;

  /// Compares [currentMinor] with the newest of [points] (epoch day, net)
  /// whose day is before [today]; falls back to the newest point. Null with
  /// no points (FR-17-26).
  static NetWorthChange? of(
    int currentMinor,
    List<({int day, int netMinor})> points,
    int today,
  ) {
    if (points.isEmpty) return null;
    final sorted = [...points]..sort((a, b) => a.day.compareTo(b.day));
    final before = sorted.where((p) => p.day < today);
    final base = before.isNotEmpty ? before.last : sorted.last;
    final delta = currentMinor - base.netMinor;
    final pct = base.netMinor > 0 ? delta * 1000 ~/ base.netMinor : null;
    return NetWorthChange(delta, pct);
  }
}
