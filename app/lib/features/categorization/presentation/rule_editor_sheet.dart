import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:hisaab/features/categorization/presentation/category_sheet.dart';
import 'package:parser_core/parser_core.dart';

/// Opens the rule editor; [existing] edits a manual rule.
Future<void> showRuleEditor(BuildContext context, {MerchantRule? existing}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => RuleEditorSheet(existing: existing),
    );

/// Rule editor: text, Exact/Contains, category, live count of past rows and
/// "Also apply to past transactions" (FR-09-08, FR-09-09).
class RuleEditorSheet extends ConsumerStatefulWidget {
  /// Creates the editor.
  const RuleEditorSheet({this.existing, super.key});

  /// Rule being edited, or null for a new one.
  final MerchantRule? existing;

  @override
  ConsumerState<RuleEditorSheet> createState() => _State();
}

class _State extends ConsumerState<RuleEditorSheet> {
  late final TextEditingController _key =
      TextEditingController(text: widget.existing?.merchantKey ?? '');
  late RuleMatch _match = widget.existing?.matchType ?? RuleMatch.exact;
  late Category _cat = widget.existing?.category ?? Category.other;
  late int? _custom = widget.existing?.customCategoryId;
  bool _apply = false;
  int _count = 0;

  MerchantRule? get _rule {
    final k = _key.text.trim().toLowerCase();
    if (k.length < MerchantRule.minKey) return null;
    return MerchantRule(
      merchantKey: k,
      category: _cat,
      customCategoryId: _custom,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      matchType: _match,
      manual: true,
    );
  }

  Future<void> _recount() async {
    final r = _rule;
    final n = r == null
        ? 0
        : await ref.read(transactionRepositoryProvider).countRuleMatches(r);
    if (mounted) setState(() => _count = n);
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final c = await showCategorySheet(
      context,
      current: _cat,
      currentCustomId: _custom,
    );
    if (c == null || !mounted) return;
    setState(() {
      _cat = c.category;
      _custom = c.customCategoryId;
    });
  }

  Future<void> _save() async {
    final r = _rule;
    if (r == null) return;
    await ref.read(categoryRepositoryProvider).saveManualRule(
          r,
          previousKey: widget.existing?.merchantKey,
        );
    if (_apply) {
      await ref.read(transactionRepositoryProvider).applyRuleToPast(r);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final valid = _rule != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('rule_key'),
            controller: _key,
            decoration: const InputDecoration(labelText: 'Merchant or text'),
            onChanged: (_) {
              setState(() {});
              unawaited(_recount());
            },
          ),
          const SizedBox(height: 12),
          SegmentedButton<RuleMatch>(
            key: const Key('rule_match'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: RuleMatch.exact, label: Text('Is')),
              ButtonSegment(value: RuleMatch.contains, label: Text('Contains')),
            ],
            selected: {_match},
            onSelectionChanged: (s) {
              setState(() => _match = s.first);
              unawaited(_recount());
            },
          ),
          ListTile(
            key: const Key('rule_category'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Category'),
            trailing: Text(_cat.label),
            onTap: _pick,
          ),
          Text(
            'Would change $_count past transactions',
            key: const Key('rule_count'),
          ),
          SwitchListTile(
            key: const Key('rule_apply'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Also apply to past transactions'),
            value: _apply,
            onChanged: (v) => setState(() => _apply = v),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('rule_save'),
              onPressed: valid ? _save : null,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
