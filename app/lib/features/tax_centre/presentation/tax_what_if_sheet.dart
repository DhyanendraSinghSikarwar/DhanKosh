import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/analytics_providers.dart';
import 'package:hisaab/features/tax_centre/domain/tax_plan.dart';

/// Opens the what-if sheet; values stay in memory only (FR-19-07, FR-19-08).
Future<void> showTaxWhatIfSheet(
  BuildContext context,
  WidgetRef ref,
  TaxPlan plan,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _Sheet(plan: plan, ref: ref),
    );

class _Sheet extends StatefulWidget {
  const _Sheet({required this.plan, required this.ref});

  final TaxPlan plan;
  final WidgetRef ref;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  late final TextEditingController _salary = _c(widget.plan.salaryUsed);
  late final TextEditingController _c80 = _c(widget.plan.c80);
  late final TextEditingController _d80 = _c(widget.plan.d80);
  late final TextEditingController _nps = _c(widget.plan.nps);

  TextEditingController _c(int minor) =>
      TextEditingController(text: (minor ~/ 100).toString());

  @override
  void dispose() {
    _salary.dispose();
    _c80.dispose();
    _d80.dispose();
    _nps.dispose();
    super.dispose();
  }

  int? _paise(TextEditingController c, int current) {
    final v = int.tryParse(c.text.trim());
    if (v == null) return null;
    final p = v * 100;
    return p == current ? null : p;
  }

  void _apply() {
    final p = widget.plan;
    final old = p.whatIf;
    widget.ref.read(taxWhatIfStateProvider.notifier).set(
          TaxWhatIf(
            salary: _paise(_salary, p.est.salary) ?? old.salary,
            interest: old.interest,
            dividends: old.dividends,
            rent: old.rent,
            otherIncome: old.otherIncome,
            stcg: old.stcg,
            ltcg: old.ltcg,
            c80: _paise(_c80, p.deductions.c80Calc) ?? old.c80,
            d80: _paise(_d80, p.deductions.d80Calc) ?? old.d80,
            nps: _paise(_nps, p.deductions.npsDetected) ?? old.nps,
            homeLoan: old.homeLoan,
            hraOther: old.hraOther,
            employerNps: old.employerNps,
          ),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Widget field(String label, TextEditingController c, Key key) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            key: key,
            controller: c,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label, prefixText: '₹ '),
          ),
        );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What if', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          field('Salary', _salary, const Key('wi-salary')),
          field('80C', _c80, const Key('wi-80c')),
          field('80D', _d80, const Key('wi-80d')),
          field('NPS', _nps, const Key('wi-nps')),
          FilledButton(
            key: const Key('wi-apply'),
            onPressed: _apply,
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
