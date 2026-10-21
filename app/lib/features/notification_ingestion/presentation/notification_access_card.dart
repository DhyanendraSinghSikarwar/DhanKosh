import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/features/notification_ingestion/domain/entities/payment_app.dart';
import 'package:hisaab/features/notification_ingestion/domain/usecases/notification_engine.dart';
import 'package:hisaab/features/notification_ingestion/presentation/notification_providers.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Data source "Payment-app notifications": status, switch, access settings
/// and watched apps (FR-04-16, US-04-02).
class NotificationAccessCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const NotificationAccessCard({super.key});

  @override
  ConsumerState<NotificationAccessCard> createState() => _State();
}

class _State extends ConsumerState<NotificationAccessCard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(notificationStatusProvider.notifier).refresh());
    }
  }

  static String _label(NotificationState s) => switch (s) {
        NotificationState.on => 'On',
        NotificationState.needsAccess => 'Needs access',
        NotificationState.off => 'Off',
      };

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(notificationStatusProvider).value ??
        const NotificationSourceStatus();
    final n = ref.read(notificationStatusProvider.notifier);
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text('Payment-app notifications', style: text.titleMedium),
              ),
              Text(
                _label(s.state),
                key: const Key('notif-status'),
                style: text.labelMedium,
              ),
            ],
          ),
          SwitchListTile(
            key: const Key('notif-enabled'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Read payment-app notifications'),
            value: s.enabled,
            onChanged: (v) => unawaited(n.setEnabled(enabled: v)),
          ),
          if (s.enabled && !s.hasAccess) ...[
            FilledButton.tonal(
              key: const Key('notif-open-settings'),
              onPressed: () => unawaited(n.openAccessSettings()),
              child: const Text('Open access settings'),
            ),
            if (s.showRestrictedHint) ...[
              const SizedBox(height: 8),
              Text(
                'If access is greyed out: App info, menu, '
                'Allow restricted settings.',
                key: const Key('notif-restricted-hint'),
                style: text.bodySmall,
              ),
            ],
          ],
          if (!s.enabled) ...[
            const SizedBox(height: 8),
            Text(
              'Off: UPI payments without a bank SMS are not tracked.',
              key: const Key('notif-off-warning'),
              style: text.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          Text('Watched apps', style: text.labelMedium),
          const SizedBox(height: 4),
          Wrap(
            key: const Key('notif-apps'),
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final a in PaymentApps.displayNames)
                Chip(
                  label: Text(a),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
