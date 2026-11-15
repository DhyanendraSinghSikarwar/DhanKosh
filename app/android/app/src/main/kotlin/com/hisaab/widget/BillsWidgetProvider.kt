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
class BillsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.bills_widget).apply {
                setTextViewText(R.id.bill_caption, widgetData.getString("bill_caption", "Upcoming bills"))
                setTextViewText(R.id.bill_1, widgetData.getString("bill_1", "No bills coming up"))
                setTextViewText(R.id.bill_2, widgetData.getString("bill_2", ""))
                setTextViewText(R.id.bill_3, widgetData.getString("bill_3", ""))
                setOnClickPendingIntent(
                    R.id.bills_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("hisaab://app/bills"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
