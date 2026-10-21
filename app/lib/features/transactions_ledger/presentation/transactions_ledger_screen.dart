import 'package:flutter/material.dart';

/// Placeholder screen for: Transactions Ledger.
class TransactionsLedgerScreen extends StatelessWidget {
  const TransactionsLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
          child: Text('Transactions Ledger placeholder',
              key: Key('transactions_ledger_placeholder'))),
    );
  }
}
