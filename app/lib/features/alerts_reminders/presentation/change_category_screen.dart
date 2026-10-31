import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/app/di/alerts_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/alerts_reminders/presentation/change_category_sheet.dart';
import 'package:parser_core/parser_core.dart';

/// Opened by the notification's More… button (`/alert-action?a=more&txId=`):
/// shows the Change category sheet over the transaction, saves the pick
/// through the alert handler, then returns home (FR-21-22).
class ChangeCategoryScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [txId].
  const ChangeCategoryScreen({required this.txId, super.key});

  /// Transaction to recategorise.
  final int txId;

  @override
  ConsumerState<ChangeCategoryScreen> createState() => _State();
}

class _State extends ConsumerState<ChangeCategoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final tx = await ref.read(transactionRepositoryProvider).byId(widget.txId);
    if (!mounted) return;
    if (tx == null) {
      context.go('/home');
      return;
    }
    final picked = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ChangeCategorySheet(
        current: tx.category,
        isCredit: tx.type == TransactionType.credit,
        onPick: (c) => Navigator.of(ctx).pop(c),
      ),
    );
    if (picked != null && picked != tx.category) {
      try {
        await ref.read(alertActionHandlerProvider).handle({
          'a': 'category',
          'txId': '${widget.txId}',
          'category': picked.name,
        });
      } on Object {
        // A failed save just returns home.
      }
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
