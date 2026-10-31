import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/updates_providers.dart';
import 'package:hisaab/features/news_support_updates/domain/upi_link.dart';
import 'package:hisaab/shared/widgets/app_card.dart';
import 'package:hisaab/shared/widgets/app_icons.dart';

/// Support page: opens a UPI app with the amount prefilled (F-31,
/// FR-31-11 to FR-31-14). Nothing is stored. [upiId] defaults to the build
/// configuration; it is never shown.
class SupportScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SupportScreen({this.upiId = supportUpiId, super.key});

  /// Donation address (VPA).
  final String upiId;

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  static const _presets = [49, 99, 199];
  int? _preset = 99;
  bool _custom = false;
  String _customText = '';

  int get _amount => _custom ? parseSupportAmount(_customText) : _preset ?? 0;

  Future<void> _pay() async {
    final link = buildUpiLink(vpa: widget.upiId, amountRupees: _amount);
    var ok = false;
    try {
      ok = await ref
          .read(widgetChannelProvider)
          .openUrl(link, chooser: true, chooserTitle: 'Pay with');
    } on Object {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No UPI app found')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          AppCard(
            key: const Key('support-hero'),
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              children: [
                const Icon(Icons.favorite, size: 34, color: AppIcons.red),
                const SizedBox(height: 6),
                Text(
                  'Support DhanKosh',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Free, offline, no ads. A tip is optional.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in _presets)
                      ChoiceChip(
                        key: Key('support-pill-$a'),
                        label: Text('₹$a'),
                        selected: !_custom && _preset == a,
                        onSelected: (_) => setState(() {
                          _custom = false;
                          _preset = _preset == a ? null : a;
                        }),
                      ),
                    ChoiceChip(
                      key: const Key('support-pill-custom'),
                      label: const Text('Other'),
                      selected: _custom,
                      onSelected: (_) => setState(() {
                        _custom = !_custom;
                        _preset = null;
                      }),
                    ),
                  ],
                ),
                if (_custom) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('support-custom-field'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(labelText: 'Amount (₹)'),
                    onChanged: (v) => setState(() => _customText = v),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    key: const Key('support-pay'),
                    onPressed: _pay,
                    child: const Text('Pay with UPI'),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Opens your UPI app. DhanKosh sends nothing.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
