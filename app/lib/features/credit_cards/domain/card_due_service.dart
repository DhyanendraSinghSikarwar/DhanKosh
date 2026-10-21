import 'package:hisaab/core/utils/combine_latest.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/account_repository.dart';
import 'package:hisaab/features/credit_cards/domain/card_day.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_repository.dart';
import 'package:hisaab/features/credit_cards/domain/card_matcher.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/credit_cards/domain/card_position.dart';
import 'package:hisaab/features/statement_import/domain/statement.dart';
import 'package:hisaab/features/statement_import/domain/statement_repository.dart';
import 'package:parser_core/parser_core.dart' show AccountKind;

/// True for a credit card account (FR-14-01): a card, not a debit card, typed
/// credit card or untyped with a stated limit.
bool isCreditCardAccount(Account a) =>
    a.kind == AccountKind.card &&
    !a.isDebitCard &&
    !a.hidden &&
    a.mergedIntoId == null &&
    (a.accountType == AccountType.creditCard ||
        (a.accountType == null && a.availableLimitMinor != null));

/// Works out every credit card's figures from the ledger (read only), the
/// recorded notices, statements and overrides (FR-14-01..05, FR-14-16).
class CardDueService {
  /// Creates the service. [now] is epoch ms.
  CardDueService({
    required AccountRepository accounts,
    required CardDueRepository dues,
    required StatementRepository statements,
    required CardFlowSource flow,
    required CardPaidStore paid,
    int Function()? now,
  })  : _accounts = accounts,
        _dues = dues,
        _statements = statements,
        _flow = flow,
        _paid = paid,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AccountRepository _accounts;
  final CardDueRepository _dues;
  final StatementRepository _statements;
  final CardFlowSource _flow;
  final CardPaidStore _paid;
  final int Function() _now;

  static CardRow _fromStatement(Statement s) => CardRow(
        source: CardDueSource.statement,
        receivedAt: s.receivedAt,
        processedAt: s.processedAt,
        bankName: s.bankName,
        last4: s.last4,
        totalDueMinor: s.totals.totalDueMinor,
        minDueMinor: s.totals.minDueMinor,
        dueEpochDay: s.totals.dueEpochDay,
        creditLimitMinor: s.totals.creditLimitMinor,
        statementEpochDay: s.totals.statementEpochDay,
        availableMinor: s.totals.availableMinor,
      );

  /// Cards, largest available limit first, refreshed on any change.
  Stream<List<CardLimit>> watchCards() => combineLatest<
          (
            List<AccountWithActivity>,
            List<CardRow>,
            List<Statement>,
            Map<String, CardOverride>,
            Set<String>,
          )>(
        [
          _accounts.watchWithActivity(monthStartMs: 0, monthEndMs: _now()),
          _dues.watchNotices(),
          _statements.watchAll(),
          _dues.watchOverrides(),
          _paid.watchPaid(),
        ],
        (v) => (
          v[0]! as List<AccountWithActivity>,
          v[1]! as List<CardRow>,
          v[2]! as List<Statement>,
          v[3]! as Map<String, CardOverride>,
          v[4]! as Set<String>,
        ),
      ).asyncMap((s) => _build(s.$1, s.$2, s.$3, s.$4, s.$5));

  /// One snapshot of [watchCards].
  Future<List<CardLimit>> cards() => watchCards().first;

  /// The card with account id [id], or null.
  Future<CardLimit?> card(int id) async =>
      (await cards()).where((c) => c.id == id).firstOrNull;

  Future<List<CardLimit>> _build(
    List<AccountWithActivity> accounts,
    List<CardRow> notices,
    List<Statement> statements,
    Map<String, CardOverride> overrides,
    Set<String> paid,
  ) async {
    final cardAccts = [
      for (final a in accounts)
        if (isCreditCardAccount(a.account)) a,
    ];
    final refs = [
      for (final a in cardAccts)
        CardRef(
          id: a.account.id,
          bankName: a.account.bankName,
          last4: a.account.last4,
        ),
    ];
    final stmtRows = [
      for (final s in statements)
        if (s.kind == StatementKind.creditCard &&
            s.status == StatementStatus.parsed)
          _fromStatement(s),
    ];
    final all = [...notices, ...stmtRows];
    final now = _now();
    final today = CardDay.ofMs(now);
    final out = <CardLimit>[];
    for (var i = 0; i < cardAccts.length; i++) {
      final a = cardAccts[i];
      final ref = refs[i];
      final rows = CardMatcher.rowsFor(ref, refs, all);
      var from = now - CardDueRules.windowDays * 86400000;
      for (final r in rows) {
        final d = r.statementEpochDay;
        if (d != null && CardDay.startMs(d) < from) from = CardDay.startMs(d);
      }
      final flow = await _flow.flowSince(a.account.id, from);
      final position = cardPosition(
        rows: rows,
        override: overrides[CardMatcher.cardKey(ref.bankName, ref.last4)],
        available: a.currentBalanceMinor,
        flow: flow,
        today: today,
      );
      final due = position.dueDay;
      out.add(
        CardLimit(
          id: ref.id,
          name: a.account.label,
          bankName: ref.bankName,
          last4: ref.last4,
          position: position,
          paid: due != null && paid.contains(CardPaidStore.key(ref.id, due)),
          availableMinor: a.currentBalanceMinor,
          availableEstimated: a.balanceIsEstimated,
          network: a.account.cardNetwork,
        ),
      );
    }
    out.sort(
      (x, y) => (y.availableMinor ?? -1).compareTo(x.availableMinor ?? -1),
    );
    return out;
  }
}
