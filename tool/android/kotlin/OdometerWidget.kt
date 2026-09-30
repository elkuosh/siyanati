package com.rovana.garage_log

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** ويدجيت الشاشة الرئيسية: عداد كل مركبة، ودوسة على المركبة تفتح تحديث العداد */
class OdometerWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val rows = intArrayOf(R.id.row0, R.id.row1, R.id.row2, R.id.row3)
        val names = intArrayOf(R.id.name0, R.id.name1, R.id.name2, R.id.name3)
        val kms = intArrayOf(R.id.km0, R.id.km1, R.id.km2, R.id.km3)
        val dues = intArrayOf(R.id.due0, R.id.due1, R.id.due2, R.id.due3)
        val count = (widgetData.getString("count", "0") ?: "0").toIntOrNull() ?: 0

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.odometer_widget)
            for (i in 0 until 4) {
                if (i < count) {
                    views.setViewVisibility(rows[i], View.VISIBLE)
                    views.setTextViewText(names[i], widgetData.getString("v${i}_name", ""))
                    views.setTextViewText(kms[i], widgetData.getString("v${i}_km", ""))
                    val due = widgetData.getString("v${i}_due", "") ?: ""
                    views.setTextViewText(dues[i], due)
                    views.setViewVisibility(dues[i], if (due.isEmpty()) View.GONE else View.VISIBLE)
                    val id = widgetData.getString("v${i}_id", "") ?: ""
                    val intent = HomeWidgetLaunchIntent.getActivity(
                        context, MainActivity::class.java,
                        Uri.parse("siyanati://odometer?id=$id")
                    )
                    views.setOnClickPendingIntent(rows[i], intent)
                } else {
                    views.setViewVisibility(rows[i], View.GONE)
                }
            }
            views.setViewVisibility(R.id.empty, if (count == 0) View.VISIBLE else View.GONE)
            val open = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java, Uri.parse("siyanati://open")
            )
            views.setOnClickPendingIntent(R.id.header, open)
            views.setOnClickPendingIntent(R.id.empty, open)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
