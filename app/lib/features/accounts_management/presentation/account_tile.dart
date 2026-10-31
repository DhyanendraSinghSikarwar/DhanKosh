import 'package:flutter/material.dart';
import 'package:hisaab/features/accounts_management/domain/account.dart';
import 'package:hisaab/features/categorization/domain/brand_logos.dart';
import 'package:hisaab/shared/providers/amount_masking.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
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

AppIcon _badge(Account a) => switch (a.accountType) {
      AccountType.wallet || AccountType.prepaidCard => AppIcons.wallet,
      AccountType.creditCard => AppIcons.cards,
      _ => a.kind == AccountKind.card ? AppIcons.cards : AppIcons.accounts,
    };

String _source(Account a) =>
    a.manualBalanceMinor != null && a.latestBalanceMinor == null
        ? 'Manual'
        : a.latestBalanceMinor != null || a.availableLimitMinor != null
            ? 'Synced'
            : 'No balance yet';

/// One account row: label, type, balance (`~` when estimated, FR-13-07).
class AccountTile extends StatelessWidget {
  const AccountTile({
    required this.item,
    required this.masked,
    this.onTap,
    this.cardDueMinor,
    this.usedPercent,
    super.key,
  });

  /// Credit card due (paise); shown instead of the limit left.
  final int? cardDueMinor;

  /// Credit card limit used, 0..100.
  final int? usedPercent;

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
          else if (a.colorArgb == null && a.cardNetwork == null)
            IconBadge(
              _badge(a),
              key: Key('account_avatar_${a.id}'),
              size: 36,
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        a.accountType == null
                            ? (isCard ? 'Card' : 'Account')
                            : accountTypeLabel(a.accountType!),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        ' · ${_source(a)}'
                        '${usedPercent == null ? '' : ' · $usedPercent% used'}',
                        key: Key('account_source_${a.id}'),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                Container(
                  key: Key(
                    a.usage == AccountUsage.business
                        ? 'account_business_${a.id}'
                        : 'account_personal_${a.id}',
                  ),
                  margin: const EdgeInsets.only(top: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: a.usage == AccountUsage.business
                        ? theme.colorScheme.tertiaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    a.usage == AccountUsage.business ? 'Business' : 'Personal',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                cardDueMinor != null
                    ? formatAmount(cardDueMinor!, masked: masked)
                    : bal == null
                        ? '-'
                        : '${item.balanceIsEstimated ? '~' : ''}'
                            '${formatAmount(bal, masked: masked)}',
                key: Key('account_balance_${a.id}'),
                style: theme.textTheme.titleMedium,
              ),
              if (cardDueMinor != null)
                Text('due', style: theme.textTheme.bodySmall)
              else if (isCard && bal != null)
                Text('limit left', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
