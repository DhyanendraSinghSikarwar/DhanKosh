import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/categorization/domain/merchant_rule.dart';
import 'package:hisaab/features/categorization/presentation/rule_editor_sheet.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

final _rulesProvider = StreamProvider<List<MerchantRule>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchRules(),
);

/// More > Rules: "Your rules" and "Learned", edit, remove with Undo, add
/// (FR-09-08, FR-09-09, FR-09-12).
class RulesScreen extends ConsumerWidget {
  /// Creates the screen.
  const RulesScreen({super.key});

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    MerchantRule r,
  ) async {
    final repo = ref.read(categoryRepositoryProvider);
    await repo.deleteRule(r.merchantKey);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Rule removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              if (r.manual) {
                await repo.saveManualRule(r);
              } else {
                await repo.learn(
                  r.merchantKey,
                  r.category,
                  at: r.updatedAt,
                );
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rules = ref.watch(_rulesProvider).value;
    final yours = [
      for (final r in rules ?? <MerchantRule>[])
        if (r.manual) r,
    ];
    final learned = [
      for (final r in rules ?? <MerchantRule>[])
        if (!r.manual) r,
    ];
    Widget section(String title, List<MerchantRule> list) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Text(title, style: theme.textTheme.titleSmall),
            ),
            for (final r in list)
              ListTile(
                key: Key('rule_${r.merchantKey}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.label_outline),
                title: Text(r.merchantKey),
                subtitle: Text(
                  '${r.matchType == RuleMatch.exact ? 'Is' : 'Contains'}'
                  ' -> ${r.category.label}'
                  '${r.subcategory == null ? '' : ' > ${r.subcategory}'}',
                ),
                onTap: r.manual
                    ? () => showRuleEditor(context, existing: r)
                    : null,
                trailing: IconButton(
                  key: Key('rule_remove_${r.merchantKey}'),
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _remove(context, ref, r),
                ),
              ),
          ],
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Rules')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('rule_add'),
        onPressed: () => showRuleEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add rule'),
      ),
      body: rules == null
          ? const Center(child: CircularProgressIndicator())
          : rules.isEmpty
              ? const EmptyState(
                  key: Key('rules_empty'),
                  icon: Icons.rule_outlined,
                  title: 'No rules yet',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  children: [
                    if (yours.isNotEmpty)
                      section('Your rules · ${yours.length}', yours),
                    if (learned.isNotEmpty)
                      section('Learned · ${learned.length}', learned),
                  ],
                ),
    );
  }
}
