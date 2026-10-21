import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// More-tab entry to Bills & insurance (route `/bills`). Also usable from
/// Home as an Upcoming "Calendar" action.
class BillsTile extends StatelessWidget {
  /// Creates the tile.
  const BillsTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('bills-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event_repeat_outlined),
        title: const Text('Bills & insurance'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/bills'),
      );
}
