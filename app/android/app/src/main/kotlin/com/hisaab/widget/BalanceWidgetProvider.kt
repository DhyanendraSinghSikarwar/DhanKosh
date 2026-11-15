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
class BalanceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.balance_widget).apply {
                setTextViewText(R.id.bal_caption, widgetData.getString("bal_caption", "Bank balance"))
                setTextViewText(R.id.bal_amount, widgetData.getString("bal_amount", "₹••••"))
                setOnClickPendingIntent(
                    R.id.balance_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("hisaab://app/accounts"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
