import 'package:flutter/material.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/categorization/domain/brand_logos.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/brand_logo.dart';
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
          if (a.colorArgb == null &&
              a.cardNetwork == null &&
              BrandLogos.bank(a.bankName) != null)
            BrandLogo(
              key: Key('account_avatar_${a.id}'),
              logoKey: BrandLogos.bank(a.bankName),
              label: a.bankName,
              size: 32,
            )
          else
            CircleAvatar(
              key: Key('account_avatar_${a.id}'),
              radius: 16,
              backgroundColor: a.colorArgb == null
                  ? theme.colorScheme.surfaceContainerHighest
                  : Color(a.colorArgb!),
              child: Text(
                a.cardNetwork == null
                    ? a.bankName.characters.first.toUpperCase()
                    : a.cardNetwork!.name.substring(0, 2).toUpperCase(),
                style: theme.textTheme.labelSmall,
              ),
            ),
          const SizedBox(width: 12),
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
                if (a.usage == AccountUsage.business)
                  Container(
                    key: Key('account_business_${a.id}'),
                    margin: const EdgeInsets.only(top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Business', style: theme.textTheme.labelSmall),
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
