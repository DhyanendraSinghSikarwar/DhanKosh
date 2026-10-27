import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Money that moved with no message: between two stated balances the tracked
/// rows do not add up (FR-13-15, memory 13 section 3.8). [deltaMinor] is
/// negative when money left; [card] gaps are changes of the available limit.
class UntrackedGap {
  /// Creates a gap.
  const UntrackedGap({
    required this.accountId,
    required this.fromTime,
    required this.toTime,
    required this.deltaMinor,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.card,
  });

  final int accountId;
  final int fromTime;
  final int toTime;
  final int deltaMinor;
  final int balanceBefore;
  final int balanceAfter;
  final bool card;

  /// Dismissal and notification identity: one window of one account.
  String get key => keyOf(accountId, fromTime, toTime);

  bool get moneyLeft => deltaMinor < 0;

  /// `"accountId|fromTime|toTime"`.
  static String keyOf(int accountId, int fromTime, int toTime) =>
      '$accountId|$fromTime|$toTime';
}

/// Finds [UntrackedGap]s. Pure: the caller loads accounts and rows.
abstract final class BalanceGaps {
  /// A gap must be at least a rupee ...
  static const minGapMinor = 100;

  /// ... and at least this share of the money involved (0.5%).
  static const minShareBps = 50;

  /// Balances stated longer ago than this are history.
  static const int maxAgeMs = 90 * 24 * 60 * 60 * 1000;

  /// History loaded before the 90-day window.
  static const historyDays = 240;

  static const _maxUnknownTransfers = 6;

  /// [transferDir]: TRANSFER row id to +1 (money came in) or -1 (left) when
  /// known; a transfer missing there is tried both ways (FR-13-15).
  static List<UntrackedGap> detect({
    required List<Account> accounts,
    required List<LedgerTx> txs,
    required Map<int, int> transferDir,
    required Set<String> dismissed,
    required int now,
  }) {
    final usable = txs
        .where(
          (t) =>
              !t.needsReview && t.duplicateOfId == null && t.accountId != null,
        )
        .toList();
    final byAccount = <int, List<LedgerTx>>{};
    for (final t in usable) {
      (byAccount[t.accountId!] ??= []).add(t);
    }
    final out = <UntrackedGap>[];
    for (final a in accounts) {
      if (a.mergedIntoId != null || a.hidden || a.linkedAccountId != null) {
        continue;
      }
      if (a.accountType != null && !a.accountType!.liquid) continue;
      final card = a.kind == AccountKind.card;
      final rows = [
        for (final m in memberIds(a, accounts)) ...?byAccount[m],
      ]..sort((x, y) {
          final c = x.timestamp.compareTo(y.timestamp);
          return c != 0 ? c : x.id.compareTo(y.id);
        });
      int? stated(LedgerTx t) => card ? t.availableLimitMinor : t.balanceMinor;
      final s = rows.where((t) => stated(t) != null).toList();
      for (var i = 1; i < s.length; i++) {
        final t1 = s[i - 1].timestamp;
        final t2 = s[i].timestamp;
        if (t2 <= t1 || now - t2 > maxAgeMs) continue;
        final m = a.manualBalanceAt;
        if (m != null && m > t1 && m <= t2) continue;
        final b1 = stated(s[i - 1])!;
        final b2 = stated(s[i])!;
        final gap = _gapIn(
          rows.where((t) => t.timestamp > t1 && t.timestamp <= t2).toList(),
          b1,
          b2,
          card: card,
          dir: transferDir,
        );
        if (gap == null) continue;
        final g = UntrackedGap(
          accountId: a.id,
          fromTime: t1,
          toTime: t2,
          deltaMinor: gap,
          balanceBefore: b1,
          balanceAfter: b2,
          card: card,
        );
        if (!dismissed.contains(g.key)) out.add(g);
      }
    }
    return out..sort((a, b) => b.toTime.compareTo(a.toTime));
  }

  /// [a] plus debit cards linked to it, accounts merged into it and their
  /// cards.
  static Set<int> memberIds(Account a, List<Account> all) {
    final merged = {
      for (final c in all)
        if (c.mergedIntoId == a.id) c.id,
    };
    return {
      a.id,
      for (final c in all)
        if (c.linkedAccountId == a.id ||
            c.mergedIntoId == a.id ||
            (c.linkedAccountId != null && merged.contains(c.linkedAccountId)))
          c.id,
    };
  }

  static int? _gapIn(
    List<LedgerTx> window,
    int b1,
    int b2, {
    required bool card,
    required Map<int, int> dir,
  }) {
    var known = 0;
    var sumAbs = 0;
    final unknown = <int>[];
    for (final t in window) {
      final amt = t.inrMinor;
      if (amt == null) return null;
      sumAbs += amt;
      switch (t.type) {
        case TransactionType.credit:
          known += amt;
        case TransactionType.debit:
        case TransactionType.investment:
          known -= amt;
        case TransactionType.transfer:
          final d = dir[t.id];
          if (card) {
            known += amt;
          } else if (d != null) {
            known += d * amt;
          } else {
            unknown.add(amt);
          }
      }
    }
    if (unknown.length > _maxUnknownTransfers) return null;
    final base = b2 - (b1 + known);
    var sums = <int>[0];
    for (final u in unknown) {
      sums = [
        for (final s in sums) ...[s + u, s - u],
      ];
    }
    final gaps = [for (final s in sums) base - s];
    if (gaps.any((g) => !_significant(g, sumAbs))) return null;
    if (unknown.isNotEmpty) return null;
    return gaps.single;
  }

  static bool _significant(int gap, int windowAmounts) {
    final involved = gap.abs() + windowAmounts;
    final floor = involved * minShareBps ~/ 10000;
    return gap.abs() >= (floor > minGapMinor ? floor : minGapMinor);
  }
}

/// A way to explain a gap.
enum GapChoice { payment, transfer, received }

/// What Add transaction starts with for a gap (FR-13-15).
class GapPrefill {
  /// Creates a prefill.
  const GapPrefill({
    required this.accountId,
    required this.amountMinor,
    required this.outgoing,
    required this.time,
    required this.fromTime,
    required this.toTime,
    required this.choices,
    required this.choice,
    this.fromAccountId,
    this.toAccountId,
  });

  /// [last] is the user's previous choice for this account, used if valid.
  factory GapPrefill.of(UntrackedGap g, {GapChoice? last}) {
    final out = g.moneyLeft;
    final choices = out && g.card
        ? [GapChoice.payment]
        : out
            ? [GapChoice.payment, GapChoice.transfer]
            : [GapChoice.received, GapChoice.transfer];
    final dflt = g.card && !out ? GapChoice.transfer : choices.first;
    final t = g.toTime - 60000;
    return GapPrefill(
      accountId: g.accountId,
      amountMinor: g.deltaMinor.abs(),
      outgoing: out,
      time: t > g.fromTime ? t : g.toTime,
      fromTime: g.fromTime,
      toTime: g.toTime,
      choices: choices,
      choice: last != null && choices.contains(last) ? last : dflt,
      fromAccountId: out ? g.accountId : null,
      toAccountId: out ? null : g.accountId,
    );
  }

  final int accountId;
  final int amountMinor;
  final bool outgoing;

  /// A moment inside the window: the stating message's, minus a minute.
  final int time;
  final int fromTime;
  final int toTime;
  final List<GapChoice> choices;
  final GapChoice choice;
  final int? fromAccountId;
  final int? toAccountId;
}

/// Account-less rows that may be the missing money.
abstract final class GapCandidates {
  static const _maxRows = 14;

  /// Up to three suggestions: one row of the amount, else two or three rows
  /// adding up to it within 100 paise.
  static List<List<LedgerTx>> find(UntrackedGap g, List<LedgerTx> rows) {
    final want = g.deltaMinor.abs();
    final pool = rows
        .where(
          (t) =>
              t.accountId == null &&
              !t.needsReview &&
              t.duplicateOfId == null &&
              t.currency == 'INR' &&
              t.timestamp > g.fromTime &&
              t.timestamp <= g.toTime &&
              switch (t.type) {
                TransactionType.credit => !g.moneyLeft,
                TransactionType.debit ||
                TransactionType.investment =>
                  g.moneyLeft,
                TransactionType.transfer => false,
              },
        )
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final p = pool.take(_maxRows).toList();
    bool hit(int sum) => (sum - want).abs() < BalanceGaps.minGapMinor;
    final found = <List<LedgerTx>>[
      for (final t in p)
        if (hit(t.amountMinor)) [t],
      for (var i = 0; i < p.length; i++)
        for (var j = i + 1; j < p.length; j++)
          if (hit(p[i].amountMinor + p[j].amountMinor)) [p[i], p[j]],
      for (var i = 0; i < p.length; i++)
        for (var j = i + 1; j < p.length; j++)
          for (var k = j + 1; k < p.length; k++)
            if (hit(p[i].amountMinor + p[j].amountMinor + p[k].amountMinor))
              [p[i], p[j], p[k]],
    ];
    return found.take(3).toList();
  }
}

/// One untracked-change notification for the alerts engine (FR-13-16).
class GapAlert {
  /// Creates an alert.
  const GapAlert({
    required this.key,
    required this.accountId,
    required this.title,
    required this.body,
  });

  /// `gap:<gap key>`; store it once posted.
  final String key;
  final int accountId;
  final String title;
  final String body;
}

/// Pure alert rule: at most [maxPerRun] gaps, each once, only gaps whose
/// `toTime` is within [windowDays] (FR-13-16). [notified] holds posted keys;
/// [labelOf] and [format] come from the caller (amount formatting).
List<GapAlert> gapAlerts({
  required List<UntrackedGap> gaps,
  required Set<String> notified,
  required int now,
  required String Function(int accountId) labelOf,
  required String Function(int minor) format,
  int maxPerRun = 3,
  int windowDays = 14,
}) {
  final out = <GapAlert>[];
  for (final g in gaps) {
    if (out.length >= maxPerRun) break;
    if (now - g.toTime > windowDays * 24 * 60 * 60 * 1000) continue;
    final key = 'gap:${g.key}';
    if (notified.contains(key)) continue;
    final amt = format(g.deltaMinor.abs());
    final what = g.card
        ? (g.moneyLeft
            ? '$amt of limit used with no message'
            : '$amt of limit freed with no message')
        : (g.moneyLeft
            ? '$amt left the account with no message'
            : '$amt came in with no message');
    out.add(
      GapAlert(
        key: key,
        accountId: g.accountId,
        title: 'Untracked change',
        body: '${labelOf(g.accountId)}: $what. Add it?',
      ),
    );
  }
  return out;
}
