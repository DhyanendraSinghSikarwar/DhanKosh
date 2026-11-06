import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/app/di/statement_import_providers.dart';
import 'package:hisaab/core/money/money.dart';
import 'package:hisaab/core/money/money_formatter.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/statement_import/domain/import_result.dart';
import 'package:hisaab/features/statement_import/domain/statement_ports.dart';
import 'package:hisaab/features/statement_import/domain/usecases/import_mapped_sheet.dart';
import 'package:hisaab/features/statement_import/presentation/import_result_text.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:parser_core/parser_core.dart' hide Money;

/// Match a spreadsheet's columns to what they hold, see how it reads, then
/// import it and check the closing balance (FR-05-28, FR-05-29). The layout is
/// remembered for the next file from the same bank.
class ColumnMappingScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [file].
  const ColumnMappingScreen({required this.file, super.key});

  /// The CSV or XLSX the user picked.
  final PickedFile file;

  @override
  ConsumerState<ColumnMappingScreen> createState() => _State();
}

class _State extends ConsumerState<ColumnMappingScreen> {
  List<SheetData> _sheets = const [];
  UnsupportedReason? _failure;
  int _sheet = 0;
  ColumnMapping _m = const ColumnMapping();
  MappedStatement? _parsed;
  List<Account> _accounts = const [];
  int? _accountId;
  bool _busy = false;
  bool _saved = false;

  List<List<String>> get _rows =>
      _sheets.isEmpty ? const [] : _sheets[_sheet].rows;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final use = ref.read(importMappedSheetProvider);
    try {
      _sheets = use.read(widget.file);
    } on SheetOpenException catch (e) {
      setState(() => _failure = e.reason);
      return;
    }
    if (_sheets.isEmpty || _sheets.every((s) => s.rows.isEmpty)) {
      setState(() => _failure = UnsupportedReason.unreadable);
      return;
    }
    // The first sheet that has a header, else the biggest.
    var best = 0;
    for (var i = 0; i < _sheets.length; i++) {
      if (_sheets[i].rows.length > _sheets[best].rows.length) best = i;
    }
    for (var i = 0; i < _sheets.length; i++) {
      final r = _sheets[i].rows;
      if (r.isNotEmpty && _hasHeader(r)) {
        best = i;
        break;
      }
    }
    _sheet = best;
    try {
      _accounts = [
        for (final a
            in await ref.read(accountRepositoryProvider).watchVisible().first)
          if (a.kind == AccountKind.account) a,
      ];
    } on Object {
      _accounts = const [];
    }
    if (!mounted) return;
    await _start();
  }

  static bool _hasHeader(List<List<String>> rows) {
    final h = StatementTable.guessHeaderRow(rows);
    final cells = rows[h].where((c) => c.trim().isNotEmpty).toList();
    return cells.length >= 3 &&
        cells.any((c) => c.toLowerCase().contains('date'));
  }

  Future<void> _start() async {
    final rows = _rows;
    final header = StatementTable.guessHeaderRow(rows);
    final saved =
        await ref.read(importMappedSheetProvider).savedFor(rows, header);
    if (!mounted) return;
    setState(() {
      _saved = saved != null;
      _m = saved ?? StatementTable.guessMapping(rows, header);
      _accountId = _accountNamedInPreamble(rows, header);
      _reparse();
    });
  }

  void _reparse() {
    _parsed = StatementTable.parse(_rows, _m);
  }

  /// The one account whose digits the lines above the header name.
  int? _accountNamedInPreamble(List<List<String>> rows, int header) {
    final text = [
      for (var i = 0; i < header && i < rows.length; i++) rows[i].join(' '),
    ].join(' ');
    final found = <String>{
      for (final m in RegExp(
        r'(?:[xX*•]{2,}\s?|ending\s+(?:in\s+)?|a/c\s*(?:no\.?)?\s*:?\s*[\dXx*•]*?)(\d{3,4})\b',
        caseSensitive: false,
      ).allMatches(text))
        m.group(1)!,
    };
    final hits = [
      for (final a in _accounts)
        if (found.contains(a.last4)) a,
    ];
    return hits.length == 1 ? hits.single.id : null;
  }

  void _setHeader(int row) {
    if (row < 0 || row >= _rows.length) return;
    setState(() {
      _m = StatementTable.guessMapping(_rows, row);
      _reparse();
    });
  }

  void _change(ColumnMapping m) => setState(() {
        _m = m;
        _reparse();
      });

  int get _columns {
    var n = 0;
    final end = _rows.length < 60 ? _rows.length : 60;
    for (var i = 0; i < end; i++) {
      if (_rows[i].length > n) n = _rows[i].length;
    }
    return n > SheetLimits.maxColumns ? SheetLimits.maxColumns : n;
  }

  static String _letter(int i) {
    var n = i;
    var s = '';
    do {
      s = String.fromCharCode(65 + n % 26) + s;
      n = n ~/ 26 - 1;
    } while (n >= 0);
    return s;
  }

  String _name(int i) {
    final h =
        _m.headerRow < _rows.length ? _rows[_m.headerRow] : const <String>[];
    final t = i < h.length ? h[i].trim() : '';
    return t.isEmpty ? _letter(i) : '${_letter(i)} · $t';
  }

  Future<void> _import() async {
    final rows = _rows;
    setState(() => _busy = true);
    MappedImportResult r;
    try {
      r = await ref.read(importMappedSheetProvider).commit(
            file: widget.file,
            rows: rows,
            mapping: _m,
            accountId: _accountId,
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (_) => _ResultSheet(result: r),
    );
    if (mounted) Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (_failure != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Match columns')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              importResultText(ImportUnsupported(_failure!)),
              key: const Key('map-failure'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final parsed = _parsed;
    return Scaffold(
      appBar: AppBar(title: const Text('Match columns')),
      body: _sheets.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _saved
                      ? 'Using the layout you saved for this bank. Change '
                          'anything that looks wrong.'
                      : 'Tell DhanKosh which column is which. It remembers '
                          'the layout.',
                  key: const Key('map-hint'),
                  style: text.bodySmall,
                ),
                const SizedBox(height: 12),
                if (_sheets.length > 1)
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var i = 0; i < _sheets.length; i++)
                        ChoiceChip(
                          key: Key('map-sheet-$i'),
                          label: Text(_sheets[i].name),
                          selected: i == _sheet,
                          onSelected: (_) {
                            setState(() => _sheet = i);
                            unawaited(_start());
                          },
                        ),
                    ],
                  ),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Header row: ${_m.headerRow + 1}',
                            key: const Key('map-header-label'),
                            style: text.titleSmall,
                          ),
                          const Spacer(),
                          IconButton(
                            key: const Key('map-header-up'),
                            tooltip: 'Row above',
                            onPressed: _m.headerRow > 0
                                ? () => _setHeader(_m.headerRow - 1)
                                : null,
                            icon: const Icon(Icons.keyboard_arrow_up),
                          ),
                          IconButton(
                            key: const Key('map-header-down'),
                            tooltip: 'Row below',
                            onPressed: _m.headerRow < _rows.length - 1
                                ? () => _setHeader(_m.headerRow + 1)
                                : null,
                            icon: const Icon(Icons.keyboard_arrow_down),
                          ),
                        ],
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _Preview(
                          rows: _rows,
                          headerRow: _m.headerRow,
                          columns: _columns,
                          letter: _letter,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _pickers(),
                const SizedBox(height: 12),
                _sample(parsed, text),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('map-import'),
                  onPressed: _busy || parsed == null || parsed.rows.isEmpty
                      ? null
                      : _import,
                  child: Text(_busy ? 'Importing' : 'Import'),
                ),
              ],
            ),
    );
  }

  Widget _col(
    String label,
    int? value,
    void Function(int?) set, {
    String? key,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<int?>(
          key: Key(key ?? 'map-$label'),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            const DropdownMenuItem<int?>(child: Text('None')),
            for (var i = 0; i < _columns; i++)
              DropdownMenuItem<int?>(
                value: i,
                child: Text(_name(i), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: set,
        ),
      );

  Widget _pickers() {
    final split = _m.isSplit || (_m.amount == null && _m.type == null);
    return AppCard(
      child: Column(
        children: [
          _col(
            'Date',
            _m.date,
            (v) => _change(
              v == null
                  ? _m.copyWith(clearDate: true, clearDateFormat: true)
                  : _m.copyWith(date: v, clearDateFormat: true),
            ),
            key: 'map-date',
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String?>(
              key: const Key('map-date-format'),
              initialValue: _m.dateFormat,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Date format',
                helperText: _m.dateFormat == null && _parsed?.dateFormat != null
                    ? 'Found ${_parsed!.dateFormat}'
                    : null,
              ),
              items: [
                const DropdownMenuItem<String?>(child: Text('Automatic')),
                for (final f in StatementDateFormats.names)
                  DropdownMenuItem<String?>(
                    value: f,
                    child: Text(
                      f == StatementDateFormats.serial
                          ? 'Excel date number'
                          : f,
                    ),
                  ),
              ],
              onChanged: (v) => _change(
                v == null
                    ? _m.copyWith(clearDateFormat: true)
                    : _m.copyWith(dateFormat: v),
              ),
            ),
          ),
          _col(
            'Description',
            _m.description,
            (v) => _change(
              v == null
                  ? _m.copyWith(clearDescription: true)
                  : _m.copyWith(description: v),
            ),
            key: 'map-description',
          ),
          SegmentedButton<bool>(
            key: const Key('map-mode'),
            segments: const [
              ButtonSegment(value: true, label: Text('Debit and credit')),
              ButtonSegment(value: false, label: Text('One amount')),
            ],
            selected: {split},
            onSelectionChanged: (s) {
              final toSplit = s.first;
              if (toSplit) {
                _change(
                  _m.copyWith(
                    debit: _m.amount ?? _m.debit,
                    clearAmount: true,
                    clearType: true,
                  ),
                );
              } else {
                _change(
                  _m.copyWith(
                    amount: _m.debit ?? _m.amount,
                    clearDebit: true,
                    clearCredit: true,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          if (split) ...[
            _col(
              'Debit',
              _m.debit,
              (v) => _change(
                v == null
                    ? _m.copyWith(clearDebit: true)
                    : _m.copyWith(debit: v),
              ),
              key: 'map-debit',
            ),
            _col(
              'Credit',
              _m.credit,
              (v) => _change(
                v == null
                    ? _m.copyWith(clearCredit: true)
                    : _m.copyWith(credit: v),
              ),
              key: 'map-credit',
            ),
          ] else ...[
            _col(
              'Amount',
              _m.amount,
              (v) => _change(
                v == null
                    ? _m.copyWith(clearAmount: true)
                    : _m.copyWith(amount: v),
              ),
              key: 'map-amount',
            ),
            _col(
              'Dr/Cr column',
              _m.type,
              (v) => _change(
                v == null ? _m.copyWith(clearType: true) : _m.copyWith(type: v),
              ),
              key: 'map-type',
            ),
          ],
          _col(
            'Balance',
            _m.balance,
            (v) => _change(
              v == null
                  ? _m.copyWith(clearBalance: true)
                  : _m.copyWith(balance: v),
            ),
            key: 'map-balance',
          ),
          _col(
            'Reference',
            _m.reference,
            (v) => _change(
              v == null
                  ? _m.copyWith(clearReference: true)
                  : _m.copyWith(reference: v),
            ),
            key: 'map-reference',
          ),
          DropdownButtonFormField<int?>(
            key: const Key('map-account'),
            initialValue: _accountId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Account'),
            items: [
              const DropdownMenuItem<int?>(child: Text('No account')),
              for (final a in _accounts)
                DropdownMenuItem<int?>(value: a.id, child: Text(a.label)),
            ],
            onChanged: (v) => setState(() => _accountId = v),
          ),
        ],
      ),
    );
  }

  Widget _sample(MappedStatement? p, TextTheme text) {
    final scheme = Theme.of(context).colorScheme;
    if (p == null || p.rows.isEmpty) {
      return AppCard(
        child: Text(
          _m.isComplete
              ? 'No transactions with these columns.'
              : 'Pick a date and an amount column.',
          key: const Key('map-empty'),
          style: text.bodyMedium?.copyWith(color: scheme.error),
        ),
      );
    }
    final c = p.continuity;
    return AppCard(
      key: const Key('map-sample'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${p.rows.length} rows${p.skipped > 0 ? ', ${p.skipped} skipped' : ''}',
            key: const Key('map-count'),
            style: text.titleSmall,
          ),
          const SizedBox(height: 6),
          for (final r in p.rows.take(5))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(_day(r.epochDay), style: text.bodySmall),
                  ),
                  Expanded(
                    child: Text(
                      r.description.isEmpty ? '-' : r.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                  Text(
                    '${r.isDebit ? '-' : '+'}${formatMoney(Money(r.amountMinor))}',
                    style: text.bodySmall?.copyWith(
                      color: r.isDebit ? scheme.error : null,
                    ),
                  ),
                ],
              ),
            ),
          if (c.checked > 0) ...[
            const SizedBox(height: 8),
            if (c.addsUp)
              Text(
                'Balances add up.',
                key: const Key('map-adds-up'),
                style: text.bodySmall?.copyWith(color: Colors.green),
              )
            else
              Text(
                "${c.breaks} row${c.breaks == 1 ? '' : 's'} don't add up. "
                'Check the debit, credit and balance columns.',
                key: const Key('map-breaks'),
                style: text.bodySmall?.copyWith(color: scheme.error),
              ),
          ],
        ],
      ),
    );
  }

  static String _day(int epochDay) {
    final d = DateTime.utc(1970).add(Duration(days: epochDay));
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.rows,
    required this.headerRow,
    required this.columns,
    required this.letter,
  });

  final List<List<String>> rows;
  final int headerRow;
  final int columns;
  final String Function(int) letter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shown = [
      for (var r = headerRow; r < rows.length && r < headerRow + 6; r++)
        rows[r],
    ];
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder.all(color: Theme.of(context).dividerColor),
      children: [
        TableRow(
          children: [
            for (var c = 0; c < columns; c++)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(letter(c), style: text.labelSmall),
              ),
          ],
        ),
        for (var i = 0; i < shown.length; i++)
          TableRow(
            children: [
              for (var c = 0; c < columns; c++)
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      c < shown[i].length ? shown[i][c] : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: i == 0
                          ? text.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700)
                          : text.bodySmall,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// What the import did and how the closing balance compares (FR-05-29).
class _ResultSheet extends ConsumerStatefulWidget {
  const _ResultSheet({required this.result});

  final MappedImportResult result;

  @override
  ConsumerState<_ResultSheet> createState() => _ResultState();
}

class _ResultState extends ConsumerState<_ResultSheet> {
  String? _note;
  bool _applied = false;

  Future<void> _use() async {
    final r = widget.result;
    final ok = await ref
        .read(importMappedSheetProvider)
        .useStatementBalance(r.accountId!, r.comparison!);
    if (!mounted) return;
    setState(() {
      _applied = ok;
      _note = ok
          ? 'Balance updated.'
          : 'The account has a newer balance, so it was left as it is.';
    });
  }

  static String _m(int minor) => formatMoney(Money(minor));

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final c = r.comparison;
    final parts = [
      '${r.added} added',
      if (r.merged > 0) '${r.merged} matched',
      if (r.review > 0) '${r.review} to review',
      if (r.skipped > 0) '${r.skipped} skipped',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Imported', style: text.titleMedium),
          Text(parts.join(', '), key: const Key('result-counts')),
          if (c != null) ...[
            const Divider(height: 24),
            Text('Balance check', style: text.titleSmall),
            const SizedBox(height: 6),
            _line('Statement', _m(c.statementMinor)),
            _line('DhanKosh', c.appMinor == null ? 'unknown' : _m(c.appMinor!)),
            if (c.appMinor != null && c.matches)
              Text(
                'Matches.',
                key: const Key('result-matches'),
                style: text.bodyMedium?.copyWith(color: Colors.green),
              )
            else if (c.appMinor != null)
              _line(
                'Difference',
                '${c.differenceMinor! > 0 ? '+' : '-'}'
                    '${_m(c.differenceMinor!.abs())}',
                color: scheme.error,
                key: const Key('result-difference'),
              ),
            if (!r.addsUp && c.appMinor != null && !c.matches)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  "The statement's own balances don't add up, so its closing "
                  "balance can't be used. Check the columns.",
                  key: const Key('result-untrusted'),
                  style: text.bodySmall,
                ),
              ),
            if (r.canSetBalance && !_applied)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton(
                  key: const Key('result-use-balance'),
                  onPressed: _use,
                  child: const Text('Use statement balance'),
                ),
              ),
            if (_note != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _note!,
                  key: const Key('result-note'),
                  style: text.bodySmall,
                ),
              ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('result-done'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String k, String v, {Color? color, Key? key}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          key: key,
          children: [
            Expanded(child: Text(k)),
            Text(
              v,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}
