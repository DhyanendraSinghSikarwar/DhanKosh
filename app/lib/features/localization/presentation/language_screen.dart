import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/appearance_providers.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/localization/presentation/language_controller.dart';

/// Language picker (F-29, FR-29-11, FR-29-12).
class LanguageScreen extends ConsumerWidget {
  /// Creates the screen.
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(languageProvider.select((s) => s.message), (_, m) {
      if (m == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
      ref.read(languageProvider.notifier).messageShown();
    });
    final s = ref.watch(languageProvider);
    final c = ref.read(languageProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(t('Language'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final l in Language.values)
            Card(
              key: Key('lang-${l.code}'),
              elevation: 0,
              color: l == s.active ? scheme.primaryContainer : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: l == s.active
                      ? scheme.primary
                      : scheme.surfaceContainerHigh,
                  foregroundColor:
                      l == s.active ? scheme.onPrimary : scheme.onSurface,
                  child: Text(l.native.characters.first),
                ),
                title: Text(
                  l.native,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l.builtIn
                      ? t('Built in')
                      : s.downloaded.contains(l)
                          ? '${t(l.english)} · ${t('Downloaded')}'
                          : '${t(l.english)} · ${t('Tap to download')}',
                ),
                trailing: _trailing(s, l, c),
                onTap: s.busy == l ? null : () => c.choose(l),
              ),
            ),
        ],
      ),
    );
  }

  Widget _trailing(LanguageState s, Language l, LanguageController c) {
    if (s.busy == l) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (l == s.active) {
      return Tooltip(
        message: t('In use'),
        child: const Icon(Icons.check_circle),
      );
    }
    if (!l.builtIn && s.downloaded.contains(l)) {
      return IconButton(
        key: Key('lang-remove-${l.code}'),
        tooltip: t('Remove download'),
        icon: const Icon(Icons.delete_outline),
        onPressed: () => c.remove(l),
      );
    }
    if (l.builtIn) return const SizedBox.shrink();
    return Tooltip(
      message: t('Download'),
      child: const Icon(Icons.cloud_download_outlined),
    );
  }
}
