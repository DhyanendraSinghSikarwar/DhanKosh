import 'package:flutter/material.dart';
import 'package:hisaab/features/localization/domain/language.dart';

/// Placeholder screen for: Search & Filters.
class SearchFiltersScreen extends StatelessWidget {
  const SearchFiltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          t('Search & Filters placeholder'),
          key: const Key('search_filters_placeholder'),
        ),
      ),
    );
  }
}
