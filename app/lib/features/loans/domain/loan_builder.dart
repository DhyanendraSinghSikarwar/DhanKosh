import 'package:hisaab/features/analytics/domain/civil_date.dart';
import 'package:hisaab/features/loans/domain/amortization.dart';
import 'package:hisaab/features/loans/domain/loan_models.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// Builds loans from loan accounts and EMI payments (FR-15-01..04, 12, 14).
/// Pure port of Kotlin `Loans`. Dates bucket at [offset] (default IST).
abstract final class Loans {
  /// Detected EMI series need payments within this many days (FR-15-03).
  static const recencyDays = 75;

  /// Same-amount payments this close count once.
  static const distinctDays = 3;

  /// The merchant key a detected EMI series is grouped by (length >= 2).
  static String? keyOf(LedgerTx t) {
    final k = (t.merchant ?? t.upiId)?.trim().toLowerCase();
    return (k != null && k.length >= 2) ? k : null;
  }

  /// A debit that may be a loan payment (FR-15-14).
  static bool isPayment(LedgerTx t) =>
      !t.needsReview &&
      t.type != TransactionType.credit &&
      t.currency == 'INR' &&
      t.category != Category.investment &&
      t.customCategoryId == null;

  /// Loan accounts (not hidden) plus detected EMI series not claimed by an
  /// account. [accounts] are loan accounts; [merged] every account that has a
  /// `mergedIntoId`. Payee keys in [dismissed] are skipped (FR-15-11).
  static List<Loan> build({
    required List<LoanAccount> accounts,
    required List<LedgerTx> payments,
    required DateTime today,
    Set<String> dismissed = const {},
    LoanLinks links = LoanLinks.none,
    List<LoanAccount> merged = const [],
    Duration offset = istOffset,
  }) {
    final loanAccs = accounts.where((a) => !a.hidden).toList();
    final pays = payments.where(isPayment).toList();
    final parent = <int, int>{
      for (final m in merged)
        if (m.mergedIntoId != null) m.id: m.mergedIntoId!,
    };
    int root(int id) {
      var x = id;
      for (var i = 0; i < 8; i++) {
        final p = parent[x];
        if (p == null) return x;
        x = p;
      }
      return x;
    }

    final kids = <int, List<LoanAccount>>{
      for (final a in loanAccs)
        a.id: [
          for (final m in merged)
            if (m.id != a.id && root(m.id) == a.id) m,
        ],
    };
    final accIds = {for (final a in loanAccs) a.id};
    final loanIds = {
      ...accIds,
      for (final k in kids.values) ...k.map((e) => e.id),
    };
    int? linked(LedgerTx t) {
      final k = keyOf(t);
      final direct = links.tx[t.id] ?? (k == null ? null : links.payee[k]);
      if (direct == null) return null;
      final r = root(direct);
      return accIds.contains(r) ? r : null;
    }

    final claimed = <int>{};
    final loans = <Loan>[];
    for (final a in loanAccs) {
      final children = kids[a.id] ?? const <LoanAccount>[];
      final mine = pays.where((t) {
        final own =
            t.accountId == a.id || children.any((c) => c.id == t.accountId);
        if (own) return true;
        if (t.category != Category.emiLoan || loanIds.contains(t.accountId)) {
          return false;
        }
        final l = linked(t);
        return l == a.id || (l == null && _names(t, a, children));
      }).toList();
      claimed.addAll(mine.map((e) => e.id));
      final terms = termsOf(a) ??
          children.map(termsOf).whereType<LoanTerms>().firstOrNull;
      final withBal =
          children.where((c) => c.latestBalanceMinor != null).toList();
      int? childBal;
      if (withBal.isNotEmpty) {
        var best = withBal.first;
        for (final c in withBal.skip(1)) {
          if ((c.balanceUpdatedAt ?? 0) > (best.balanceUpdatedAt ?? 0))
            best = c;
        }
        childBal = best.latestBalanceMinor;
      }
      final bal = a.currentBalanceMinor ?? childBal;
      final nick = a.nickname;
      loans.add(
        _summarise(
          key: 'acct:${a.id}',
          accountId: a.id,
          name: (nick != null && nick.trim().isNotEmpty) ? nick : a.bankName,
          bank: a.bankName,
          last4: a.last4,
          txs: mine,
          terms: terms,
          bankOutstanding: bal?.abs(),
          today: today,
          loanIds: loanIds,
          offset: offset,
          mergedIds: [for (final c in children) c.id],
        ),
      );
    }

    final groups = <String, List<LedgerTx>>{};
    for (final t in pays) {
      if (t.category != Category.emiLoan ||
          claimed.contains(t.id) ||
          loanIds.contains(t.accountId)) {
        continue;
      }
      final k = keyOf(t);
      if (k == null || dismissed.contains(k)) continue;
      groups.putIfAbsent(k, () => []).add(t);
    }
    final detected = <Loan>[];
    for (final e in groups.entries) {
      final k = e.key;
      final group = e.value;
      final months = {
        for (final t in group)
          dayOf(t.timestamp, offset: offset).year * 12 +
              dayOf(t.timestamp, offset: offset).month,
      };
      var last = dayOf(group.first.timestamp, offset: offset);
      for (final t in group) {
        final d = dayOf(t.timestamp, offset: offset);
        if (d.isAfter(last)) last = d;
      }
      if ((months.length < 2 && !links.manualPayees.contains(k)) ||
          last.isBefore(today.subtract(const Duration(days: recencyDays)))) {
        continue;
      }
      var newest = group.first;
      for (final t in group) {
        if (t.timestamp >= newest.timestamp) newest = t;
      }
      final name = newest.merchant ?? newest.upiId ?? 'EMI';
      detected.add(
        _summarise(
          key: 'payee:$k',
          accountId: null,
          name: name,
          bank: name,
          last4: null,
          txs: group,
          terms: null,
          bankOutstanding: null,
          today: today,
          loanIds: const {},
          offset: offset,
        ),
      );
    }
    return [
      ...stableSorted<Loan>(
        loans,
        (a, b) => (b.outstandingMinor ?? 0).compareTo(a.outstandingMinor ?? 0),
      ),
      ...stableSorted<Loan>(detected, (a, b) {
        final x = a.nextDue;
        final y = b.nextDue;
        if (x == null && y == null) return 0;
        if (x == null) return -1;
        if (y == null) return 1;
        return x.compareTo(y);
      }),
    ];
  }

  static bool _names(LedgerTx t, LoanAccount a, List<LoanAccount> kids) {
    final text = [t.merchant, t.upiId, t.note]
        .whereType<String>()
        .join(' ')
        .toLowerCase();
    if (text.trim().isEmpty) return false;
    final last4s = [a.last4, ...kids.map((e) => e.last4)];
    if (last4s.any((l) => l.length >= 4 && text.contains(l))) return true;
    final names = [
      a.nickname,
      a.bankName,
      for (final k in kids) ...[k.nickname, k.bankName],
    ].whereType<String>();
    return names.any((n) => _sameName(t.merchant, n));
  }

  static bool _sameName(String? merchant, String name) {
    final m = merchant?.trim().toLowerCase() ?? '';
    final n = name.trim().toLowerCase();
    if (m.isEmpty || n.isEmpty) return false;
    if (m == n) return true;
    final shorter = m.length < n.length ? m.length : n.length;
    return shorter >= 5 && (m.startsWith('$n ') || n.startsWith('$m '));
  }

  /// Likely duplicate loan accounts; `into` is the one with terms, then more
  /// payments (FR-15-12). [ignored] holds `LoanDuplicate.key`s.
  static List<LoanDuplicate> duplicates(
    List<Loan> loans, {
    Set<String> ignored = const {},
  }) {
    final accs = loans.where((l) => l.accountId != null).toList();
    final out = <LoanDuplicate>[];
    final used = <int>{};
    for (var i = 0; i < accs.length; i++) {
      for (var j = i + 1; j < accs.length; j++) {
        final a = accs[i];
        final b = accs[j];
        if (used.contains(a.accountId) || used.contains(b.accountId)) continue;
        if (!_similar(a, b)) continue;
        var c =
            ((a.terms != null) ? 1 : 0).compareTo((b.terms != null) ? 1 : 0);
        if (c == 0) c = a.payments.length.compareTo(b.payments.length);
        final aInto = c >= 0;
        final d = LoanDuplicate(from: aInto ? b : a, into: aInto ? a : b);
        if (ignored.contains(d.key)) continue;
        out.add(d);
        used
          ..add(a.accountId!)
          ..add(b.accountId!);
      }
    }
    return out;
  }

  static bool _similar(Loan a, Loan b) {
    final la = a.last4 ?? '';
    final lb = b.last4 ?? '';
    if (la.length >= 3 && la == lb) return true;
    if (la.isNotEmpty && lb.isNotEmpty && la != lb) return false;
    final na = a.name.trim().toLowerCase();
    final nb = b.name.trim().toLowerCase();
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    final shorter = na.length < nb.length ? na.length : nb.length;
    if (shorter >= 5 && (na.startsWith(nb) || nb.startsWith(na))) return true;
    final ba = a.bankName.trim().toLowerCase();
    return ba.isNotEmpty && ba == b.bankName.trim().toLowerCase();
  }

  /// Terms of an account, or null without a principal and tenure.
  static LoanTerms? termsOf(LoanAccount a) {
    final p = a.principalMinor;
    final n = a.tenureMonths;
    if (p == null || n == null || p <= 0 || n <= 0) return null;
    return LoanTerms(
      principalMinor: p,
      rateBps: a.rateBps ?? 0,
      tenureMonths: n,
      startDay: a.startDay == null ? null : fromEpochDay(a.startDay!),
    );
  }

  /// Add-loan rule (FR-15-06): with a tenure an EMI alone suffices
  /// (principal = EMI x tenure, rate 0). Null when the inputs are invalid.
  static LoanTerms? termsFromForm({
    int? principalMinor,
    int? emiMinor,
    int rateBps = 0,
    int? tenureMonths,
    DateTime? firstEmi,
  }) {
    if (rateBps < 0 || rateBps > 6000) return null;
    if (tenureMonths != null && (tenureMonths < 1 || tenureMonths > 600)) {
      return null;
    }
    if (tenureMonths == null) return null;
    if (principalMinor != null && principalMinor > 0) {
      return LoanTerms(
        principalMinor: principalMinor,
        rateBps: rateBps,
        tenureMonths: tenureMonths,
        startDay: firstEmi,
      );
    }
    if (emiMinor != null && emiMinor > 0) {
      return LoanTerms(
        principalMinor: emiMinor * tenureMonths,
        rateBps: 0,
        tenureMonths: tenureMonths,
        startDay: firstEmi,
      );
    }
    return null;
  }

  /// EMI day validation (FR-15-06).
  static bool validEmiDay(int day) => day >= 1 && day <= 31;

  /// One EMI per month: same-amount copies within 3 days count once.
  static List<LedgerTx> _distinct(List<LedgerTx> txs, Duration offset) {
    final out = <LedgerTx>[];
    for (final t in stableSorted<LedgerTx>(
      txs,
      (a, b) => a.timestamp.compareTo(b.timestamp),
    )) {
      final td = dayOf(t.timestamp, offset: offset);
      final dup = out.any(
        (o) =>
            o.amountMinor == t.amountMinor &&
            daysBetween(dayOf(o.timestamp, offset: offset), td).abs() <=
                distinctDays,
      );
      if (!dup) out.add(t);
    }
    return out;
  }

  /// Summary of one loan from its payments (FR-15-04).
  static Loan summarise({
    required String key,
    required String name,
    required List<LedgerTx> txs,
    required DateTime today,
    int? accountId,
    String? bank,
    String? last4,
    LoanTerms? terms,
    int? bankOutstanding,
    Set<int> loanIds = const {},
    Duration offset = istOffset,
  }) =>
      _summarise(
        key: key,
        accountId: accountId,
        name: name,
        bank: bank ?? name,
        last4: last4,
        txs: txs,
        terms: terms,
        bankOutstanding: bankOutstanding,
        today: today,
        loanIds: loanIds,
        offset: offset,
      );

  static Loan _summarise({
    required String key,
    required int? accountId,
    required String name,
    required String bank,
    required String? last4,
    required List<LedgerTx> txs,
    required LoanTerms? terms,
    required int? bankOutstanding,
    required DateTime today,
    required Set<int> loanIds,
    required Duration offset,
    List<int> mergedIds = const [],
  }) {
    DateTime dateOf(LedgerTx t) => dayOf(t.timestamp, offset: offset);
    final all = _distinct(txs, offset);
    final amounts = all.map((e) => e.amountMinor).toList()..sort();
    final median = amounts.isEmpty ? null : amounts[all.length ~/ 2];
    final series = median == null
        ? <LedgerTx>[]
        : all
            .where((t) => (t.amountMinor - median).abs() <= median ~/ 5)
            .toList();
    final computed = terms == null
        ? null
        : Amortization.emi(
            terms.principalMinor, terms.rateBps, terms.tenureMonths);
    final computedEmi = (computed != null && computed > 0) ? computed : null;
    final emi = series.isEmpty ? computedEmi : series.last.amountMinor;
    final days = series.map((t) => dateOf(t).day).toList()..sort();
    final emiDay =
        days.isEmpty ? terms?.startDay?.day : days[series.length ~/ 2];
    final lastPaid = all.isEmpty ? null : dateOf(all.last);
    final firstPaid = all.isEmpty ? null : dateOf(all.first);

    final schedule = terms == null
        ? const <Instalment>[]
        : Amortization.schedule(terms, emiMinor: emi);
    final start = terms?.startDay;
    final elapsed = start == null
        ? null
        : Amortization.elapsed(start, today, schedule.length);
    final paidCount = elapsed ?? series.length;
    int? scheduledOutstanding;
    if (terms != null && elapsed != null) {
      scheduledOutstanding = elapsed == 0
          ? terms.principalMinor
          : (elapsed - 1 < schedule.length
              ? schedule[elapsed - 1].balanceAfterMinor
              : null);
    }
    final outstanding = bankOutstanding ?? scheduledOutstanding;
    int? remaining;
    if (terms != null && bankOutstanding == null && elapsed != null) {
      remaining = schedule.length - elapsed;
    } else if (outstanding != null && emi != null) {
      remaining = Amortization.remainingEmis(
        outstanding,
        emi,
        terms?.rateBps ?? 0,
      );
    } else if (terms != null) {
      final r = schedule.length - series.length;
      remaining = r < 0 ? 0 : r;
    }

    DateTime? nextDue;
    if (emiDay != null) {
      DateTime on(int y, int m) => clampedDay(y, m, emiDay);
      final thisM = DateTime.utc(today.year, today.month);
      final nextM = addMonths(thisM, 1);
      final paidThisMonth = lastPaid != null &&
          lastPaid.year == today.year &&
          lastPaid.month == today.month;
      final cur = on(today.year, today.month);
      var cand = (!paidThisMonth && !cur.isBefore(today))
          ? cur
          : on(nextM.year, nextM.month);
      if (start != null && start.isAfter(cand)) cand = start;
      if (remaining != 0 && outstanding != 0) nextDue = cand;
    }
    DateTime? payoff;
    if (remaining != null) {
      if (remaining == 0) {
        payoff = lastPaid;
      } else if (nextDue != null) {
        final ym =
            addMonths(DateTime.utc(nextDue.year, nextDue.month), remaining - 1);
        payoff = clampedDay(ym.year, ym.month, emiDay ?? 1);
      }
    }

    final done = schedule.take(elapsed ?? 0).toList();
    var paidSum = 0;
    for (final t in all) {
      paidSum += t.amountMinor;
    }
    var doneSum = 0;
    var doneInterest = 0;
    for (final s in done) {
      doneSum += s.emiMinor;
      doneInterest += s.interestMinor;
    }
    var totalInterest = 0;
    for (final s in schedule) {
      totalInterest += s.interestMinor;
    }
    final newestFirst = stableSorted<LedgerTx>(
      all,
      (a, b) => b.timestamp.compareTo(a.timestamp),
    );
    int? paying;
    for (final t in all) {
      if (t.accountId != null && !loanIds.contains(t.accountId)) {
        paying = t.accountId;
      }
    }
    return Loan(
      key: key,
      accountId: accountId,
      name: name,
      bankName: bank,
      last4: last4,
      emiMinor: emi,
      emiDay: emiDay,
      paidCount: paidCount,
      trackedCount: series.length,
      totalPaidMinor: (elapsed != null && emi != null)
          ? (doneSum > paidSum ? doneSum : paidSum)
          : paidSum,
      firstPaid: firstPaid,
      lastPaid: lastPaid,
      nextDue: nextDue,
      outstandingMinor: outstanding,
      outstandingSource: bankOutstanding != null
          ? OutstandingSource.bank
          : (scheduledOutstanding != null
              ? OutstandingSource.schedule
              : OutstandingSource.none),
      terms: terms,
      totalEmis: terms == null ? null : schedule.length,
      remainingEmis: remaining,
      payoffDate: payoff,
      principalPaidMinor: (terms != null && outstanding != null)
          ? ((terms.principalMinor - outstanding) < 0
              ? 0
              : terms.principalMinor - outstanding)
          : null,
      interestPaidMinor: elapsed != null ? doneInterest : null,
      totalInterestMinor: schedule.isEmpty ? null : totalInterest,
      upcoming: schedule.skip(elapsed ?? 0).take(12).toList(),
      payments: newestFirst,
      payingAccountId: paying,
      mergedIds: mergedIds,
    );
  }
}
