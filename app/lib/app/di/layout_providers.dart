import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/theming_customisation/domain/section_layout.dart';

// Section layout store (F-28, FR-28-15..21): settings-backed
// `[{id, visible, order}]` per screen id ('home', 'analytics', 'portfolio').

/// Slots of a screen id in saved order; defaults until the store loads.
/// Analysis and Portfolio read the visible ids (FR-28-20).
// ignore: specify_nonobvious_property_types
final sectionLayoutProvider =
    StreamProvider.family<List<SectionSlot>, String>((ref, screenId) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo
      .watch(SectionLayout.key(screenId))
      .map((saved) => SectionLayout.resolve(screenId, saved));
});

/// Visible section ids of a screen id, in order; defaults while loading.
// ignore: specify_nonobvious_property_types
final visibleSectionsProvider = Provider.family<List<String>, String>(
  (ref, screenId) => SectionLayout.visibleIds(
    ref.watch(sectionLayoutProvider(screenId)).value ??
        SectionLayout.defaults(screenId),
  ),
);

/// Saves a layout for a screen id.
final sectionLayoutWriterProvider =
    Provider<Future<void> Function(String, List<SectionSlot>)>(
  (ref) => (screenId, slots) => ref
      .read(settingsRepositoryProvider)
      .write(SectionLayout.key(screenId), SectionLayout.encode(slots)),
);

/// Back to defaults for a screen id (FR-28-18).
final sectionLayoutResetProvider = Provider<Future<void> Function(String)>(
  (ref) => (screenId) =>
      ref.read(settingsRepositoryProvider).remove(SectionLayout.key(screenId)),
);
