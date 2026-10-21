import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisaab/app/di/updates_providers.dart';
import 'package:hisaab/features/news_support_updates/domain/upi_link.dart';

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
  static const _presets = [100, 200, 500];
  int? _preset;
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Support DhanKosh')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.coffee_outlined, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'DhanKosh is free, private and built by one developer. '
                        'If it helps you, you can buy the developer a coffee.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Amount'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
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
                  label: const Text('Custom'),
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
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('support-pay'),
                onPressed: _pay,
                child: const Text('Pay with a UPI app'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Thank you. Nothing about your payment is stored in the app.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
