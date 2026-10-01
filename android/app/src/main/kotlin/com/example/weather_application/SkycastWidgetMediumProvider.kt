package com.example.weather_application

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 4×2 widget: the small widget's current weather, the best time for the
 * user's first activity, and the next six hours. Same data source as
 * [SkycastWidgetProvider]; keys are written by widgetData() in
 * lib/features/home_widget/presentation/widget_data.dart.
 */
class SkycastWidgetMediumProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.skycast_widget_medium).apply {
                setInt(R.id.widget_root, "setBackgroundResource", skyBackground(widgetData.getString("sky", null)))
                setTextViewText(R.id.widget_city, widgetData.getString("city", null) ?: context.getString(R.string.widget_empty))
                setTextViewText(R.id.widget_temp, widgetData.getString("temp", null) ?: "--°")
                setTextViewText(
                    R.id.widget_condition,
                    listOfNotNull(widgetData.getString("condition", null), widgetData.getString("hilo", null))
                        .filter { it.isNotEmpty() }
                        .joinToString(" · "),
                )
                val activity = widgetData.getString("activity", null).orEmpty()
                setTextViewText(R.id.widget_activity, activity)
                setViewVisibility(R.id.widget_activity, if (activity.isEmpty()) View.GONE else View.VISIBLE)
                for ((i, ids) in HOURS.withIndex()) {
                    setTextViewText(ids[0], widgetData.getString("h${i}_time", null) ?: "")
                    setTextViewText(ids[1], weatherEmoji(widgetData.getString("h${i}_icon", null)))
                    setTextViewText(ids[2], widgetData.getString("h${i}_temp", null) ?: "")
                }
                setOnClickPendingIntent(R.id.widget_root, openApp(context))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private companion object {
        /** Time, icon and temperature view ids per hourly column. */
        val HOURS = listOf(
            intArrayOf(R.id.h0_time, R.id.h0_icon, R.id.h0_temp),
            intArrayOf(R.id.h1_time, R.id.h1_icon, R.id.h1_temp),
            intArrayOf(R.id.h2_time, R.id.h2_icon, R.id.h2_temp),
            intArrayOf(R.id.h3_time, R.id.h3_icon, R.id.h3_temp),
            intArrayOf(R.id.h4_time, R.id.h4_icon, R.id.h4_temp),
            intArrayOf(R.id.h5_time, R.id.h5_icon, R.id.h5_temp),
        )
    }
}

/**
 * Emoji for a `<WeatherCondition>_<day|night>` key: a RemoteViews widget can
 * only show drawables or text, and emoji need no extra assets.
 */
internal fun weatherEmoji(key: String?): String {
    val night = key?.endsWith("_night") == true
    return when (key?.substringBeforeLast('_')) {
        "clear", "mainlyClear" -> if (night) "🌙" else "☀️"
        "partlyCloudy" -> if (night) "☁️" else "⛅"
        "overcast" -> "☁️"
        "fog" -> "🌫️"
        "drizzle", "showers" -> "🌦️"
        "rain" -> "🌧️"
        "snow" -> "❄️"
        "thunderstorm" -> "⛈️"
        null -> ""
        else -> "☁️"
    }
}
