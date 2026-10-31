import 'package:flutter/material.dart';
import 'package:hisaab/features/alerts_reminders/domain/alert_rules.dart';
import 'package:parser_core/parser_core.dart';

const _palette = <Color>[
  Color(0xFFFF7043),
  Color(0xFF66BB6A),
  Color(0xFF42A5F5),
  Color(0xFFFFA726),
  Color(0xFFAB47BC),
  Color(0xFF26A69A),
  Color(0xFFEC407A),
  Color(0xFF5C6BC0),
  Color(0xFFEF5350),
];

/// Dot colour of [c] on the Change category sheet.
Color categoryDotColor(Category c) => _palette[c.index % _palette.length];

/// "Change category" sheet opened by the notification's More… button: every
/// category of the right type, a check on the current one; a tap picks it
/// (FR-21-22).
class ChangeCategorySheet extends StatelessWidget {
  /// Creates the sheet; [onPick] gets the chosen category.
  const ChangeCategorySheet({
    required this.current,
    required this.isCredit,
    required this.onPick,
    super.key,
  });

  /// Category now on the transaction.
  final Category current;

  /// Credit rows list the income-side categories.
  final bool isCredit;

  /// Called with the tapped category.
  final ValueChanged<Category> onPick;

  @override
  Widget build(BuildContext context) {
    final cats = AlertRules.categoriesFor(isCredit: isCredit, current: current);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Change category',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in cats)
                  ListTile(
                    key: Key('pick_${c.name}'),
                    leading: Icon(
                      Icons.circle,
                      size: 14,
                      color: categoryDotColor(c),
                    ),
                    title: Text(c.label),
                    trailing: c == current
                        ? const Icon(Icons.check, key: Key('current_check'))
                        : null,
                    onTap: () => onPick(c),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
