package com.hisaab.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.hisaab.hisaab.MainActivity
import com.hisaab.hisaab.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * "DhanKosh spend" widget (F-30). Reads only the strings Dart saved through
 * home_widget (already formatted, masked and translated); shows masked
 * amounts until the app has written a snapshot (FR-30-06).
 */
class SpendWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.spend_widget).apply {
                setTextViewText(
                    R.id.spend_caption_today,
                    widgetData.getString("caption_today", "Spent today"),
                )
                setTextViewText(
                    R.id.spend_amount_today,
                    widgetData.getString("spent_today_text", "₹••••"),
                )
                setTextViewText(
                    R.id.spend_caption_month,
                    widgetData.getString("caption_month", "This month"),
                )
                setTextViewText(
                    R.id.spend_amount_month,
                    widgetData.getString("spent_month_text", "₹••••"),
                )
                setOnClickPendingIntent(
                    R.id.spend_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
