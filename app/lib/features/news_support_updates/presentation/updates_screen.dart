import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/updates_providers.dart';
import 'package:hisaab/features/news_support_updates/domain/release.dart';
import 'package:hisaab/features/news_support_updates/domain/update_state.dart';
import 'package:hisaab/features/news_support_updates/domain/version_compare.dart';

/// About and updates (F-31, FR-31-18, FR-31-19, FR-31-22, FR-31-28..32).
class UpdatesScreen extends ConsumerStatefulWidget {
  /// Creates the screen; [version] defaults to the installed version.
  const UpdatesScreen({this.version = appVersion, super.key});

  /// Installed version shown.
  final String version;

  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends ConsumerState<UpdatesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(ref.read(releaseHistoryProvider.notifier).load()),
    );
  }

  Future<void> _openPage(Release r) async {
    try {
      await ref.read(widgetChannelProvider).openUrl(
            r.pageUrl ??
                'https://github.com/$releaseRepo/releases/tag/v${r.version}',
          );
    } on Object {
      // Hand-off failures are non-fatal (FR-31-26).
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateControllerProvider);
    final ctl = ref.read(updateControllerProvider.notifier);
    final busy = state is UpdateChecking || state is UpdateDownloading;
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
          Text('Version ${widget.version}', key: const Key('about-version')),
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
                  _status(context, state, ctl),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('check-updates'),
                    onPressed: busy ? null : () => ctl.check(force: true),
                    child: const Text('Check for updates'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _history(context, ref.watch(releaseHistoryProvider), busy, ctl),
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

  Widget _actions(Release r, UpdateController ctl, {required String retry}) =>
      Wrap(
        spacing: 8,
        children: [
          FilledButton(
            key: const Key('install-update'),
            onPressed: () => unawaited(ctl.install(r)),
            child: Text(retry),
          ),
          TextButton(
            key: const Key('open-release-page'),
            onPressed: () => unawaited(_openPage(r)),
            child: const Text('Open release page'),
          ),
        ],
      );

  Widget _status(BuildContext context, UpdateState s, UpdateController ctl) =>
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
              Text('Checking...'),
            ],
          ),
        UpdateUpToDate() => Text(
            'You are on the latest (${widget.version})',
            key: const Key('update-latest'),
          ),
        UpdateFailed(:final message, :final release) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, key: const Key('update-failed')),
              if (release != null) ...[
                const SizedBox(height: 8),
                _actions(release, ctl, retry: 'Try again'),
              ],
            ],
          ),
        UpdateDownloading(:final release, :final progress) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                progress >= 1
                    ? 'Verifying ${release.version}...'
                    : 'Downloading ${release.version}... '
                        '${(progress * 100).round()}%',
                key: const Key('update-downloading'),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                key: const Key('update-progress'),
                value: progress >= 1 ? null : progress,
              ),
              TextButton(
                key: const Key('cancel-download'),
                onPressed: ctl.cancelDownload,
                child: const Text('Cancel'),
              ),
            ],
          ),
        UpdatePermissionNeeded(:final release) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Allow DhanKosh to install apps in the settings that opened, '
                'then tap Retry.',
                key: Key('update-permission'),
              ),
              const SizedBox(height: 8),
              _actions(release, ctl, retry: 'Retry'),
            ],
          ),
        UpdateHandedOff(:final release) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Installer opened. If DhanKosh was not installed, retry or '
                'open the release page.',
                key: Key('update-handed-off'),
              ),
              const SizedBox(height: 8),
              _actions(release, ctl, retry: 'Retry'),
            ],
          ),
        UpdateAvailable(:final release) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Update ${release.version} available',
                key: const Key('update-available'),
              ),
              const SizedBox(height: 8),
              for (final l in cleanReleaseNotes(release.notes)) Text('• $l'),
              if (cleanReleaseNotes(release.notes).isEmpty)
                const Text("Release notes aren't available."),
              const SizedBox(height: 8),
              _actions(release, ctl, retry: 'Download and install'),
            ],
          ),
      };

  Widget _history(
    BuildContext context,
    HistoryState h,
    bool busy,
    UpdateController ctl,
  ) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('release-history'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Release history', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (h.loading && h.releases.isEmpty)
              const Text('Loading...', key: Key('history-loading')),
            if (h.failed)
              Text(
                h.releases.isEmpty
                    ? "Couldn't load releases. Check your connection."
                    : 'Offline. Showing the last saved list.',
                key: const Key('history-offline'),
              ),
            for (final r in h.releases) _row(context, r, busy, ctl),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    Release r,
    bool busy,
    UpdateController ctl,
  ) {
    final installed = r.version == widget.version;
    final newer = isNewer(r.version, widget.version);
    final notes = cleanReleaseNotes(r.notes);
    final d = r.publishedAt?.toLocal();
    final date = d == null
        ? ''
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
    return ExpansionTile(
      key: Key('release-${r.version}'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Row(
        children: [
          Text(r.version),
          const SizedBox(width: 8),
          if (installed) const Chip(label: Text('Installed')),
          if (newer) const Chip(label: Text('New')),
        ],
      ),
      subtitle: date.isEmpty ? null : Text(date),
      children: [
        for (final l in notes) Text('• $l'),
        if (notes.isEmpty) const Text("Release notes aren't available."),
        if (newer && r.installable && !busy)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: Key('install-${r.version}'),
              onPressed: () => unawaited(ctl.install(r)),
              child: const Text('Download and install'),
            ),
          ),
      ],
    );
  }
}
