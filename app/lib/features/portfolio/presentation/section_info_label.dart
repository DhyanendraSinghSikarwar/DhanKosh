import 'package:flutter/material.dart';
import 'package:hisaab/shared/widgets/section_label.dart';

/// [SectionLabel] with an info button that reveals a one-line [tip].
class SectionInfoLabel extends StatefulWidget {
  /// Creates the label.
  const SectionInfoLabel(this.text, {required this.tip, super.key});

  final String text;
  final String tip;

  @override
  State<SectionInfoLabel> createState() => _SectionInfoLabelState();
}

class _SectionInfoLabelState extends State<SectionInfoLabel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionLabel(widget.text),
            const SizedBox(width: 6),
            InkResponse(
              key: Key('info-${widget.text}'),
              radius: 14,
              onTap: () => setState(() => _open = !_open),
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (_open)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.tip,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
