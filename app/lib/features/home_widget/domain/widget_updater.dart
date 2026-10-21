import 'package:hisaab/features/home_widget/domain/spend_widget_data.dart';

/// Pushes a snapshot to the native widget (FR-30-08). Never throws.
abstract interface class WidgetUpdater {
  /// Stores [data] and asks the launcher to redraw.
  Future<void> update(SpendWidgetData data);
}
