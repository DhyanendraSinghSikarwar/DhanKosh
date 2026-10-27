import 'package:flutter/material.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/theming_customisation/domain/section_layout.dart';
import 'package:hisaab/features/theming_customisation/presentation/section_layout_editor.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Customise card: pick Home, Analysis or Portfolio, then edit its sections
/// (FR-28-15).
class SectionLayoutCard extends StatefulWidget {
  /// Creates the card.
  const SectionLayoutCard({super.key});

  @override
  State<SectionLayoutCard> createState() => _SectionLayoutCardState();
}

class _SectionLayoutCardState extends State<SectionLayoutCard> {
  String _screen = ScreenIds.home;

  @override
  Widget build(BuildContext context) => AppCard(
        key: const Key('section-layout-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              key: const Key('layout-screen'),
              showSelectedIcon: false,
              segments: [
                for (final id in ScreenIds.all)
                  ButtonSegment(
                    value: id,
                    label: Text(t(ScreenIds.label(id))),
                  ),
              ],
              selected: {_screen},
              onSelectionChanged: (v) => setState(() => _screen = v.first),
            ),
            const SizedBox(height: 8),
            SectionLayoutEditor(screenId: _screen),
          ],
        ),
      );
}
