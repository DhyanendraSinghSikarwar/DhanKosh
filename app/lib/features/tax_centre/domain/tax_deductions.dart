import 'package:hisaab/features/tax_centre/domain/tax_income.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// One source of a deduction (the memory `TaxItem`).
class TaxItem {
  const TaxItem(this.label, this.amountMinor);

  final String label;
  final int amountMinor;
}

/// An EPF holding's two passbook figures (FR-19-05). Times are epoch ms.
class EpfHolding {
  const EpfHolding({
    this.valueMinor,
    this.previousValueMinor,
    this.asOf,
    this.previousAsOf,
  });

  final int? valueMinor;
  final int? previousValueMinor;
  final int? asOf;
  final int? previousAsOf;
}

enum InsuranceKind { health, life, motor, other }

class DetectedDeductions {
  const DetectedDeductions({
    this.items80C = const [],
    this.items80D = const [],
    this.npsDetected = 0,
    this.otherInvested = 0,
  });

  final List<TaxItem> items80C;
  final List<TaxItem> items80D;
  final int npsDetected;
  final int otherInvested;

  int get c80Calc => items80C.fold(0, (a, e) => a + e.amountMinor);
  int get d80Calc => items80D.fold(0, (a, e) => a + e.amountMinor);
}

/// Deduction detection from ledger rows (FR-19-05, FR-19-06), ported from
/// Kotlin `TaxSource`. Open question (memory 19 #10): `QUALIFIES_80C` misses
/// ELSS funds named without "elss"/"tax saver".
abstract final class TaxDeductionDetector {
  static final _qualifies80C = RegExp(
    r'elss|tax\s?saver|tax\s?saving|\bppf\b|public provident|sukanya|\bssy\b|\bnsc\b|national savings',
    caseSensitive: false,
  );
  static final _nps = RegExp(r'\bnps\b|national pension', caseSensitive: false);
  static final _ppf = RegExp(r'\bppf\b|public provident', caseSensitive: false);
  static final _ssy = RegExp(r'sukanya|\bssy\b', caseSensitive: false);
  static final _nsc = RegExp(r'\bnsc\b|national savings', caseSensitive: false);
  static final _health = RegExp(
    r'health|mediclaim|star\s|niva|bupa|care\s|cigna|aditya birla health',
    caseSensitive: false,
  );
  static final _life = RegExp(
    r'\blife\b|term|\blic\b|pru|aia|max life',
    caseSensitive: false,
  );
  static final _motor = RegExp(
    r'motor|car\b|bike|two.?wheeler|vehicle|\bauto\b',
    caseSensitive: false,
  );

  /// `Planning.kindOf`: first match wins (health, life, motor, other).
  static InsuranceKind kindOf(String text) {
    if (_health.hasMatch(text)) return InsuranceKind.health;
    if (_life.hasMatch(text)) return InsuranceKind.life;
    if (_motor.hasMatch(text)) return InsuranceKind.motor;
    return InsuranceKind.other;
  }

  static String label80C(String text) {
    if (_ppf.hasMatch(text)) return 'PPF deposits';
    if (_ssy.hasMatch(text)) return 'Sukanya Samriddhi';
    if (_nsc.hasMatch(text)) return 'NSC';
    return 'ELSS tax-saver funds';
  }

  /// Employee share of EPF passbook growth inside [fromMs]..[toMs]
  /// (x 12 / 15.67, truncated); 0 without two usable figures.
  static int epfShare(EpfHolding h, int fromMs, int toMs) {
    final now = h.valueMinor;
    final before = h.previousValueMinor;
    final at = h.asOf;
    final prevAt = h.previousAsOf;
    if (now == null || before == null || at == null || prevAt == null) return 0;
    if (now <= before || at <= prevAt || at < fromMs) return 0;
    final hi = at < toMs ? at : toMs;
    final lo = prevAt > fromMs ? prevAt : fromMs;
    final overlap = hi - lo < 0 ? 0 : hi - lo;
    final share = (now - before) * overlap / (at - prevAt);
    return (share * 12 / 15.67).truncate();
  }

  /// [txs] are all rows; those in [fromMs]..[toMs] (inclusive), not under
  /// review, are scanned.
  static DetectedDeductions detect(
    List<LedgerTx> txs,
    int fromMs,
    int toMs, {
    List<EpfHolding> epf = const [],
  }) {
    final rows = txs
        .where(
          (t) => !t.needsReview && t.timestamp >= fromMs && t.timestamp <= toMs,
        )
        .toList();
    final invest =
        rows.where((t) => t.type == TransactionType.investment).toList();
    final nps = invest.where((t) => _nps.hasMatch(TaxIncome.text(t))).toList();
    final qualifying =
        invest.where((t) => _qualifies80C.hasMatch(TaxIncome.text(t))).toList();
    final premiums = rows
        .where(
          (t) =>
              t.category == Category.insurance &&
              t.type != TransactionType.credit &&
              t.type != TransactionType.transfer,
        )
        .toList();
    int sum(Iterable<LedgerTx> l) =>
        l.fold(0, (a, t) => a + TaxIncome.paise(t));
    final life = premiums
        .where((t) => kindOf(TaxIncome.text(t)) == InsuranceKind.life)
        .toList();
    final health = premiums
        .where((t) => kindOf(TaxIncome.text(t)) == InsuranceKind.health)
        .toList();

    final grouped = <String, int>{};
    for (final t in qualifying) {
      final l = label80C(TaxIncome.text(t));
      grouped[l] = (grouped[l] ?? 0) + TaxIncome.paise(t);
    }
    final items80C = <TaxItem>[
      for (final e in grouped.entries) TaxItem(e.key, e.value),
      if (life.isNotEmpty) TaxItem('Life insurance premiums', sum(life)),
    ];
    final epfTotal = epf.fold(0, (a, h) => a + epfShare(h, fromMs, toMs));
    if (epfTotal > 0)
      items80C.add(TaxItem('EPF, your share (estimated)', epfTotal));
    final healthSum = sum(health);
    final used = {...qualifying.map((t) => t.id), ...nps.map((t) => t.id)};
    return DetectedDeductions(
      items80C: items80C.where((i) => i.amountMinor > 0).toList(),
      items80D: healthSum > 0
          ? [TaxItem('Health insurance premiums', healthSum)]
          : [],
      npsDetected: sum(nps),
      otherInvested: sum(invest.where((t) => !used.contains(t.id))),
    );
  }
}
