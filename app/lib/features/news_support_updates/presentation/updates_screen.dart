import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/updates_providers.dart';
import 'package:hisaab/features/news_support_updates/domain/release.dart';
import 'package:hisaab/features/news_support_updates/domain/update_state.dart';

/// About and updates (F-31, FR-31-18, FR-31-19, FR-31-22, FR-31-23).
class UpdatesScreen extends ConsumerWidget {
  /// Creates the screen; [version] defaults to the installed version.
  const UpdatesScreen({this.version = appVersion, super.key});

  /// Installed version shown.
  final String version;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    final ctl = ref.read(updateControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Image.asset(
            'assets/branding/dhankosh_mark.png',
            height: 72,
            semanticLabel: 'DhanKosh',
          ),
          Text('DhanKosh', style: Theme.of(context).textTheme.headlineSmall),
          Text('Version $version', key: const Key('about-version')),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Updates',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _status(context, ref, state),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('check-updates'),
                    onPressed: state is UpdateChecking
                        ? null
                        : () => ctl.check(force: true),
                    child: const Text('Check for updates'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Everything stays on this phone. DhanKosh sends no analytics and '
            'no personal data. Update checks only ask GitHub for the latest '
            'release.',
            key: Key('about-privacy'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Copyright (c) 2026 Dhyanendra Singh Sikarwar. All rights '
            'reserved.',
            key: Key('about-licence'),
          ),
        ],
      ),
    );
  }

  Widget _status(BuildContext context, WidgetRef ref, UpdateState s) =>
      switch (s) {
        UpdateIdle() => const Text('Not checked yet.'),
        UpdateChecking() => const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Checking…'),
            ],
          ),
        UpdateUpToDate() => const Text('You have the latest version.'),
        UpdateFailed(:final message) => Text(message),
        UpdateAvailable(:final release) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DhanKosh ${release.version} is available',
                key: const Key('update-available'),
              ),
              const SizedBox(height: 8),
              for (final l in cleanReleaseNotes(release.notes)) Text('• $l'),
              if (cleanReleaseNotes(release.notes).isEmpty)
                const Text("Release notes aren't available."),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('install-update'),
                onPressed: () async {
                  try {
                    await ref
                        .read(widgetChannelProvider)
                        .openUrl(release.apkUrl);
                  } on Object {
                    // Hand-off failures are non-fatal (FR-31-26).
                  }
                },
                child: const Text('Install'),
              ),
            ],
          ),
      };
}
