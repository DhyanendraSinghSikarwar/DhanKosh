import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/categorization/domain/category_choice.dart';
import 'package:hisaab/features/categorization/domain/custom_category.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:hisaab/features/categorization/presentation/category_icons.dart';
import 'package:hisaab/features/categorization/presentation/name_icon_dialog.dart';
import 'package:parser_core/parser_core.dart';

final _customCategoriesProvider = StreamProvider<List<CustomCategory>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchCustomCategories(),
);

/// Opens the picker; null when dismissed.
Future<CategoryChoice?> showCategorySheet(
  BuildContext context, {
  required Category current,
  int? currentCustomId,
  String? ruleKey,
}) =>
    showModalBottomSheet<CategoryChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CategorySheet(
        current: current,
        currentCustomId: currentCustomId,
        ruleKey: ruleKey,
      ),
    );

/// Category picker: built-in taxonomy, custom categories, and "always use
/// for this merchant" with apply-to-past (FR-09-05, FR-09-08, FR-09-09,
/// FR-09-13, FR-09-16).
class CategorySheet extends ConsumerStatefulWidget {
  /// Creates the sheet. [ruleKey] is the merchant key; null hides rule options.
  const CategorySheet({
    required this.current,
    this.currentCustomId,
    this.ruleKey,
    super.key,
  });

  /// Category now on the row.
  final Category current;

  /// Custom category now on the row.
  final int? currentCustomId;

  /// Merchant key for the rule (see `MerchantRule.keyOf`).
  final String? ruleKey;

  @override
  ConsumerState<CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<CategorySheet> {
  late Category _cat = widget.current;
  late int? _custom = widget.currentCustomId;
  bool _saveRule = false;
  bool _applyPast = false;
  String _search = '';

  MerchantRule _rule() => MerchantRule(
        merchantKey: widget.ruleKey!,
        category: _cat,
        customCategoryId: _custom,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        manual: true,
      );

  Future<void> _newCategory() async {
    final made = await showNameIconDialog(context, title: 'New category');
    if (made == null) return;
    final id = await ref.read(categoryRepositoryProvider).addCustomCategory(
          name: made.name,
          icon: made.icon,
          colorArgb: 0xFF607D8B,
        );
    if (mounted) {
      setState(() {
        _cat = Category.other;
        _custom = id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final customs = ref.watch(_customCategoriesProvider).value ?? const [];
    final q = _search.toLowerCase();
    final builtIn = [
      for (final c in Category.values)
        if (q.isEmpty || c.label.toLowerCase().contains(q)) c,
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const Key('category_search'),
                      onChanged: (v) => setState(() => _search = v),
                      decoration: const InputDecoration(
                        hintText: 'Search categories',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final c in builtIn)
                          ChoiceChip(
                            key: Key('cat_${c.name}'),
                            label: Text(c.label),
                            selected: _custom == null && _cat == c,
                            onSelected: (_) => setState(() {
                              _cat = c;
                              _custom = null;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your categories',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final c in customs)
                          ChoiceChip(
                            key: Key('custom_${c.id}'),
                            avatar: Icon(CategoryIcons.get(c.icon), size: 18),
                            label: Text(c.name),
                            selected: _custom == c.id,
                            onSelected: (_) => setState(() {
                              _cat = Category.other;
                              _custom = c.id;
                            }),
                          ),
                        ActionChip(
                          key: const Key('new_category'),
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text('New category'),
                          onPressed: _newCategory,
                        ),
                      ],
                    ),
                    if (widget.ruleKey != null) ...[
                      SwitchListTile(
                        key: const Key('rule_save'),
                        contentPadding: EdgeInsets.zero,
                        title: Text('Always use for “${widget.ruleKey}”'),
                        value: _saveRule,
                        onChanged: (v) => setState(() {
                          _saveRule = v;
                          if (!v) _applyPast = false;
                        }),
                      ),
                      if (_saveRule)
                        FutureBuilder<int>(
                          future: ref
                              .read(transactionRepositoryProvider)
                              .countRuleMatches(_rule()),
                          builder: (context, snap) => CheckboxListTile(
                            key: const Key('rule_past'),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              'Also apply to past (${snap.data ?? 0})',
                            ),
                            value: _applyPast,
                            onChanged: (v) =>
                                setState(() => _applyPast = v ?? false),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('category_save'),
                onPressed: () => Navigator.pop(
                  context,
                  CategoryChoice(
                    _cat,
                    customCategoryId: _custom,
                    saveRule: _saveRule,
                    applyToPast: _applyPast,
                  ),
                ),
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
