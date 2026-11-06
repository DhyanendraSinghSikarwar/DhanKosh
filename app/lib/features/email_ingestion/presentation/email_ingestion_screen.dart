import 'package:flutter/material.dart';
import 'package:hisaab/features/localization/domain/language.dart';

/// Placeholder screen for: Email Ingestion.
class EmailIngestionScreen extends StatelessWidget {
  const EmailIngestionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          t('Email Ingestion placeholder'),
          key: const Key('email_ingestion_placeholder'),
        ),
      ),
    );
  }
}
