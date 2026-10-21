/// SQL for the `inrMinor` maintenance triggers and bulk recompute (FR-23-04..06).
///
/// Schema-level: these are not part of Drift's generated schema, so they are
/// created in `onCreate`, `onUpgrade` and `beforeOpen` with `IF NOT EXISTS`.
abstract final class ForexSql {
  /// `inrMinor` for the row [r] (`NEW` in triggers, `transactions` in recompute).
  /// Nearest rate day wins, earlier day on a tie (FR-23-10); NULL without a rate.
  static String inr(String r) => '''
CASE WHEN $r.currency = 'INR' THEN $r.amount_minor ELSE
 (SELECT CAST(ROUND($r.amount_minor * fr.inr_per_unit * (1 + COALESCE((SELECT a.forex_markup_bps FROM accounts a WHERE a.id = $r.account_id), 0) / 10000.0)) AS INTEGER)
  FROM forex_rates fr WHERE fr.currency = $r.currency
  ORDER BY ABS(fr.day - (($r.timestamp + 19800000) / 86400000)), fr.day LIMIT 1)
END''';

  /// Trigger statements (idempotent).
  static final List<String> triggers = [
    '''
CREATE TRIGGER IF NOT EXISTS transactions_inr_insert AFTER INSERT ON transactions
BEGIN UPDATE transactions SET inr_minor = ${inr('NEW')} WHERE id = NEW.id; END''',
    '''
CREATE TRIGGER IF NOT EXISTS transactions_inr_update
AFTER UPDATE OF amount_minor, currency, account_id, timestamp ON transactions
BEGIN UPDATE transactions SET inr_minor = ${inr('NEW')} WHERE id = NEW.id; END''',
  ];

  /// Recompute every non-INR row (after a rate or markup change).
  static final String recompute =
      "UPDATE transactions SET inr_minor = ${inr('transactions')} "
      "WHERE currency != 'INR'";
}
