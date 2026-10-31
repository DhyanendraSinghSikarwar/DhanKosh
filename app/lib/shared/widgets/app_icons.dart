import 'package:flutter/material.dart';

/// A coloured icon: Material glyph plus the tint it is drawn with.
@immutable
class AppIcon {
  /// Creates an icon spec.
  const AppIcon(this.icon, this.color);

  /// Glyph.
  final IconData icon;

  /// Tint, also used (faded) as the badge background.
  final Color color;
}

/// The app's coloured icon set (colours match the screen mockups).
abstract final class AppIcons {
  static const Color mint = Color(0xFF8FD19E);
  static const Color blue = Color(0xFF7FA9E6);
  static const Color amber = Color(0xFFE3B45F);
  static const Color violet = Color(0xFFB39DDB);
  static const Color red = Color(0xFFE8837C);
  static const Color teal = Color(0xFF5FC4C4);
  static const Color olive = Color(0xFF9AB87A);
  static const Color goldTone = Color(0xFFD9B36C);

  // Manage and capture
  static const accounts = AppIcon(Icons.account_balance_outlined, blue);
  static const book = AppIcon(Icons.menu_book_outlined, amber);
  static const sms = AppIcon(Icons.sms_outlined, mint);
  static const pasteSms = AppIcon(Icons.content_paste_outlined, teal);
  static const history = AppIcon(Icons.history_toggle_off_outlined, violet);
  static const senders = AppIcon(Icons.badge_outlined, blue);
  static const email = AppIcon(Icons.mail_outline, red);
  static const notifications =
      AppIcon(Icons.notifications_active_outlined, amber);
  static const statements = AppIcon(Icons.description_outlined, teal);
  static const profile = AppIcon(Icons.person_outline, mint);

  // Money tools
  static const bills = AppIcon(Icons.event_repeat_outlined, red);
  static const goals = AppIcon(Icons.flag_outlined, mint);
  static const loans = AppIcon(Icons.swap_horiz_rounded, amber);
  static const tax = AppIcon(Icons.receipt_long_outlined, violet);
  static const rules = AppIcon(Icons.auto_awesome_outlined, amber);
  static const forex = AppIcon(Icons.currency_exchange_outlined, teal);
  static const news = AppIcon(Icons.newspaper_outlined, blue);
  static const budgets = AppIcon(Icons.account_balance_wallet_outlined, mint);
  static const cards = AppIcon(Icons.credit_card_outlined, violet);
  static const insurance = AppIcon(Icons.shield_outlined, amber);
  static const income = AppIcon(Icons.south_west, mint);
  static const insight = AppIcon(Icons.lightbulb_outline, amber);

  // Alerts, appearance, privacy, data, about
  static const alerts = AppIcon(Icons.alarm_outlined, amber);
  static const activity = AppIcon(Icons.history_outlined, blue);
  static const diagnostics = AppIcon(Icons.build_circle_outlined, olive);
  static const customise = AppIcon(Icons.palette_outlined, violet);
  static const language = AppIcon(Icons.language_outlined, teal);
  static const security = AppIcon(Icons.lock_outline, red);
  static const hideAmounts = AppIcon(Icons.visibility_off_outlined, blue);
  static const backup = AppIcon(Icons.cloud_upload_outlined, mint);
  static const sample = AppIcon(Icons.science_outlined, olive);
  static const erase = AppIcon(Icons.delete_outline, red);
  static const support = AppIcon(Icons.favorite_outline, red);
  static const updates = AppIcon(Icons.system_update_outlined, mint);

  // Asset classes
  static const stocks = AppIcon(Icons.show_chart_rounded, mint);
  static const mutualFunds = AppIcon(Icons.pie_chart_outline_rounded, blue);
  static const nps = AppIcon(Icons.elderly_outlined, violet);
  static const epfo = AppIcon(Icons.savings_outlined, amber);
  static const sukanya = AppIcon(Icons.family_restroom_outlined, red);
  static const ppf = AppIcon(Icons.account_balance_outlined, teal);
  static const fixedDeposit = AppIcon(Icons.lock_clock_outlined, olive);
  static const gold = AppIcon(Icons.diamond_outlined, goldTone);
  static const wallet = AppIcon(Icons.account_balance_wallet_outlined, violet);
  static const cash = AppIcon(Icons.payments_outlined, olive);
}

/// Rounded tinted square holding a coloured [AppIcon].
class IconBadge extends StatelessWidget {
  /// Creates a badge.
  const IconBadge(this.spec, {this.size = 40, super.key});

  /// Icon and tint.
  final AppIcon spec;

  /// Badge edge length.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(spec.icon, color: spec.color, size: size * 0.55),
    );
  }
}
