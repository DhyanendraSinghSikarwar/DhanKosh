import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/history_providers.dart';
import 'package:hisaab/app/di/providers.dart';
import 'package:hisaab/features/settings_data_sources/domain/setting_key.dart';
import 'package:hisaab/features/settings_data_sources/domain/usecases/change_history_days.dart';
import 'package:hisaab/shared/widgets/app_card.dart';

/// Saved "History to read" window in days.
final StreamProvider<int> historyDaysProvider = StreamProvider.autoDispose<int>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(SettingKeys.historyDays),
);

/// "History to read": 7 to 365 days for SMS and email. Raising it reads the
/// longer period again (FR-26-30).
class HistoryDaysCard extends ConsumerStatefulWidget {
  /// Creates the card.
  const HistoryDaysCard({super.key});

  @override
  ConsumerState<HistoryDaysCard> createState() => _HistoryDaysCardState();
}

class _HistoryDaysCardState extends ConsumerState<HistoryDaysCard> {
  double? _drag;
  String? _message;

  Future<void> _apply(int days) async {
    final reread = await ref.read(changeHistoryDaysProvider)(days);
    if (!mounted) return;
    setState(() {
      _drag = null;
      _message = reread ? 'Reading $days days again.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(historyDaysProvider).value ?? 90;
    final shown = (_drag ?? saved.toDouble()).round();
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('History to read', style: text.titleMedium)),
              Text(
                '$shown days',
                key: const Key('history-days'),
                style: text.labelLarge,
              ),
            ],
          ),
          Slider(
            key: const Key('history-slider'),
            value: shown.toDouble(),
            min: ChangeHistoryDays.min.toDouble(),
            max: ChangeHistoryDays.max.toDouble(),
            divisions: ChangeHistoryDays.max - ChangeHistoryDays.min,
            label: '$shown',
            onChanged: (v) => setState(() => _drag = v),
            onChangeEnd: (v) => _apply(v.round()),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final d in ChangeHistoryDays.presets)
                ChoiceChip(
                  key: Key('history-$d'),
                  label: Text('$d'),
                  selected: shown == d,
                  onSelected: (_) => _apply(d),
                ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              key: const Key('history-message'),
              style: text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
