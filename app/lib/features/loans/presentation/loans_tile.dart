import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry to Loans (route `/loans`).
class LoansTile extends StatelessWidget {
  /// Creates the tile.
  const LoansTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('loans-tile'),
        badge: AppIcons.loans,
        title: t('Loans'),
        subtitle: t('Lent and borrowed, EMIs'),
        onTap: () => context.push('/loans'),
      );
}
