import 'package:flutter/material.dart';
import 'package:hisaab/features/email_ingestion/domain/entities/email_account.dart';

/// Short numbered steps to create an app password for [provider] (FR-03-07).
class AppPasswordGuide extends StatelessWidget {
  /// Creates the guide.
  const AppPasswordGuide(this.provider, {super.key});

  /// Provider whose steps are shown.
  final EmailProvider provider;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      key: Key('app-password-guide-${provider.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'An app password is separate from your normal one.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < provider.steps.length; i++)
          Text('${i + 1}. ${provider.steps[i]}', style: text.bodySmall),
        if (provider.appPasswordUrl != null)
          SelectableText(provider.appPasswordUrl!, style: text.bodySmall),
      ],
    );
  }
}
