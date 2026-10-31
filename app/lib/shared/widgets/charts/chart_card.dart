import 'package:flutter/material.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/section_label.dart';

/// Chart card: filled [AppCard] with a `SectionLabel` header, an optional
/// (i) tip that opens a small note, and an optional trailing widget.
class ChartCard extends StatefulWidget {
  /// Creates the card.
  const ChartCard({
    required this.label,
    required this.child,
    this.tip,
    this.tipKey,
    this.trailing,
    this.cardKey,
    super.key,
  });

  /// Header text (upper-cased by [SectionLabel]).
  final String label;

  /// Card body.
  final Widget child;

  /// Text opened by the (i) button.
  final String? tip;

  /// Key of the tip text.
  final Key? tipKey;

  /// Widget at the right end of the header.
  final Widget? trailing;

  /// Key of the card itself.
  final Key? cardKey;

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        key: widget.cardKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SectionLabel(widget.label),
                if (widget.tip != null) ...[
                  const SizedBox(width: 8),
                  InkResponse(
                    key: Key('info-${widget.label}'),
                    radius: 16,
                    onTap: () => setState(() => _open = !_open),
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.onSurfaceVariant),
                      ),
                      child: Text(
                        'i',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
            if (_open && widget.tip != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.tip!,
                  key: widget.tipKey,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            widget.child,
          ],
        ),
      ),
    );
  }
}
