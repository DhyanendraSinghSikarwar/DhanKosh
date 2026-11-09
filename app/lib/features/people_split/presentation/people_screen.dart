import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/groups_people_providers.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

/// "Owes you ₹X" or "You owe ₹X" for a balance (FR-40-04).
String balanceText(int minor, {required bool masked}) {
  if (minor == 0) return 'Settled';
  final amt = formatAmount(minor.abs(), masked: masked, paise: false);
  return minor > 0 ? 'Owes you $amt' : 'You owe $amt';
}

/// People you share costs with (FR-40-04): who owes whom.
class PeopleScreen extends ConsumerWidget {
  /// Creates the screen.
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masked = ref.watch(hideAmountsProvider).value ?? true;
    final people = ref.watch(peopleProvider).value ?? const [];
    final net = people.fold<int>(0, (s, p) => s + p.balanceMinor);
    return Scaffold(
      appBar: AppBar(title: Text(t('People and splits'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('person_new'),
        icon: const Icon(Icons.person_add_alt),
        label: Text(t('Add person')),
        onPressed: () async {
          final name = await askPersonName(context, title: t('Add person'));
          if (name == null || name.isEmpty) return;
          final id = await ref.read(peopleRepositoryProvider).addPerson(name);
          if (context.mounted) await context.push('/people/$id');
        },
      ),
      body: people.isEmpty
          ? EmptyState(
              icon: Icons.group_outlined,
              title: t('No one yet'),
              hint: t('Split a payment from its detail screen.'),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    balanceText(net, masked: masked),
                    key: const Key('people_net'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                for (final p in people)
                  AppCard(
                    key: Key('person_${p.id}'),
                    margin: const EdgeInsets.only(bottom: 10),
                    onTap: () => context.push('/people/${p.id}'),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text(p.name.characters.first.toUpperCase()),
                      ),
                      title: Text(p.name),
                      subtitle:
                          Text(balanceText(p.balanceMinor, masked: masked)),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Asks for a person's name; null when cancelled.
Future<String?> askPersonName(
  BuildContext context, {
  required String title,
  String? initial,
}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const Key('person_name_field'),
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t('Cancel')),
        ),
        FilledButton(
          key: const Key('person_name_save'),
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: Text(t('Save')),
        ),
      ],
    ),
  );
}
