import 'package:hisaab/core/utils/ist.dart';
import 'package:hisaab/features/backup_export/domain/blob_gateway.dart';
import 'package:hisaab/features/backup_export/domain/report_builders.dart';
import 'package:hisaab/features/expense_tracking/domain/budget_repository.dart';
import 'package:hisaab/features/portfolio/domain/holding_repository.dart';
import 'package:hisaab/features/portfolio/domain/net_worth.dart';
import 'package:hisaab/features/transactions_ledger/domain/ledger_filter.dart';
import 'package:hisaab/features/transactions_ledger/domain/transaction_repository.dart';
import 'package:hisaab/shared/report/pdf_report_renderer.dart';
import 'package:hisaab/shared/report/report_document.dart';

/// Builds and saves PDF reports on the device (FR-24-29..31).
class ReportService {
  /// Creates the service. [netWorth] returns the current figure or null.
  const ReportService({
    required TransactionRepository txs,
    required BudgetRepository budgets,
    required HoldingRepository holdings,
    required Future<NetWorth?> Function() netWorth,
  })  : _txs = txs,
        _budgets = budgets,
        _holdings = holdings,
        _netWorth = netWorth;

  final TransactionRepository _txs;
  final BudgetRepository _budgets;
  final HoldingRepository _holdings;
  final Future<NetWorth?> Function() _netWorth;

  /// Summary of one month.
  Future<ReportDocument> month(int year, int month) => _period(
        label: ReportBuilders.monthLabel(year, month),
        stem: 'DhanKosh-summary-$year-${month.toString().padLeft(2, '0')}',
        fromMs: Ist.startMs(year, month, 1),
        toMs: month == 12
            ? Ist.startMs(year + 1, 1, 1)
            : Ist.startMs(year, month + 1, 1),
        months: 1,
      );

  /// Summary of one calendar year.
  Future<ReportDocument> year(int year) => _period(
        label: 'Year $year',
        stem: 'DhanKosh-summary-$year',
        fromMs: Ist.startMs(year, 1, 1),
        toMs: Ist.startMs(year + 1, 1, 1),
        months: 12,
      );

  Future<ReportDocument> _period({
    required String label,
    required String stem,
    required int fromMs,
    required int toMs,
    required int months,
  }) async {
    final txs =
        await _txs.watch(LedgerFilter(fromMs: fromMs, toMs: toMs)).first;
    final nw = await _netWorth();
    return ReportBuilders.period(
      label: label,
      fileStem: stem,
      txs: txs,
      fromMs: fromMs,
      toMs: toMs,
      budgets: await _budgets.all(),
      months: months,
      assetsMinor: nw?.assetsMinor,
      liabilitiesMinor: nw?.liabilitiesMinor,
    );
  }

  /// Holdings report as of [today].
  Future<ReportDocument> portfolio(DateTime today) async {
    final nw = await _netWorth();
    return ReportBuilders.portfolio(
      holdings: await _holdings.list(),
      asOf:
          '${today.day} ${ReportBuilders.monthLabel(today.year, today.month)}',
      assetsMinor: nw?.assetsMinor,
      liabilitiesMinor: nw?.liabilitiesMinor,
    );
  }

  /// Renders [doc] and saves it as `<fileStem>.pdf`; null on cancel.
  Future<String?> save(BlobGateway gateway, ReportDocument doc) async {
    final bytes = await renderReportPdf(doc);
    return await gateway.saveFile(
      '${doc.fileStem}.pdf',
      bytes,
      'application/pdf',
    );
  }
}
