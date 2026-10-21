import 'package:flutter/material.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:parser_core/parser_core.dart';

/// Readable type name.
String accountTypeLabel(AccountType t) => switch (t) {
      AccountType.nre => 'NRE',
      AccountType.nro => 'NRO',
      AccountType.fd => 'FD',
      AccountType.rd => 'RD',
      AccountType.ppf => 'PPF',
      AccountType.creditCard => 'Credit card',
      AccountType.debitCard => 'Debit card',
      AccountType.prepaidCard => 'Prepaid card',
      _ => '${t.name[0].toUpperCase()}${t.name.substring(1)}',
    };

/// One account row: label, type, balance (`~` when estimated, FR-13-07).
class AccountTile extends StatelessWidget {
  const AccountTile({
    required this.item,
    required this.masked,
    this.onTap,
    super.key,
  });

  final AccountWithActivity item;
  final bool masked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = item.account;
    final bal = item.currentBalanceMinor;
    final isCard = a.kind == AccountKind.card;
    return AppCard(
      key: Key('account_${a.id}'),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.label, style: theme.textTheme.titleMedium),
                Text(
                  a.accountType == null
                      ? (isCard ? 'Card' : 'Account')
                      : accountTypeLabel(a.accountType!),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                bal == null
                    ? '-'
                    : '${item.balanceIsEstimated ? '~' : ''}'
                        '${formatAmount(bal, masked: masked)}',
                key: Key('account_balance_${a.id}'),
                style: theme.textTheme.titleMedium,
              ),
              if (isCard && bal != null)
                Text('limit left', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
