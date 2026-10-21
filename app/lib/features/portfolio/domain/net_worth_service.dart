import 'package:hisaab/core/utils/combine_latest.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/accounts_management/domain/account_repository.dart';
import 'package:hisaab/features/credit_cards/domain/card_due_service.dart';
import 'package:hisaab/features/credit_cards/domain/card_models.dart';
import 'package:hisaab/features/portfolio/domain/compute_net_worth.dart';
import 'package:hisaab/features/portfolio/domain/holding.dart';
import 'package:hisaab/features/portfolio/domain/holding_repository.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/portfolio/domain/net_worth_repository.dart';

/// Live net worth from accounts, holdings, card dues and exclusions.
class NetWorthService {
  /// Creates the service. [now] is epoch ms.
  NetWorthService({
    required AccountRepository accounts,
    required HoldingRepository holdings,
    required CardDueService cards,
    required NetWorthPrefsRepository prefs,
    required NetWorthRepository history,
    int Function()? now,
  })  : _accounts = accounts,
        _holdings = holdings,
        _cards = cards,
        _prefs = prefs,
        _history = history,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AccountRepository _accounts;
  final HoldingRepository _holdings;
  final CardDueService _cards;
  final NetWorthPrefsRepository _prefs;
  final NetWorthRepository _history;
  final int Function() _now;

  /// Net worth for [book], refreshed on any change.
  Stream<NetWorth> watch({Book book = Book.all}) => combineLatest<NetWorth>(
        [
          _accounts.watchWithActivity(monthStartMs: 0, monthEndMs: _now()),
          _holdings.watch(),
          _cards.watchCards(),
          _prefs.watch(),
        ],
        (v) => computeNetWorth(
          accounts: v[0]! as List<AccountWithActivity>,
          holdings: v[1]! as List<Holding>,
          cards: v[2]! as List<CardLimit>,
          filter: v[3]! as NetWorthFilter,
          book: book,
        ),
      );

  /// Records today's all-books point (FR-16-05). [today] is an epoch day.
  Future<bool> recordToday(int today) async {
    final w = await watch().first;
    // Recorded history ignores exclusions: recompute with defaults.
    final all = computeNetWorth(
      accounts: await _accounts
          .watchWithActivity(monthStartMs: 0, monthEndMs: _now())
          .first,
      holdings: await _holdings.list(),
      cards: w.cards,
    );
    return await _history.recordPoint(
      today,
      all.assetsMinor,
      all.liabilitiesMinor,
    );
  }
}
