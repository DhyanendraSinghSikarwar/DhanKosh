import 'package:hisaab/features/statement_import/domain/statement.dart';

/// What a statement did to the account balance or card limit (FR-05-07).
enum AccountEffectKind { none, availableLimit, closingBalance }

/// Account figure set by a statement; never a transaction.
class AccountEffect {
  /// Creates an effect.
  const AccountEffect({
    this.kind = AccountEffectKind.none,
    this.amountMinor,
    this.bankName,
    this.last4,
  });

  /// Nothing applied.
  static const none = AccountEffect();

  final AccountEffectKind kind;
  final int? amountMinor;
  final String? bankName;
  final String? last4;

  /// A figure was applied.
  bool get applied => kind != AccountEffectKind.none;

  Map<String, Object?> toJson() => {
        'k': kind.name,
        'a': amountMinor,
        'b': bankName,
        'l': last4,
      };

  /// Reads [toJson].
  static AccountEffect fromJson(Map<String, Object?> j) => AccountEffect(
        kind: AccountEffectKind.values.asNameMap()[j['k']] ??
            AccountEffectKind.none,
        amountMinor: j['a'] as int?,
        bankName: j['b'] as String?,
        last4: j['l'] as String?,
      );
}

/// Holdings rows differ from the statement's stated totals (FR-05-18).
class HoldingsMismatch {
  /// Creates a mismatch.
  const HoldingsMismatch({
    this.statedValueMinor,
    this.rowsValueMinor,
    this.statedInvestedMinor,
    this.rowsInvestedMinor,
  });

  final int? statedValueMinor;
  final int? rowsValueMinor;
  final int? statedInvestedMinor;
  final int? rowsInvestedMinor;

  Map<String, Object?> toJson() => {
        'sv': statedValueMinor,
        'rv': rowsValueMinor,
        'si': statedInvestedMinor,
        'ri': rowsInvestedMinor,
      };

  /// Reads [toJson].
  static HoldingsMismatch fromJson(Map<String, Object?> j) => HoldingsMismatch(
        statedValueMinor: j['sv'] as int?,
        rowsValueMinor: j['rv'] as int?,
        statedInvestedMinor: j['si'] as int?,
        rowsInvestedMinor: j['ri'] as int?,
      );
}

/// What one import did, kept for the detail screen (FR-05-20).
class StatementOutcome {
  /// Creates an outcome.
  const StatementOutcome({
    this.added = 0,
    this.merged = 0,
    this.review = 0,
    this.holdingsUpdated = 0,
    this.depositsUpdated = 0,
    this.effect = AccountEffect.none,
    this.mismatch,
  });

  final int added;
  final int merged;
  final int review;
  final int holdingsUpdated;
  final int depositsUpdated;
  final AccountEffect effect;
  final HoldingsMismatch? mismatch;

  Map<String, Object?> toJson() => {
        'ad': added,
        'me': merged,
        're': review,
        'ho': holdingsUpdated,
        'de': depositsUpdated,
        'ef': effect.toJson(),
        'mm': mismatch?.toJson(),
      };

  /// Reads [toJson].
  static StatementOutcome fromJson(Map<String, Object?> j) => StatementOutcome(
        added: j['ad'] as int? ?? 0,
        merged: j['me'] as int? ?? 0,
        review: j['re'] as int? ?? 0,
        holdingsUpdated: j['ho'] as int? ?? 0,
        depositsUpdated: j['de'] as int? ?? 0,
        effect: j['ef'] is Map
            ? AccountEffect.fromJson((j['ef']! as Map).cast())
            : AccountEffect.none,
        mismatch: j['mm'] is Map
            ? HoldingsMismatch.fromJson((j['mm']! as Map).cast())
            : null,
      );
}

/// Keeps the [StatementOutcome] of each statement.
abstract interface class StatementOutcomeStore {
  /// Stores [o] for statement [id].
  Future<void> save(int id, StatementOutcome o);

  /// Outcome of [id], or null.
  Future<StatementOutcome?> read(int id);

  /// Forgets [id].
  Future<void> delete(int id);
}

/// Tells the user a statement needs its password (FR-05-11).
abstract interface class StatementLockedNotifier {
  /// Posts the "password protected" notice for statement [id].
  Future<void> notify(int id, {String? bank});
}

/// A statement with what its import did (FR-05-20).
class StatementDetail {
  /// Creates the detail.
  const StatementDetail(this.statement, this.outcome);

  /// Stored row.
  final Statement statement;

  /// What the import did; null for rows imported before it was kept.
  final StatementOutcome? outcome;
}
