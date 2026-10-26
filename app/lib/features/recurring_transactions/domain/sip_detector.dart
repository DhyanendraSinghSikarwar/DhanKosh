import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/recurring_transactions/domain/sip.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

/// SIP detection and schedule maths (FR-12-17..20). Pure. Weekly, monthly
/// and quarterly series are told apart by the median gap between
/// instalments; `today` is an IST date as UTC midnight.
abstract final class SipDetector {
  /// Amounts within this share of the median belong to one series.
  static const amountTolerance = 5; // 1/5 = 20%

  /// Instalment events from INVESTMENT ledger rows (FR-12-18).
  static List<SipEvent> eventsFromLedger(List<LedgerTx> txs) => [
        for (final t in txs)
          if (t.type == TransactionType.investment &&
              !t.needsReview &&
              t.duplicateOfId == null &&
              t.currency == 'INR' &&
              (t.merchant ?? t.upiId) != null)
            SipEvent(
              name: (t.merchant ?? t.upiId)!.trim(),
              atMs: t.timestamp,
              amountMinor: t.amountMinor,
            ),
      ];

  static String _key(String name) =>
      name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  /// Key two names share when they are the same fund.
  static String keyOf(String name) => _key(name);

  static int _median(List<int> xs) {
    final s = [...xs]..sort();
    return s[s.length ~/ 2];
  }

  /// Adds [months] to [from], keeping day [dom] clamped to the month length.
  static DateTime addMonths(DateTime from, int months, int dom) {
    final idx = from.year * 12 + from.month - 1 + months;
    final y = idx ~/ 12;
    final m = idx % 12 + 1;
    final len = Ist.lengthOfMonth(y, m);
    return DateTime.utc(y, m, dom < len ? dom : len);
  }

  static SipFrequency? _frequency(int gap, int count) {
    if (gap >= 5 && gap <= 9 && count >= 3) return SipFrequency.weekly;
    if (gap >= 26 && gap <= 35) return SipFrequency.monthly;
    if (gap >= 80 && gap <= 100) return SipFrequency.quarterly;
    return null;
  }

  static int _recencyDays(SipFrequency f) => switch (f) {
        SipFrequency.daily => 3,
        SipFrequency.weekly => 14,
        SipFrequency.monthly => 45,
        SipFrequency.quarterly => 135,
      };

  /// FR-12-17, FR-12-18: SIPs found in [events], sorted by next date.
  static List<Sip> detect(List<SipEvent> events, DateTime today) {
    // One instalment per fund, day and amount (a ledger row and the order
    // for the same purchase count once).
    final seen = <String>{};
    final groups = <String, List<SipEvent>>{};
    for (final e in events) {
      final k = _key(e.name);
      if (k.length < 3 || e.amountMinor <= 0) continue;
      final id = '$k|${Ist.dayOf(e.atMs)}|${e.amountMinor}';
      if (seen.add(id)) (groups[k] ??= []).add(e);
    }
    final out = <Sip>[];
    for (final g in groups.values) {
      final median = _median(g.map((e) => e.amountMinor).toList());
      final similar = g
          .where(
            (e) => (e.amountMinor - median).abs() <= median ~/ amountTolerance,
          )
          .toList()
        ..sort((a, b) => a.atMs.compareTo(b.atMs));
      if (similar.length < 2) continue;
      final days = [for (final e in similar) Ist.dayOf(e.atMs)];
      final gaps = [
        for (var i = 1; i < days.length; i++) days[i] - days[i - 1],
      ]..removeWhere((d) => d == 0);
      if (gaps.isEmpty) continue;
      final freq = _frequency(_median(gaps), similar.length);
      if (freq == null) continue;
      final last = Ist.dateOf(similar.last.atMs);
      if (last.isBefore(today.subtract(Duration(days: _recencyDays(freq))))) {
        continue;
      }
      final doms = [for (final e in similar) Ist.dateOf(e.atMs).day];
      final dom = _median(doms);
      final next = switch (freq) {
        SipFrequency.weekly => last.add(const Duration(days: 7)),
        SipFrequency.quarterly => addMonths(last, 3, dom),
        _ => addMonths(last, 1, dom),
      };
      out.add(
        Sip(
          name: similar.last.name,
          amountMinor: similar.last.amountMinor,
          frequency: freq,
          nextDate: next,
          totalInvestedMinor: g.fold(0, (s, e) => s + e.amountMinor),
          instalments: g.length,
          lastDate: last,
          dayOfMonth: freq == SipFrequency.weekly ? null : dom,
        ),
      );
    }
    return out..sort((a, b) => a.nextDate.compareTo(b.nextDate));
  }

  static DateTime _date(int epochDay) =>
      DateTime.utc(1970).add(Duration(days: epochDay));

  /// Next instalment of a user SIP on or after [today] (FR-12-19).
  static DateTime nextDateOf(SipItem s, DateTime today) {
    final start = _date(s.startDay);
    final from = start.isAfter(today) ? start : today;
    switch (s.frequency) {
      case SipFrequency.daily:
        return from;
      case SipFrequency.weekly:
        final wd = s.weekday ?? start.weekday;
        return from.add(Duration(days: (wd - from.weekday) % 7));
      case SipFrequency.monthly:
      case SipFrequency.quarterly:
        final dom = s.dayOfMonth ?? start.day;
        final here = addMonths(DateTime.utc(from.year, from.month), 0, dom);
        return here.isBefore(from) ? addMonths(here, 1, dom) : here;
    }
  }

  /// Instalments of a user SIP due from its start through [today].
  static int instalmentsUntil(SipItem s, DateTime today) {
    final start = _date(s.startDay);
    if (start.isAfter(today)) return 0;
    switch (s.frequency) {
      case SipFrequency.daily:
        return today.difference(start).inDays + 1;
      case SipFrequency.weekly:
        final wd = s.weekday ?? start.weekday;
        final first = start.add(Duration(days: (wd - start.weekday) % 7));
        return first.isAfter(today)
            ? 0
            : today.difference(first).inDays ~/ 7 + 1;
      case SipFrequency.monthly:
      case SipFrequency.quarterly:
        final dom = s.dayOfMonth ?? start.day;
        var d = addMonths(DateTime.utc(start.year, start.month), 0, dom);
        if (d.isBefore(start)) d = addMonths(d, 1, dom);
        var n = 0;
        while (!d.isAfter(today)) {
          n++;
          d = addMonths(d, 1, dom);
        }
        return n;
    }
  }

  /// FR-12-19: user SIPs replace detected ones of the same fund; sorted by
  /// next date. A user SIP's total is the detected total when records
  /// exist, else amount times instalments due.
  static List<Sip> withManual(
    List<Sip> detected,
    List<SipItem> manual,
    DateTime today,
  ) {
    final byKey = {for (final d in detected) _key(d.name): d};
    final mine = [
      for (final m in manual)
        () {
          final rec = byKey[_key(m.name)];
          final n = instalmentsUntil(m, today);
          return Sip(
            name: m.name,
            amountMinor: m.amountMinor,
            frequency: m.frequency,
            nextDate: nextDateOf(m, today),
            totalInvestedMinor: rec?.totalInvestedMinor ?? n * m.amountMinor,
            instalments: rec?.instalments ?? n,
            lastDate: rec?.lastDate,
            manualId: m.id,
            dayOfMonth: m.dayOfMonth,
            weekday: m.weekday,
            startDay: m.startDay,
          );
        }(),
    ];
    final names = {for (final r in mine) _key(r.name)};
    return [
      ...mine,
      ...detected.where((d) => !names.contains(_key(d.name))),
    ]..sort((a, b) => a.nextDate.compareTo(b.nextDate));
  }
}
