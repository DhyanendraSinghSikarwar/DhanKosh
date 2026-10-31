import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
        title: 'Loans',
        subtitle: 'Lent and borrowed, EMIs',
        onTap: () => context.push('/loans'),
      );
}
