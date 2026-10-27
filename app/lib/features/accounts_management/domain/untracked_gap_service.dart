import 'package:hisaab/features/accounts_management/domain/account_admin_repository.dart';
import 'package:hisaab/features/accounts_management/domain/untracked_gap.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/settings_repository.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_tx.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:parser_core/parser_core.dart';

/// Settings keys of the untracked-gap feature (memory 13 section 3.8).
abstract final class GapSettingKeys {
  /// Dismissed gap keys.
  static const dismissed = SettingKey<Set<String>>(
    'untracked_gaps.dismissed',
    <String>{},
  );

  /// `"<accountId>=<GapChoice name>"`, last choice per account.
  static const choices = SettingKey<Set<String>>(
    'untracked_gaps.choices',
    <String>{},
  );
}

/// Finds open gaps and records what the user did with them (FR-13-15).
class UntrackedGapService {
  /// Creates the service.
  UntrackedGapService({
    required AccountAdminRepository accounts,
    required TransactionRepository transactions,
    required SettingsRepository settings,
    int Function()? now,
  })  : _accounts = accounts,
        _txs = transactions,
        _settings = settings,
        _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AccountAdminRepository _accounts;
  final TransactionRepository _txs;
  final SettingsRepository _settings;
  final int Function() _now;

  static const int _dayMs = 24 * 60 * 60 * 1000;

  /// Open gaps, newest first, without dismissed ones.
  Future<List<UntrackedGap>> openGaps() async {
    final now = _now();
    final all = await _accounts.all();
    final txs = await _txs
        .watch(
          LedgerFilter(fromMs: now - BalanceGaps.historyDays * _dayMs),
        )
        .first;
    final dir = <int, int>{};
    for (final t in txs) {
      if (t.type != TransactionType.transfer) continue;
      if (t.note?.startsWith('Credit card bill') ?? false) {
        dir[t.id] = -1;
        continue;
      }
      for (final s in await _txs.sourcesOf(t.id)) {
        if (s.sourceMessageId.startsWith('xfer-out:')) dir[t.id] = -1;
        if (s.sourceMessageId.startsWith('xfer-in:')) dir[t.id] = 1;
      }
    }
    return BalanceGaps.detect(
      accounts: all,
      txs: txs,
      transferDir: dir,
      dismissed: await _settings.read(GapSettingKeys.dismissed),
      now: now,
    );
  }

  /// Account-less rows that may be [gap]'s missing money.
  Future<List<List<LedgerTx>>> candidates(UntrackedGap gap) async {
    final rows = await _txs.watch(LedgerFilter(fromMs: gap.fromTime)).first;
    return GapCandidates.find(gap, rows);
  }

  /// Attaches the account-less [rows] to the gap's account (ledger write path).
  Future<void> assign(UntrackedGap gap, List<LedgerTx> rows) async {
    for (final r in rows) {
      await _txs.setAccount(r.id, gap.accountId);
    }
  }

  /// Hides the gap for good.
  Future<void> ignore(UntrackedGap gap) async {
    final cur = await _settings.read(GapSettingKeys.dismissed);
    await _settings.write(GapSettingKeys.dismissed, {...cur, gap.key});
  }

  /// Remembers the last explanation chosen for [accountId].
  Future<void> rememberChoice(int accountId, GapChoice choice) async {
    final cur = await _settings.read(GapSettingKeys.choices);
    await _settings.write(GapSettingKeys.choices, {
      for (final c in cur)
        if (!c.startsWith('$accountId=')) c,
      '$accountId=${choice.name}',
    });
  }

  /// The remembered choice for [accountId].
  Future<GapChoice?> lastChoice(int accountId) async {
    for (final c in await _settings.read(GapSettingKeys.choices)) {
      if (c.startsWith('$accountId=')) {
        final n = c.substring('$accountId='.length);
        return GapChoice.values.where((g) => g.name == n).firstOrNull;
      }
    }
    return null;
  }
}
