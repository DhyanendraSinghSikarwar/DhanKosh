import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/analytics_providers.dart';
import 'package:hisaab/app/di/backup_providers.dart';
import 'package:hisaab/features/tax_centre/domain/tax_calculator.dart';
import 'package:hisaab/features/tax_centre/domain/tax_plan.dart';
import 'package:hisaab/features/tax_centre/domain/tax_report_builder.dart';
import 'package:hisaab/features/tax_centre/domain/tax_rules.dart';
import 'package:hisaab/features/tax_centre/presentation/tax_what_if_sheet.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Tax Centre: old vs new regime estimate (F-19, FR-19-01).
class TaxCentreScreen extends ConsumerWidget {
  /// Creates the screen.
  const TaxCentreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(taxPeriodChoiceProvider);
    final base = ref.watch(taxBaselineProvider).value;
    final whatIf = ref.watch(taxWhatIfStateProvider);
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    String money(int m) => formatAmount(m, masked: masked, paise: false);
    final plan = base?.plan(whatIf);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Centre'),
        actions: [
          IconButton(
            key: const Key('tax-export'),
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: plan == null || !plan.hasIncome
                ? null
                : () => _export(context, ref, plan, masked: masked),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TaxPeriod>(
            key: const Key('tax-period'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TaxPeriod.thisFy, label: Text('This FY')),
              ButtonSegment(value: TaxPeriod.lastFy, label: Text('Last FY')),
              ButtonSegment(value: TaxPeriod.last12, label: Text('12 months')),
            ],
            selected: {period},
            onSelectionChanged: (s) =>
                ref.read(taxPeriodChoiceProvider.notifier).select(s.first),
          ),
          const SizedBox(height: 12),
          if (plan == null)
            const Center(child: CircularProgressIndicator())
          else
            ..._body(context, ref, plan, money),
        ],
      ),
    );
  }

  // FR-19-09..11: needs income; asks first while amounts are hidden.
  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    TaxPlan plan, {
    required bool masked,
  }) async {
    if (masked) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Export with amounts?'),
          content: const Text('The PDF shows real figures.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('tax-export-confirm'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Export'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final saved = await ref.read(reportServiceProvider).save(
          ref.read(blobGatewayProvider),
          TaxReportBuilder.build(plan),
        );
    if (saved != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved $saved')));
    }
  }

  List<Widget> _body(
    BuildContext context,
    WidgetRef ref,
    TaxPlan plan,
    String Function(int) money,
  ) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget row(String l, String v, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(child: Text(l, style: style ?? t.bodyMedium)),
              Text(v, style: style ?? t.bodyMedium),
            ],
          ),
        );
    Widget card(String title, List<Widget> kids, {Key? key}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            key: key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSmall),
                const SizedBox(height: 8),
                ...kids,
              ],
            ),
          ),
        );
    final newRegime = plan.newIsBetter;
    final best = newRegime ? plan.newRegime : plan.oldRegime;
    final slabs = (newRegime ? plan.rules.newRegime : plan.rules.oldRegime)
            .slabs[AgeBand.below60] ??
        const <TaxSlab>[];
    return [
      Text(
        '${plan.fyLabel} estimate. FY 2026-27 rules unconfirmed.',
        key: const Key('tax-note'),
        style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      card('Income', [
        row('Salary', money(plan.salaryUsed)),
        row('Interest', money(plan.interestUsed)),
        row('Dividends', money(plan.dividendsUsed)),
        row('Rent', money(plan.rentUsed)),
        row('Other', money(plan.otherUsed)),
        const Divider(),
        row('Total', money(plan.income), style: t.titleSmall),
        if (plan.est.estimated)
          Text(
            'Estimated from ${plan.est.monthsOfData} months of data',
            style: t.bodySmall,
          ),
      ]),
      if (!plan.hasIncome)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'No income found. Use What if to enter figures.',
            key: Key('tax-no-income'),
          ),
        )
      else
        card(
          plan.newIsBetter
              ? 'New regime saves ${money(plan.saving)}'
              : 'Old regime saves ${money(plan.saving)}',
          [
            Row(
              key: const Key('tax-compare'),
              children: [
                Expanded(child: _regime(context, 'New', plan.newRegime, money)),
                const SizedBox(width: 12),
                Expanded(child: _regime(context, 'Old', plan.oldRegime, money)),
              ],
            ),
          ],
        ),
      if (plan.hasIncome)
        card('Slabs (${newRegime ? 'new' : 'old'} regime)', [
          for (final l in TaxCalculator.slabLines(best.taxable, slabs))
            row(
              l.to == null
                  ? 'Above ${money(l.from)} at ${l.rate}%'
                  : '${money(l.from)} to ${money(l.to!)} at ${l.rate}%',
              money(l.tax),
            ),
        ]),
      card('Detected deductions', [
        row('80C', '${money(plan.c80)} of ${money(plan.rules.limit80C)}'),
        for (final i in plan.deductions.items80C)
          row(i.label, money(i.amountMinor)),
        row('80D', money(plan.d80)),
        for (final i in plan.deductions.items80D)
          row(i.label, money(i.amountMinor)),
        row('NPS', money(plan.nps)),
        if (plan.left80C > 0) Text('${money(plan.left80C)} of 80C left'),
      ]),
      Row(
        children: [
          Expanded(
            child: FilledButton.tonal(
              key: const Key('tax-whatif'),
              onPressed: () => showTaxWhatIfSheet(context, ref, plan),
              child: const Text('What if'),
            ),
          ),
          if (plan.whatIf.any) ...[
            const SizedBox(width: 8),
            TextButton(
              key: const Key('tax-whatif-reset'),
              onPressed: () => ref
                  .read(taxWhatIfStateProvider.notifier)
                  .set(const TaxWhatIf()),
              child: const Text('Reset'),
            ),
          ],
        ],
      ),
    ];
  }

  Widget _regime(
    BuildContext context,
    String name,
    RegimeTax r,
    String Function(int) money,
  ) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: t.labelLarge),
        Text(money(r.total), key: Key('tax-total-$name'), style: t.titleLarge),
        Text('Taxable ${money(r.taxable)}', style: t.bodySmall),
        Text('Deductions ${money(r.deductions)}', style: t.bodySmall),
        Text('Cess ${money(r.cess)}', style: t.bodySmall),
      ],
    );
  }
}
