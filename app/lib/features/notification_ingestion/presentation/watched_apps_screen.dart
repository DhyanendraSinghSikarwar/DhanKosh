import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/features/localization/domain/language.dart';
import 'package:hisaab/features/notification_ingestion/domain/entities/payment_app.dart';
import 'package:hisaab/features/notification_ingestion/domain/notification_ports.dart';
import 'package:hisaab/features/notification_ingestion/presentation/notification_providers.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Which apps the notification listener reads (FR-04-19, FR-04-20). Built-in
/// payment apps can be switched off; any other app that notified the phone can
/// be added, so a UPI payment with no bank SMS is still recorded.
class WatchedAppsScreen extends ConsumerWidget {
  /// Creates the screen.
  const WatchedAppsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(watchedAppsListProvider);
    final n = ref.read(watchedAppsListProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(t('Watched apps'))),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(t('Could not load apps'))),
        data: (v) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Only these apps are read. Everything else is ignored without '
              'its text being looked at.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (v.added.isNotEmpty) ...[
              const _Heading('Apps you added'),
              AppCard(
                child: Column(
                  children: [
                    for (final a in v.added)
                      SwitchListTile(
                        key: Key('watched-extra-${a.packageName}'),
                        contentPadding: EdgeInsets.zero,
                        value: true,
                        title: Text(a.displayName),
                        subtitle: Text(a.packageName),
                        onChanged: (_) => unawaited(n.removeApp(a.packageName)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const _Heading('Other apps that notified you'),
            AppCard(
              key: const Key('watched-seen'),
              child: v.seen.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Nothing yet. Apps that notify you while reading is '
                        'on show up here, by name only.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : Column(
                      children: [
                        for (final a in v.seen)
                          ListTile(
                            key: Key('watched-seen-${a.packageName}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(a.label),
                            subtitle: Text(a.packageName),
                            trailing: TextButton(
                              onPressed: () =>
                                  unawaited(n.addApp(a.packageName, a.label)),
                              child: Text(t('Watch')),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            const _Heading('Payment and bank apps'),
            AppCard(
              child: Column(
                children: [
                  for (final a in v.builtIn)
                    SwitchListTile(
                      key: Key('watched-builtin-${a.packageName}'),
                      contentPadding: EdgeInsets.zero,
                      value: !v.watched.disabled.contains(a.packageName),
                      title: Text(a.displayName),
                      onChanged: (on) => unawaited(
                        n.setBuiltIn(a.packageName, watched: on),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

/// Built-ins, the user's added apps and the apps seen but not watched.
class WatchedAppsView {
  /// Creates a view.
  const WatchedAppsView({
    required this.watched,
    required this.seen,
  });

  /// The user's choices.
  final WatchedApps watched;

  /// Apps that notified the phone and are not watched.
  final List<UnwatchedApp> seen;

  /// Every built-in app, in list order.
  List<PaymentApp> get builtIn => PaymentApps.all;

  /// The apps the user added themselves.
  List<PaymentApp> get added => [
        for (final e in watched.extra.entries)
          if (PaymentApps.byPackage(e.key) == null) PaymentApp(e.key, e.value),
      ];
}
