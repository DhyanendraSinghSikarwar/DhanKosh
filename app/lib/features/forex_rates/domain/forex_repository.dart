import 'package:hisaab/features/forex_rates/domain/forex_rate.dart';

/// User forex rates and the unpriced summary (F-23).
abstract interface class ForexRepository {
  /// Rates ordered by currency, day DESC (FR-23-02).
  Stream<List<ForexRate>> watchRates();

  /// Current rates, same order.
  Future<List<ForexRate>> rates();

  /// The rate [currency] would use for [day] (nearest, earlier on a tie).
  Future<ForexRate?> rateFor(String currency, int day);

  /// Latest-day rate of [currency], or null.
  Future<ForexRate?> latest(String currency);

  /// Saves (replaces) the rate and recomputes `inrMinor` (FR-23-01,
  /// FR-23-06). Currency is upper-cased; throws [ArgumentError] unless 3
  /// letters and the rate is > 0.
  Future<void> upsert(ForexRate rate);

  /// Deletes the rate and recomputes (FR-23-13).
  Future<void> delete(String currency, int day);

  /// Recomputes `inrMinor` of all non-INR rows (FR-23-06), e.g. after a
  /// card markup change.
  Future<void> recompute();

  /// Foreign spend counts, count DESC (FR-23-09).
  Stream<List<CurrencyCount>> watchForeign();
}
