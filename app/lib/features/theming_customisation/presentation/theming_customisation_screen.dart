import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/appearance_providers.dart';
import 'package:hisaab/app/theme/palettes.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/theming_customisation/domain/appearance.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Customise screen: Appearance section (F-28, FR-28-11..13).
/// Net worth and Tab sections are deferred (memory 28).
class ThemingCustomisationScreen extends ConsumerWidget {
  /// Creates the screen.
  const ThemingCustomisationScreen({super.key});

  Future<void> _save(WidgetRef ref, AppearanceSettings s) =>
      ref.read(appearanceRepositoryProvider).save(s);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(appearanceProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(t('Customise'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t('Appearance'), style: text.titleMedium),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<ThemeModeChoice>(
                  key: const Key('mode-selector'),
                  segments: [
                    ButtonSegment(
                      value: ThemeModeChoice.system,
                      label: Text(t('System')),
                    ),
                    ButtonSegment(
                      value: ThemeModeChoice.light,
                      label: Text(t('Light')),
                    ),
                    ButtonSegment(
                      value: ThemeModeChoice.dark,
                      label: Text(t('Dark')),
                    ),
                  ],
                  selected: {a.mode},
                  onSelectionChanged: (v) =>
                      _save(ref, a.copyWith(mode: v.first)),
                ),
                SwitchListTile(
                  key: const Key('pure-black-switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('Pure black in dark mode')),
                  value: a.pureBlack,
                  onChanged: (v) => _save(ref, a.copyWith(pureBlack: v)),
                ),
                const SizedBox(height: 8),
                Text(t('Text size'), style: text.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<TextSize>(
                  key: const Key('text-size-selector'),
                  segments: [
                    for (final s in TextSize.values)
                      ButtonSegment(value: s, label: Text(t(s.label))),
                  ],
                  selected: {a.textSize},
                  onSelectionChanged: (v) =>
                      _save(ref, a.copyWith(textSize: v.first)),
                ),
              ],
            ),
          ),
          for (final g in PaletteGroup.values) ...[
            const SizedBox(height: 16),
            Text(t(g.label), style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final p in PaletteId.values.where((p) => p.group == g))
                  _Swatch(
                    id: p,
                    selected: p == a.palette,
                    onTap: () => _save(ref, a.copyWith(palette: p)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final PaletteId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spec = allPaletteSpecs[id.index];
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: id.label,
      child: InkWell(
        key: Key('palette-${id.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 88,
          child: Column(
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(colors: spec.heroLight),
                  border: Border.all(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                t(id.label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
