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
            val cityName = widgetData.getString(CITY_NAME_KEY, DEFAULT_CITY_NAME)
                ?: DEFAULT_CITY_NAME
            val nextPrayerName =
                widgetData.getString(NEXT_PRAYER_NAME_KEY, DEFAULT_NEXT_PRAYER_NAME)
                    ?: DEFAULT_NEXT_PRAYER_NAME
            val nextPrayerTime =
                widgetData.getString(NEXT_PRAYER_TIME_KEY, DEFAULT_NEXT_PRAYER_TIME)
                    ?: DEFAULT_NEXT_PRAYER_TIME

            val views = RemoteViews(context.packageName, R.layout.prayer_times_widget).apply {
                setTextViewText(R.id.widget_city_name, cityName)
                setTextViewText(R.id.widget_next_prayer_name, "Sonraki: $nextPrayerName")
                setTextViewText(R.id.widget_next_prayer_time, nextPrayerTime)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    companion object {
        private const val CITY_NAME_KEY = "widget_city_name"
        private const val NEXT_PRAYER_NAME_KEY = "widget_next_prayer_name"
        private const val NEXT_PRAYER_TIME_KEY = "widget_next_prayer_time"
        private const val DEFAULT_CITY_NAME = "Ezan Vakti"
        private const val DEFAULT_NEXT_PRAYER_NAME = "--"
        private const val DEFAULT_NEXT_PRAYER_TIME = "--:--"
    }
}
