package com.viralvaghela.movenow

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Locale

class MoveNowSmallWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val steps = prefs.getInt("stepsToday", 0)
        val distance = prefs.getFloat("distanceToday", 0f).toDouble()
        val status = prefs.getString("currentActivity", "STILL") ?: "STILL"
        val isPaused = prefs.getBoolean("isPaused", false)
        val units = prefs.getString("flutter.units", "meters") ?: "meters"

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_small_layout)
            
            // Format steps
            views.setTextViewText(R.id.widget_steps, "$steps Steps")
            
            // Format distance
            val distanceText = if (units == "km") {
                String.format(Locale.getDefault(), "%.2f km", distance / 1000.0)
            } else {
                "${distance.toInt()} m"
            }
            views.setTextViewText(R.id.widget_distance, distanceText)

            // Format status badge
            val displayStatus = if (isPaused) "PAUSED" else status
            views.setTextViewText(R.id.widget_status, displayStatus)
            
            // Set text color for badge based on activity
            val badgeColor = when (displayStatus) {
                "WALKING", "RUNNING" -> 0xFF4CAF50.toInt() // Green
                "PAUSED" -> 0xFFFF9800.toInt() // Orange
                "STANDING" -> 0xFF2196F3.toInt() // Blue
                else -> 0xFF888888.toInt() // Gray
            }
            views.setTextColor(R.id.widget_status, badgeColor)

            // Open App on widget click
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_steps, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // Refresh widget when update broadcast is received
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val thisAppWidget = ComponentName(context.packageName, MoveNowSmallWidgetProvider::class.java.name)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
        onUpdate(context, appWidgetManager, appWidgetIds)
    }
}
