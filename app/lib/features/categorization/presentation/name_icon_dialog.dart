import 'package:flutter/material.dart';
import 'package:hisaab/features/categorization/presentation/category_icons.dart';

/// Asks for a name and an icon for a new category or sub-category (FR-09-33).
/// Returns null on cancel or an empty name.
Future<({String name, String icon})?> showNameIconDialog(
  BuildContext context, {
  required String title,
  Key? nameKey,
  Key? addKey,
}) {
  final c = TextEditingController();
  var icon = 'label';
  return showDialog<({String name, String icon})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: nameKey ?? const Key('new_category_name'),
                controller: c,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Name'),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    key: const Key('icon_picker'),
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final e in CategoryIcons.pickable)
                        IconButton(
                          key: Key('icon_${e.key}'),
                          isSelected: e.key == icon,
                          tooltip: e.key.replaceAll('_', ' '),
                          icon: Icon(e.value),
                          onPressed: () => setState(() => icon = e.key),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: addKey ?? const Key('new_category_add'),
            onPressed: () {
              final name = c.text.trim();
              Navigator.pop(
                ctx,
                name.isEmpty ? null : (name: name, icon: icon),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
}
