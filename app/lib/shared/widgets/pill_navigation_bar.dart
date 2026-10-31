import 'package:flutter/material.dart';

/// Floating rounded [NavigationBar] with margin around it (mockup look).
class PillNavigationBar extends StatelessWidget {
  /// Creates the bar.
  const PillNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    super.key,
  });

  /// Selected tab.
  final int selectedIndex;

  /// Tab tap handler.
  final ValueChanged<int> onDestinationSelected;

  /// Tabs.
  final List<Widget> destinations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(32),
          clipBehavior: Clip.antiAlias,
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}
