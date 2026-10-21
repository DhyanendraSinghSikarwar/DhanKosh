import 'package:hisaab/features/forex_rates/domain/forex_rate.dart';

/// Optional port for an automatic rate feed. Memory 23 section 6 and
/// open question 8 specify user-entered rates only (no network), so no
/// implementation ships; a future one must be approved first.
abstract interface class ForexRatesSource {
  /// Latest rates for [currencies]; empty on any failure.
  Future<List<ForexRate>> fetchLatest(Set<String> currencies);
}
