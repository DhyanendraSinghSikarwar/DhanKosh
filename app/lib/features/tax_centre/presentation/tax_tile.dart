import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// More-tab entry to the Tax Centre; composed in `app/router.dart`.
class TaxTile extends StatelessWidget {
  /// Creates the tile.
  const TaxTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('tax-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.receipt_outlined),
        title: const Text('Tax Centre'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/tax'),
      );
}
