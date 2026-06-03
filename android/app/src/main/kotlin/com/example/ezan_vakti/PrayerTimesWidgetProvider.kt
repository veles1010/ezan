package com.example.ezan_vakti

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerTimesWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val title = widgetData.getString(TITLE_KEY, DEFAULT_TITLE) ?: DEFAULT_TITLE
            val nextPrayer =
                widgetData.getString(NEXT_PRAYER_KEY, DEFAULT_NEXT_PRAYER)
                    ?: DEFAULT_NEXT_PRAYER

            val views = RemoteViews(context.packageName, R.layout.prayer_times_widget).apply {
                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_next_prayer, nextPrayer)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    companion object {
        private const val TITLE_KEY = "widget_title"
        private const val NEXT_PRAYER_KEY = "widget_next_prayer"
        private const val DEFAULT_TITLE = "Ezan Vakti"
        private const val DEFAULT_NEXT_PRAYER = "Sonraki vakit: Öğle 13:00"
    }
}
