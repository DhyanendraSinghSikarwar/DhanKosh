import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// More-tab entry for "Market news" (F-31), composed in `app/router.dart`.
class NewsTile extends StatelessWidget {
  /// Creates the tile.
  const NewsTile({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('news-tile'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.newspaper_outlined),
        title: const Text('Market news'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/news'),
      );
}
