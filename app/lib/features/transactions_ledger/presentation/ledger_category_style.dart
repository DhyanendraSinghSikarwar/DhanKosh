import 'package:flutter/material.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:parser_core/parser_core.dart' show Category;

/// Icon and tint of a category for round row badges.
({IconData icon, Color color}) categoryStyle(Category c) => switch (c) {
      Category.food => (icon: Icons.restaurant, color: AppIcons.amber),
      Category.groceries => (icon: Icons.shopping_basket, color: AppIcons.olive),
      Category.transport => (icon: Icons.directions_car, color: AppIcons.teal),
      Category.fuel => (icon: Icons.local_gas_station, color: AppIcons.red),
      Category.shopping => (icon: Icons.shopping_bag, color: AppIcons.violet),
      Category.bills => (icon: Icons.bolt, color: AppIcons.amber),
      Category.entertainment => (icon: Icons.movie, color: AppIcons.violet),
      Category.travel => (icon: Icons.flight, color: AppIcons.blue),
      Category.health => (icon: Icons.favorite, color: AppIcons.teal),
      Category.education => (icon: Icons.school, color: AppIcons.blue),
      Category.rent => (icon: Icons.home, color: AppIcons.mint),
      Category.insurance => (icon: Icons.shield, color: AppIcons.amber),
      Category.emiLoan => (icon: Icons.swap_horiz, color: AppIcons.amber),
      Category.investment => (icon: Icons.trending_up, color: AppIcons.mint),
      Category.cash => (icon: Icons.payments, color: AppIcons.olive),
      Category.subscriptions => (icon: Icons.autorenew, color: AppIcons.violet),
      Category.personalCare => (icon: Icons.spa, color: AppIcons.red),
      Category.household => (icon: Icons.chair, color: AppIcons.goldTone),
      Category.gifts => (icon: Icons.card_giftcard, color: AppIcons.red),
      Category.donations => (icon: Icons.volunteer_activism, color: AppIcons.red),
      Category.taxes => (icon: Icons.receipt_long, color: AppIcons.violet),
      Category.fees => (icon: Icons.account_balance, color: AppIcons.blue),
      Category.salary => (icon: Icons.work, color: AppIcons.mint),
      Category.income => (icon: Icons.south_west, color: AppIcons.mint),
      Category.refund => (icon: Icons.undo, color: AppIcons.mint),
      Category.transfer => (icon: Icons.sync_alt, color: AppIcons.blue),
      Category.other => (icon: Icons.category, color: AppIcons.blue),
    };

/// Donut / bar colours by rank, as in the approved mock; ranks past 6 grey.
const List<Color> rankColors = [
  AppIcons.mint,
  AppIcons.blue,
  AppIcons.amber,
  AppIcons.violet,
  AppIcons.red,
  AppIcons.teal,
];

/// Colour of the item at [rank] (0-based).
Color rankColor(BuildContext context, int rank) => rank < rankColors.length
    ? rankColors[rank]
    : Theme.of(context).colorScheme.outline;

/// Compact amount for the donut centre: 1.1L, 2.4Cr, 12K.
String compactAmount(int minor, {required bool masked}) {
  if (masked) return '••••';
  final r = minor / 100;
  String f(double v, String s) =>
      '${v.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}$s';
  if (r >= 10000000) return f(r / 10000000, 'Cr');
  if (r >= 100000) return f(r / 100000, 'L');
  if (r >= 1000) return f(r / 1000, 'K');
  return r.toStringAsFixed(0);
}
