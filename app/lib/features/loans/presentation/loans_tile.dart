import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// More-tab entry to Loans (route `/loans`).
class LoansTile extends StatelessWidget {
  /// Creates the tile.
  const LoansTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('loans-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.account_balance_outlined),
        title: const Text('Loans'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/loans'),
      );
}
