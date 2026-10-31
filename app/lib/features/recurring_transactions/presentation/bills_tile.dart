import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/settings_row.dart';

/// More-tab entry to Bills & insurance (route `/bills`). Also usable from
/// Home as an Upcoming "Calendar" action.
class BillsTile extends StatelessWidget {
  /// Creates the tile.
  const BillsTile({super.key});

  @override
  Widget build(BuildContext context) => SettingsRow(
        key: const Key('bills-tile'),
        badge: AppIcons.bills,
        title: 'Bills and recurring',
        subtitle: 'Calendar of upcoming payments',
        onTap: () => context.push('/bills'),
      );
}
