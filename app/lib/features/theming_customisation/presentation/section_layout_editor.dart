import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/layout_providers.dart';
import 'package:hisaab/features/theming_customisation/domain/section_layout.dart';

/// Show, hide and reorder the sections of one screen, with presets for Home
/// (FR-28-15, FR-28-19). Shared by Customise and Home edit mode.
class SectionLayoutEditor extends ConsumerWidget {
  /// Creates the editor for [screenId].
  const SectionLayoutEditor({required this.screenId, super.key});

  /// `home`, `analytics` or `portfolio`.
  final String screenId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(sectionLayoutProvider(screenId)).value ??
        SectionLayout.defaults(screenId);
    final save = ref.read(sectionLayoutWriterProvider);
    return Column(
      key: Key('layout-editor-$screenId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (screenId == ScreenIds.home)
          Wrap(
            spacing: 8,
            children: [
              for (final p in SectionLayout.presets)
                ActionChip(
                  key: Key('preset-${p.name}'),
                  label: Text(p.name),
                  onPressed: () => save(
                    screenId,
                    SectionLayout.apply(screenId, p.shown),
                  ),
                ),
            ],
          ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (a, b) =>
              save(screenId, SectionLayout.reorder(slots, a, b)),
          children: [
            for (final (i, s) in slots.indexed)
              SwitchListTile(
                key: Key('section-${s.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(s.label),
                secondary: ReorderableDragStartListener(
                  index: i,
                  child: const Icon(Icons.drag_handle),
                ),
                value: s.visible,
                onChanged: (v) => save(
                  screenId,
                  SectionLayout.setVisible(slots, s.id, visible: v),
                ),
              ),
          ],
        ),
        TextButton(
          key: Key('layout-reset-$screenId'),
          onPressed: () => ref.read(sectionLayoutResetProvider)(screenId),
          child: const Text('Reset'),
        ),
      ],
    );
  }
}
