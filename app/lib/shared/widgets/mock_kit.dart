import 'package:flutter/material.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';
import 'package:hisaab/shared/widgets/section_label.dart';

/// Text sizes of the approved mockups: big 30, mid 19, body 14, small 12.
abstract final class MockText {
  /// Hero number (30, w650).
  static TextStyle big(BuildContext context, {Color? color}) => TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      );

  /// Secondary number (19, w600).
  static TextStyle mid(BuildContext context, {Color? color}) => TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      );

  /// Row text (14).
  static TextStyle body(BuildContext context, {Color? color}) => TextStyle(
        fontSize: 14,
        color: color ?? Theme.of(context).colorScheme.onSurface,
      );

  /// Muted 12.
  static TextStyle small(BuildContext context, {Color? color}) => TextStyle(
        fontSize: 12,
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      );
}

/// Card header: [SectionLabel] on the left, optional [trailing] on the right.
class CardHeader extends StatelessWidget {
  /// Creates a header.
  const CardHeader(this.label, {this.trailing, this.info, super.key});

  /// Label text (shown upper case).
  final String label;

  /// Right-hand widget.
  final Widget? trailing;

  /// Optional "i" button.
  final Widget? info;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SectionLabel(label),
        if (info != null) ...[const SizedBox(width: 6), info!],
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Round "i" button of the mockups; toggles a note.
class InfoDot extends StatelessWidget {
  /// Creates the button.
  const InfoDot({required this.onTap, super.key});

  /// Tap handler.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkResponse(
      onTap: onTap,
      radius: 16,
      child: Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c),
        ),
        child: Text('i', style: TextStyle(fontSize: 11, color: c)),
      ),
    );
  }
}

/// Text link in the primary colour ("More ›").
class MoreLink extends StatelessWidget {
  /// Creates a link.
  const MoreLink(this.text, {required this.onTap, super.key});

  /// Link text.
  final String text;

  /// Tap handler.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// One legend entry: coloured dot and label.
class LegendItem {
  /// Creates an entry.
  const LegendItem(this.label, this.color);

  /// Text.
  final String label;

  /// Dot colour.
  final Color color;
}

/// Wrapping legend of round dots (12 px muted text).
class LegendRow extends StatelessWidget {
  /// Creates a legend.
  const LegendRow(this.items, {super.key});

  /// Entries.
  final List<LegendItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final i in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: i.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(i.label, style: MockText.small(context)),
            ],
          ),
      ],
    );
  }
}

/// Row of the mockups: [IconBadge], title and muted subtitle, amount on the
/// right (19 px), optional bottom divider.
class IconAmountRow extends StatelessWidget {
  /// Creates a row.
  const IconAmountRow({
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.amount,
    this.trailing,
    this.amountKey,
    this.divider = false,
    this.amountSize = 19,
    super.key,
  });

  /// Title.
  final String title;

  /// Muted line under the title.
  final String? subtitle;

  /// Coloured badge.
  final AppIcon? icon;

  /// Custom leading widget (instead of [icon]).
  final Widget? leading;

  /// Amount text (right).
  final String? amount;

  /// Widget after the amount.
  final Widget? trailing;

  /// Key of the amount text.
  final Key? amountKey;

  /// Line under the row.
  final bool divider;

  /// Amount font size.
  final double amountSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: divider
            ? Border(bottom: BorderSide(color: scheme.outlineVariant))
            : null,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 11)],
          if (leading == null && icon != null) ...[
            IconBadge(icon!),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MockText.body(context),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MockText.small(context),
                  ),
              ],
            ),
          ),
          if (amount != null) ...[
            const SizedBox(width: 8),
            Text(
              amount!,
              key: amountKey,
              style: MockText.mid(context).copyWith(fontSize: amountSize),
            ),
          ],
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
