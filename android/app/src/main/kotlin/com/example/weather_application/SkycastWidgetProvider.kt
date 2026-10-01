package com.example.weather_application

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 2×2 current-weather widget. The Flutter app pushes the text and the sky key
 * (see lib/features/home_widget/); this only draws them, tapping opens the app.
 */
class SkycastWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.skycast_widget).apply {
                setInt(R.id.widget_root, "setBackgroundResource", skyBackground(widgetData.getString("sky", null)))
                setTextViewText(R.id.widget_city, widgetData.getString("city", null) ?: context.getString(R.string.widget_empty))
                setTextViewText(R.id.widget_temp, widgetData.getString("temp", null) ?: "--°")
                setTextViewText(R.id.widget_condition, widgetData.getString("condition", null) ?: "")
                setTextViewText(R.id.widget_hilo, widgetData.getString("hilo", null) ?: "")
                setOnClickPendingIntent(R.id.widget_root, openApp(context))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}

/** Opens the app; shared by both widget sizes. */
internal fun openApp(context: Context): PendingIntent =
    PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

// An explicit map rather than getIdentifier(), so resource shrinking can't drop them.
internal fun skyBackground(sky: String?): Int =
    when (sky) {
        "clear_day" -> R.drawable.widget_bg_clear_day
        "clear_night" -> R.drawable.widget_bg_clear_night
        "cloudy_day" -> R.drawable.widget_bg_cloudy_day
        "cloudy_night" -> R.drawable.widget_bg_cloudy_night
        "fog_day" -> R.drawable.widget_bg_fog_day
        "fog_night" -> R.drawable.widget_bg_fog_night
        "rain_day" -> R.drawable.widget_bg_rain_day
        "rain_night" -> R.drawable.widget_bg_rain_night
        "snow_day" -> R.drawable.widget_bg_snow_day
        "snow_night" -> R.drawable.widget_bg_snow_night
        "storm_day" -> R.drawable.widget_bg_storm_day
        "storm_night" -> R.drawable.widget_bg_storm_night
        else -> R.drawable.widget_bg_clear_day
    }
