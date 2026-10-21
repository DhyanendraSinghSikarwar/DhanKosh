import 'package:hisaab/features/forex_rates/domain/forex_rate.dart';

/// Pure converter mirroring the SQL triggers (FR-23-04, FR-23-10, FR-23-11).
///
/// INR returns [amountMinor]; null when [ratesForCurrency] is empty. The
/// nearest rate day wins, the earlier day on a tie; the result is rounded
/// half away from zero.
int? inrMinorFor({
  required int amountMinor,
  required String currency,
  required int timestampMs,
  required int? markupBps,
  required List<ForexRate> ratesForCurrency,
}) {
  if (currency == 'INR') return amountMinor;
  if (ratesForCurrency.isEmpty) return null;
  final day = (timestampMs + 19800000) ~/ 86400000;
  var best = ratesForCurrency.first;
  for (final r in ratesForCurrency.skip(1)) {
    final d = (r.day - day).abs();
    final bd = (best.day - day).abs();
    if (d < bd || (d == bd && r.day < best.day)) best = r;
  }
  return (amountMinor * best.inrPerUnit * (1 + (markupBps ?? 0) / 10000.0))
      .round();
}
