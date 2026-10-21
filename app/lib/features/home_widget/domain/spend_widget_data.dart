/// Snapshot shown by the home-screen widget (FR-30-03, FR-30-15).
class SpendWidgetData {
  /// Creates the snapshot.
  const SpendWidgetData({
    required this.todayMinor,
    required this.monthMinor,
    required this.hidden,
    required this.todayText,
    required this.monthText,
    required this.todayCaption,
    required this.monthCaption,
    required this.updatedAt,
  });

  /// Spent today, paise.
  final int todayMinor;

  /// Spent this month, paise.
  final int monthMinor;

  /// Whether amounts were masked at build time.
  final bool hidden;

  /// Formatted or masked today total.
  final String todayText;

  /// Formatted or masked month total.
  final String monthText;

  /// Caption above today's amount.
  final String todayCaption;

  /// Caption above the month amount.
  final String monthCaption;

  /// Build time.
  final DateTime updatedAt;
}
