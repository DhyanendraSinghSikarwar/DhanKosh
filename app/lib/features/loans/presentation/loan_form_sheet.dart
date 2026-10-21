import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/bills_providers.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/loans/domain/loan_account_repository.dart';
import 'package:hisaab/features/loans/domain/loan_builder.dart';
import 'package:hisaab/features/loans/domain/loan_models.dart';
import 'package:hisaab/features/loans/presentation/loan_card.dart';

/// Add or edit a hand-entered loan (FR-15-06). Terms are validated by
/// `Loans.termsFromForm`; the EMI is calculated from them.
class LoanFormSheet extends ConsumerStatefulWidget {
  /// Creates the sheet; [loan] set edits that loan's account.
  const LoanFormSheet({this.loan, super.key});

  /// Loan to edit (must have an account).
  final Loan? loan;

  @override
  ConsumerState<LoanFormSheet> createState() => _LoanFormSheetState();
}

class _LoanFormSheetState extends ConsumerState<LoanFormSheet> {
  final _lender = TextEditingController();
  final _last4 = TextEditingController();
  final _principal = TextEditingController();
  final _emi = TextEditingController();
  final _rate = TextEditingController(text: '0');
  final _tenure = TextEditingController();
  final _outstanding = TextEditingController();
  DateTime? _first;
  String? _error;

  @override
  void initState() {
    super.initState();
    final l = widget.loan;
    if (l == null) return;
    final t = l.terms;
    _lender.text = l.bankName;
    if (t != null) {
      _principal.text = '${t.principalMinor ~/ 100}';
      _rate.text = (t.rateBps / 100).toString();
      _tenure.text = '${t.tenureMonths}';
      _first = t.startDay;
    }
    if (l.outstandingFromBank && l.outstandingMinor != null) {
      _outstanding.text = '${l.outstandingMinor! ~/ 100}';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _lender,
      _last4,
      _principal,
      _emi,
      _rate,
      _tenure,
      _outstanding,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _bps(String s) {
    final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(s.trim());
    if (m == null) return null;
    return int.parse(m.group(1)!) * 100 +
        int.parse((m.group(2) ?? '').padRight(2, '0'));
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _first ?? now,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null)
      setState(() => _first = DateTime.utc(d.year, d.month, d.day));
  }

  Future<void> _save() async {
    final lender = _lender.text.trim();
    if (lender.isEmpty) return setState(() => _error = 'Enter the lender');
    final last4 = _last4.text.trim();
    if (last4.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(last4)) {
      return setState(() => _error = 'Last 4 must be 4 digits');
    }
    final rate = _bps(_rate.text);
    final tenure = int.tryParse(_tenure.text.trim());
    final terms = rate == null
        ? null
        : Loans.termsFromForm(
            principalMinor: parseMoney(_principal.text)?.minor,
            emiMinor: parseMoney(_emi.text)?.minor,
            rateBps: rate,
            tenureMonths: tenure,
            firstEmi: _first,
          );
    if (terms == null) {
      return setState(
        () => _error = 'Enter principal or EMI, tenure 1-600, rate 0-60%',
      );
    }
    if (_first != null && !Loans.validEmiDay(_first!.day)) {
      return setState(() => _error = 'Invalid EMI day');
    }
    int? out;
    if (_outstanding.text.trim().isNotEmpty) {
      out = parseMoney(_outstanding.text)?.minor;
      if (out == null) return setState(() => _error = 'Invalid outstanding');
    }
    final draft = LoanDraft(
      bankName: lender,
      last4: last4.isEmpty ? null : last4,
      principalMinor: terms.principalMinor,
      rateBps: terms.rateBps,
      tenureMonths: terms.tenureMonths,
      startDay: _first == null
          ? null
          : _first!.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay,
      outstandingMinor: out,
    );
    final repo = ref.read(loanAccountRepositoryProvider);
    final id = widget.loan?.accountId;
    if (id == null) {
      final made = await repo.create(draft);
      if (made == null) {
        return setState(
            () => _error = 'A loan with this lender and last 4 exists');
      }
    } else {
      await repo.update(id, draft);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.loan != null;
    Widget field(String key, String label, TextEditingController c,
            {String? prefix, bool number = true}) =>
        TextField(
          key: Key(key),
          controller: c,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label, prefixText: prefix),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Edit loan' : 'Add loan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            field('loan-lender', 'Lender', _lender, number: false),
            if (!editing) field('loan-last4', 'Last 4 (optional)', _last4),
            field('loan-principal', 'Principal', _principal, prefix: '₹ '),
            field('loan-emi', 'EMI (used when no principal)', _emi,
                prefix: '₹ '),
            Row(
              children: [
                Expanded(child: field('loan-rate', 'Rate % a year', _rate)),
                const SizedBox(width: 12),
                Expanded(
                    child: field('loan-tenure', 'Tenure (months)', _tenure)),
              ],
            ),
            field(
                'loan-outstanding', 'Outstanding now (optional)', _outstanding,
                prefix: '₹ '),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('loan-first'),
              onPressed: _pick,
              child: Text(
                _first == null
                    ? 'First EMI date'
                    : 'First EMI ${loanDate(_first!)}',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const Key('loan-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('loan-save'),
                onPressed: _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
