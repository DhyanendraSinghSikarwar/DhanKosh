import 'package:hisaab/features/credit_cards/domain/card_due_repository.dart';
import 'package:hisaab/features/credit_cards/domain/card_matcher.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';

/// User actions on a card (FR-14-07..09). Stores state only; nothing here
/// writes the ledger.
class CardDueActions {
  /// Creates the actions. [now] is epoch ms.
  CardDueActions({
    required CardDueRepository dues,
    required CardPaidStore paid,
    int Function()? now,
  })  : _dues = dues,
        _paid = paid,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final CardDueRepository _dues;
  final CardPaidStore _paid;
  final int Function() _now;

  /// Mark paid: silences reminders for this card and due date and clears its
  /// overrides (FR-14-09). No-op without a due date.
  Future<void> markPaid(CardLimit card) async {
    final due = card.dueDay;
    if (due == null) return;
    await _paid.markPaid(card.id, due);
    await _dues.clearOverride(CardMatcher.cardKey(card.bankName, card.last4));
  }

  /// Undo of [markPaid] (the cleared overrides stay cleared).
  Future<void> undoPaid(CardLimit card) async {
    final due = card.dueDay;
    if (due != null) await _paid.undoPaid(card.id, due);
  }

  /// Saves an edit (FR-14-07). A value equal to the [calculated] one is not
  /// stored; with nothing left the override is cleared.
  Future<void> saveEdit(
    CardLimit card, {
    required CardPosition calculated,
    int? billedMinor,
    int? minDueMinor,
    int? dueEpochDay,
    int? unbilledMinor,
    int? outstandingMinor,
  }) async {
    final key = CardMatcher.cardKey(card.bankName, card.last4);
    final o = CardOverride(
      cardKey: key,
      setAt: _now(),
      billedMinor: _keep(billedMinor, calculated.billedMinor),
      minDueMinor: _keep(minDueMinor, calculated.minDueMinor),
      dueEpochDay: _keep(dueEpochDay, calculated.dueDay),
      unbilledMinor: _keep(unbilledMinor, calculated.unbilledMinor),
      outstandingMinor: _keep(outstandingMinor, calculated.outstandingMinor),
    );
    if (o.isEmpty) {
      await _dues.clearOverride(key);
    } else {
      await _dues.saveOverride(o);
    }
  }

  /// Reset all to calculated.
  Future<void> resetAll(CardLimit card) =>
      _dues.clearOverride(CardMatcher.cardKey(card.bankName, card.last4));

  static int? _keep(int? v, int? calc) => v == calc ? null : v;
}
