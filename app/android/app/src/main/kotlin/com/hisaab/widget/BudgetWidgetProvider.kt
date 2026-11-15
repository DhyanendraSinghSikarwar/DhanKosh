package com.hisaab.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import com.hisaab.hisaab.MainActivity
import com.hisaab.hisaab.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget (F-30, FR-30-16). Draws only strings Dart already formatted and masked. */
class BudgetWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.budget_widget).apply {
                setTextViewText(R.id.bud_caption, widgetData.getString("bud_caption", "Budget left"))
                setTextViewText(R.id.bud_left, widgetData.getString("bud_left", "₹••••"))
                setTextViewText(R.id.bud_sub, widgetData.getString("bud_sub", ""))
                setProgressBar(R.id.bud_progress, 100, widgetData.getString("bud_percent", "0")?.toIntOrNull() ?: 0, false)
                setOnClickPendingIntent(
                    R.id.budget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("hisaab://app/budgets"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
