import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/merge_suggestions.dart';
import 'package:hisaab/features/accounts_management/domain/untracked_gap.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:parser_core/parser_core.dart';

const int _day = 24 * 60 * 60 * 1000;
const _now = 1790310600000;

Account acct(
  int id, {
  AccountKind kind = AccountKind.account,
  String bank = 'HDFC Bank',
  String last4 = '1234',
  int? manualAt,
  int? linked,
  int? merged,
  AccountType? type,
  int? balance,
}) =>
    Account(
      id: id,
      bankName: bank,
      last4: last4,
      kind: kind,
      createdAt: 0,
      manualBalanceAt: manualAt,
      linkedAccountId: linked,
      mergedIntoId: merged,
      accountType: type,
      latestBalanceMinor: balance,
    );

LedgerTx tx(
  int id,
  int at, {
  int amount = 50000,
  TransactionType type = TransactionType.debit,
  int? account = 1,
  int? balance,
  int? limit,
  AccountKind kind = AccountKind.account,
  int? inr,
  String? note,
}) =>
    LedgerTx(
      id: id,
      amountMinor: amount,
      currency: 'INR',
      type: type,
      bankName: 'HDFC Bank',
      accountKind: kind,
      channel: Channel.upi,
      timestamp: at,
      hasExplicitTime: true,
      category: Category.other,
      transactionHash: 'h$id',
      confidence: 1,
      needsReview: false,
      createdAt: at,
      accountId: account,
      balanceMinor: balance,
      availableLimitMinor: limit,
      inrMinor: inr ?? amount,
      note: note,
    );

List<UntrackedGap> detect(
  List<LedgerTx> txs, {
  List<Account>? accounts,
  Map<int, int> dir = const {},
  Set<String> dismissed = const {},
}) =>
    BalanceGaps.detect(
      accounts: accounts ?? [acct(1)],
      txs: txs,
      transferDir: dir,
      dismissed: dismissed,
      now: _now,
    );

void main() {
  const t1 = _now - 10 * _day;
  const t2 = _now - 6 * _day;

  // TC-13-10 (FR-13-15): the worked example, 20,000 -> 18,500 with a 500 debit.
  test('significant gap: money left with no message', () {
    final g = detect([
      tx(1, t1, amount: 100, balance: 2000000),
      tx(2, t1 + _day),
      tx(3, t2, amount: 100, balance: 1850000, type: TransactionType.credit),
    ]);
    // Expected 20,000 - 500 + 1 = 19,501; stated 18,500.
    expect(g.single.deltaMinor, 1850000 - 1950100);
    expect(g.single.moneyLeft, isTrue);
    expect(g.single.key, '1|$t1|$t2');
  });

  // TC-13-10: below the threshold.
  test('gap below 100 paise or the share floor is not a gap', () {
    expect(
      detect([
        tx(1, t1, amount: 100, balance: 2000000),
        tx(2, t2, amount: 100, balance: 2000050, type: TransactionType.credit),
      ]),
      isEmpty,
    );
  });

  // TC-13-10: unknown transfer direction explains the balance -> null.
  test('unknown transfer in the window yields no gap', () {
    final rows = [
      tx(1, t1, amount: 100, balance: 100000),
      tx(2, t1 + _day, amount: 30000, type: TransactionType.transfer),
      tx(3, t2, amount: 100, balance: 70100, type: TransactionType.credit),
    ];
    expect(detect(rows), isEmpty);
    // With a known direction (out) the books balance too.
    expect(detect(rows, dir: {2: -1}), isEmpty);
    // Known direction "in" leaves a gap.
    expect(detect(rows, dir: {2: 1}), hasLength(1));
  });

  // TC-13-10: manual balance inside the window, age, dismissed.
  test('skips manual balance windows, old windows and dismissed keys', () {
    final rows = [
      tx(1, t1, amount: 100, balance: 2000000),
      tx(2, t2, amount: 100, balance: 1000000, type: TransactionType.credit),
    ];
    expect(detect(rows), hasLength(1));
    expect(
      detect(rows, accounts: [acct(1, manualAt: t1 + _day)]),
      isEmpty,
    );
    expect(detect(rows, dismissed: {'1|$t1|$t2'}), isEmpty);
    final old = [
      tx(1, _now - 200 * _day, amount: 100, balance: 2000000),
      tx(
        2,
        _now - 100 * _day,
        amount: 100,
        balance: 1,
        type: TransactionType.credit,
      ),
    ];
    expect(detect(old), isEmpty);
  });

  // FR-13-15: a card limit that fell is limit used with no message.
  test('card gaps use the available limit', () {
    final g = detect(
      [
        tx(1, t1, kind: AccountKind.card, limit: 5000000, amount: 100),
        tx(
          2,
          t2,
          kind: AccountKind.card,
          limit: 4000000,
          amount: 100,
          type: TransactionType.credit,
        ),
      ],
      accounts: [acct(1, kind: AccountKind.card)],
    );
    expect(g.single.card, isTrue);
    expect(g.single.moneyLeft, isTrue);
  });

  // FR-13-15: debit cards and merged accounts roll up; linked accounts skip.
  test('members roll up into the main account', () {
    final accts = [
      acct(1),
      acct(2, type: AccountType.debitCard, linked: 1),
      acct(3, merged: 1, last4: '1235'),
    ];
    final g = detect(
      [
        tx(1, t1, amount: 100, balance: 2000000),
        tx(2, t1 + _day, account: 2),
        tx(
          3,
          t2,
          account: 3,
          amount: 100,
          balance: 1950100,
          type: TransactionType.credit,
        ),
      ],
      accounts: accts,
    );
    expect(g, isEmpty);
  });

  // TC-13-11 (FR-13-15)
  test('GapPrefill choices and time', () {
    const out = UntrackedGap(
      accountId: 1,
      fromTime: 1000000,
      toTime: 2000000,
      deltaMinor: -5000,
      balanceBefore: 1,
      balanceAfter: 1,
      card: false,
    );
    final p = GapPrefill.of(out);
    expect(p.choices, [GapChoice.payment, GapChoice.transfer]);
    expect(p.amountMinor, 5000);
    expect(p.time, 2000000 - 60000);
    expect(p.fromAccountId, 1);
    expect(
      GapPrefill.of(out, last: GapChoice.transfer).choice,
      GapChoice.transfer,
    );
    const cardUp = UntrackedGap(
      accountId: 1,
      fromTime: 1,
      toTime: 2,
      deltaMinor: 5000,
      balanceBefore: 1,
      balanceAfter: 1,
      card: true,
    );
    expect(GapPrefill.of(cardUp).choice, GapChoice.transfer);
    expect(GapPrefill.of(cardUp).toAccountId, 1);
    const cardOut = UntrackedGap(
      accountId: 1,
      fromTime: 1,
      toTime: 2,
      deltaMinor: -5000,
      balanceBefore: 1,
      balanceAfter: 1,
      card: true,
    );
    expect(GapPrefill.of(cardOut).choices, [GapChoice.payment]);
  });

  // TC-13-11: candidates single and sum of two within 100 paise.
  test('GapCandidates finds single rows and sums', () {
    const g = UntrackedGap(
      accountId: 1,
      fromTime: t1,
      toTime: t2,
      deltaMinor: -30000,
      balanceBefore: 1,
      balanceAfter: 1,
      card: false,
    );
    final rows = [
      tx(1, t1 + 1000, account: null, amount: 30050),
      tx(2, t1 + 2000, account: null, amount: 10000),
      tx(3, t1 + 3000, account: null, amount: 20000),
      tx(
        4,
        t1 + 4000,
        account: null,
        amount: 99999,
        type: TransactionType.credit,
      ),
      tx(5, t1 + 5000, amount: 30000),
    ];
    final c = GapCandidates.find(g, rows);
    expect(c.first.map((t) => t.id), [1]);
    expect(c[1].map((t) => t.id), [2, 3]);
    expect(c, hasLength(2));
  });

  // TC-13-12 (FR-13-16): max 3, 14 days, once each.
  test('gapAlerts caps, ages and dedups', () {
    UntrackedGap gap(
      int i,
      int toAgoDays, {
      int delta = -5000,
      bool card = false,
    }) =>
        UntrackedGap(
          accountId: i,
          fromTime: 1,
          toTime: _now - toAgoDays * _day,
          deltaMinor: delta,
          balanceBefore: 1,
          balanceAfter: 1,
          card: card,
        );
    final gaps = [
      gap(1, 1),
      gap(2, 2, delta: 7000),
      gap(3, 3, card: true),
      gap(4, 4),
      gap(5, 20),
    ];
    final out = gapAlerts(
      gaps: gaps,
      notified: {'gap:${gaps[0].key}'},
      now: _now,
      labelOf: (id) => 'Acct$id',
      format: (m) => '₹${m ~/ 100}',
    );
    expect(out.map((a) => a.accountId), [2, 3, 4]);
    expect(out[0].body, 'Acct2: ₹70 came in with no message. Add it?');
    expect(out[1].body, 'Acct3: ₹50 of limit used with no message. Add it?');
    expect(out[0].title, 'Untracked change');
    expect(
      gapAlerts(
        gaps: [gaps[4]],
        notified: {},
        now: _now,
        labelOf: (_) => '',
        format: (_) => '',
      ),
      isEmpty,
    );
  });

  // TC-13-06 (FR-13-09)
  test('duplicate suggestions', () {
    final a = acct(1);
    final b = acct(2, last4: '234'); // ICICI-style 3 digits
    final c = acct(3, last4: '9999');
    final s = duplicateSuggestions([a, b, c], {1: 5, 2: 1});
    expect(s, hasLength(1));
    expect(s.single.target.id, 1);
    expect(s.single.source.id, 2);
    // Differing types are never duplicates.
    expect(
      duplicateSuggestions(
        [
          acct(1, type: AccountType.savings),
          acct(2, type: AccountType.current),
        ],
        {},
      ),
      isEmpty,
    );
    // Odd number merges into the proper one.
    final odd = duplicateSuggestions([acct(1, last4: 'x'), acct(2)], {1: 9});
    expect(odd.single.target.id, 2);
  });

  // TC-13-07 (FR-13-09)
  test('debit card link suggestions', () {
    final bank1 = acct(1, balance: 100);
    final bank2 = acct(2, last4: '5555', balance: 200);
    final card = acct(
      3,
      kind: AccountKind.card,
      type: AccountType.debitCard,
      last4: '7777',
      balance: 200,
    );
    var l = linkSuggestions([bank1, bank2, card], {1: 9});
    expect(l.single.account.id, 2);
    expect(l.single.reason, contains('balance'));
    l = linkSuggestions([bank1, card], {});
    expect(l.single.reason, "It's your only HDFC Bank account.");
    final card2 = acct(
      4,
      kind: AccountKind.card,
      type: AccountType.debitCard,
      last4: '8888',
    );
    l = linkSuggestions([bank1, bank2, card2], {2: 7});
    expect(l.single.account.id, 2);
    expect(l.single.reason, 'Your most used HDFC Bank account.');
    expect(linkSuggestions([card], {}), isEmpty);
  });
}
