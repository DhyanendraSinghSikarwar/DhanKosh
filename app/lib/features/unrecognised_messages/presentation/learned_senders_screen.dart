import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/unrecognised_providers.dart';
import 'package:hisaab/features/unrecognised_messages/domain/unrecognised_message.dart';
import 'package:hisaab/features/unrecognised_messages/presentation/unrecognised_providers.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/empty_state.dart';

/// Senders the user taught the app, or switched off, each with Forget
/// (FR-38-09).
class LearnedSendersScreen extends ConsumerWidget {
  /// Creates the screen.
  const LearnedSendersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(senderPrefsProvider);
    final repo = ref.read(unrecognisedRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Learned senders')),
      body: prefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load',
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                key: Key('senders_empty'),
                icon: Icons.school_outlined,
                title: 'No learned senders',
                hint: 'Add a message from a new sender once and its later '
                    'messages are offered to you.',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final p in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        key: Key('sender_${p.senderKey}'),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_title(p.senderKey)),
                          subtitle: Text(_subtitle(p)),
                          trailing: TextButton(
                            key: Key('forget_${p.senderKey}'),
                            onPressed: () => repo.forget(p.senderKey),
                            child: const Text('Forget'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  static String _title(String key) =>
      key.startsWith('app:') ? key.substring(4) : key;

  static String _subtitle(SenderPref p) {
    if (p.ignored) return 'Switched off';
    final acct = p.last4 == null
        ? 'No account remembered'
        : '${p.bankName ?? 'Account'} ••${p.last4}';
    return 'Offered at any score · $acct';
  }
}
