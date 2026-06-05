package com.veles.ezanvakti

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
            val state = resolveWidgetState(widgetData)

            val views = RemoteViews(context.packageName, R.layout.prayer_times_widget).apply {
                setTextViewText(R.id.widget_city_name, state.cityName)
                setTextViewText(
                    R.id.widget_next_prayer_line,
                    "${state.nextPrayerName} ${state.nextPrayerTime}"
                )
                setTextViewText(R.id.widget_remaining_time, state.remainingTime)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun resolveWidgetState(widgetData: SharedPreferences): WidgetState {
        val nowMillis = System.currentTimeMillis()
        val cityName = widgetData.getString(CITY_NAME_KEY, DEFAULT_CITY_NAME)
            ?.takeIf { it.isNotBlank() }
            ?: DEFAULT_CITY_NAME
        val scheduleEntry = parsePrayerSchedule(
            widgetData.getString(PRAYER_SCHEDULE_KEY, null)
        ).firstOrNull { it.targetMillis > nowMillis }
        val fallbackEntry = readFallbackEntry(widgetData)
            ?.takeIf { it.targetMillis > nowMillis }
        val nextEntry = scheduleEntry ?: fallbackEntry ?: return safeWidgetState()

        return WidgetState(
            cityName = cityName,
            nextPrayerName = nextEntry.name,
            nextPrayerTime = nextEntry.time,
            remainingTime = formatRemainingTime(nextEntry.targetMillis - nowMillis)
        )
    }

    private fun readFallbackEntry(widgetData: SharedPreferences): PrayerEntry? {
        val name = widgetData.getString(NEXT_PRAYER_NAME_KEY, null)
            ?.takeIf { it.isNotBlank() }
            ?: return null
        val time = widgetData.getString(NEXT_PRAYER_TIME_KEY, null)
            ?.takeIf { it.isNotBlank() }
            ?: return null
        val targetMillis = widgetData.getString(NEXT_PRAYER_TARGET_MILLIS_KEY, null)
            ?.toLongOrNull()
            ?: return null

        return PrayerEntry(name = name, time = time, targetMillis = targetMillis)
    }

    private fun parsePrayerSchedule(rawSchedule: String?): List<PrayerEntry> {
        if (rawSchedule.isNullOrBlank()) {
            return emptyList()
        }

        return rawSchedule.split(SCHEDULE_ENTRY_SEPARATOR)
            .mapNotNull { rawEntry ->
                val parts = rawEntry.split(SCHEDULE_PART_SEPARATOR)
                if (parts.size != 3) {
                    return@mapNotNull null
                }

                val targetMillis = parts[2].toLongOrNull() ?: return@mapNotNull null
                PrayerEntry(
                    name = parts[0],
                    time = parts[1],
                    targetMillis = targetMillis
                )
            }
            .sortedBy { it.targetMillis }
    }

    private fun formatRemainingTime(remainingMillis: Long): String {
        if (remainingMillis < MILLIS_IN_MINUTE) {
            return TIME_ENTERED_TEXT
        }

        val totalMinutes = remainingMillis / MILLIS_IN_MINUTE
        val hours = totalMinutes / MINUTES_IN_HOUR
        val minutes = totalMinutes % MINUTES_IN_HOUR
        val fullText = if (hours > 0L) {
            "$hours saat $minutes dakika kaldı"
        } else {
            "$minutes dakika kaldı"
        }

        if (fullText.length <= MAX_REMAINING_TEXT_LENGTH) {
            return fullText
        }

        return if (hours > 0L) {
            "${hours}s ${minutes}dk kaldı"
        } else {
            "${minutes}dk kaldı"
        }
    }

    private fun safeWidgetState(cityName: String = DEFAULT_CITY_NAME): WidgetState {
        return WidgetState(
            cityName = cityName,
            nextPrayerName = DEFAULT_NEXT_PRAYER_NAME,
            nextPrayerTime = DEFAULT_NEXT_PRAYER_TIME,
            remainingTime = DEFAULT_REMAINING_TIME
        )
    }

    companion object {
        private const val CITY_NAME_KEY = "widget_city_name"
        private const val NEXT_PRAYER_NAME_KEY = "widget_next_prayer_name"
        private const val NEXT_PRAYER_TIME_KEY = "widget_next_prayer_time"
        private const val NEXT_PRAYER_TARGET_MILLIS_KEY = "widget_next_prayer_target_millis"
        private const val PRAYER_SCHEDULE_KEY = "widget_prayer_schedule"
        private const val SCHEDULE_ENTRY_SEPARATOR = ";"
        private const val SCHEDULE_PART_SEPARATOR = "|"
        private const val MILLIS_IN_MINUTE = 60000L
        private const val MINUTES_IN_HOUR = 60L
        private const val MAX_REMAINING_TEXT_LENGTH = 16
        private const val DEFAULT_CITY_NAME = "Ezan Vakti"
        private const val DEFAULT_NEXT_PRAYER_NAME = "--"
        private const val DEFAULT_NEXT_PRAYER_TIME = "--:--"
        private const val DEFAULT_REMAINING_TIME = "--"
        private const val TIME_ENTERED_TEXT = "Vakit girdi"
    }
}

private data class PrayerEntry(
    val name: String,
    val time: String,
    val targetMillis: Long
)

private data class WidgetState(
    val cityName: String,
    val nextPrayerName: String,
    val nextPrayerTime: String,
    val remainingTime: String
)
