import 'package:hisaab/features/home_widget/domain/spend_widget_data.dart';
import 'package:hisaab/features/home_widget/domain/widget_updater.dart';
import 'package:home_widget/home_widget.dart';

/// Native provider class (Kotlin, `com.hisaab.widget`).
const spendWidgetProvider = 'com.hisaab.widget.SpendWidgetProvider';

/// Shared-preference keys read by the native provider (memory 30 section 8).
Map<String, String> widgetPayload(SpendWidgetData d) => {
      'spent_today_text': d.todayText,
      'spent_month_text': d.monthText,
      'caption_today': d.todayCaption,
      'caption_month': d.monthCaption,
      'updated_at': d.updatedAt.millisecondsSinceEpoch.toString(),
    };

/// [WidgetUpdater] over the `home_widget` plugin.
class HomeWidgetUpdater implements WidgetUpdater {
  /// Creates the updater.
  const HomeWidgetUpdater();

  @override
  Future<void> update(SpendWidgetData data) async {
    try {
      for (final e in widgetPayload(data).entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: spendWidgetProvider);
    } on Object {
      // No native side (tests, desktop) or launcher failure: ignore.
    }
  }
}
