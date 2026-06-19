package com.viralvaghela.movenow

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Locale

class MoveNowLargeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val steps = prefs.getInt("stepsToday", 0)
        val distance = prefs.getFloat("distanceToday", 0f).toDouble()
        val status = prefs.getString("currentActivity", "STILL") ?: "STILL"
        val isPaused = prefs.getBoolean("isPaused", false)
        val lastWalkTime = prefs.getLong("lastWalkTime", System.currentTimeMillis())
        val inactivityTimeoutMs = prefs.getLong("flutter.inactivityTimeoutMs", 60 * 60 * 1000)
        val requiredDistanceMeters = try {
            prefs.getFloat("flutter.requiredDistanceMeters", 100f).toDouble()
        } catch (e: Exception) {
            try {
                prefs.getLong("flutter.requiredDistanceMeters", 100L).toDouble()
            } catch (e2: Exception) {
                100.0
            }
        }
        val currentPeriodSteps = prefs.getInt("currentPeriodSteps", 0)
        val metersPerStep = try {
            prefs.getFloat("flutter.stepLengthMeters", 0.762f).toDouble()
        } catch (e: Exception) {
            try {
                val rawLong = prefs.getLong("flutter.stepLengthMeters", java.lang.Double.doubleToRawLongBits(0.762))
                val doubleVal = java.lang.Double.longBitsToDouble(rawLong)
                if (doubleVal <= 0.1) 0.762 else doubleVal
            } catch (e2: Exception) {
                0.762
            }
        }
        val units = prefs.getString("flutter.units", "meters") ?: "meters"

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_large_layout)
            
            // Format steps & distance
            views.setTextViewText(R.id.widget_large_steps, "$steps Steps")
            
            val distanceText = if (units == "km") {
                String.format(Locale.getDefault(), "%.2f km walked", distance / 1000.0)
            } else {
                "${distance.toInt()} m walked"
            }
            views.setTextViewText(R.id.widget_large_distance, distanceText)

            // Format status badge
            val displayStatus = if (isPaused) "PAUSED" else status
            views.setTextViewText(R.id.widget_large_status, displayStatus)
            
            val badgeColor = when (displayStatus) {
                "WALKING", "RUNNING" -> 0xFF4CAF50.toInt()
                "PAUSED" -> 0xFFFF9800.toInt()
                "STANDING" -> 0xFF2196F3.toInt()
                else -> 0xFF888888.toInt()
            }
            views.setTextColor(R.id.widget_large_status, badgeColor)

            // Countdown
            val remainingMs = inactivityTimeoutMs - (System.currentTimeMillis() - lastWalkTime)
            val minutesLeft = (remainingMs / (1000 * 60)).toInt()
            val countdownText = when {
                isPaused -> "Paused"
                minutesLeft <= 0 -> "0 min left"
                else -> "$minutesLeft min left"
            }
            views.setTextViewText(R.id.widget_large_countdown, countdownText)

            // Progress/Help Text
            val currentPeriodDistance = currentPeriodSteps * metersPerStep
            val remainingDist = requiredDistanceMeters - currentPeriodDistance
            val progressText = when {
                isPaused -> "Monitoring is paused"
                remainingDist <= 0 -> "Walk complete! Timer reset"
                else -> {
                    val unitStr = if (units == "km") "km" else "m"
                    val displayDist = if (units == "km") remainingDist / 1000.0 else remainingDist
                    val formatStr = if (units == "km") "%.2f" else "%.0f"
                    "Walk " + String.format(Locale.getDefault(), formatStr, displayDist) + " $unitStr to reset"
                }
            }
            views.setTextViewText(R.id.widget_large_progress_text, progressText)

            // Pause/Resume Button
            val buttonAction = if (isPaused) MoveNowForegroundService.ACTION_RESUME else MoveNowForegroundService.ACTION_PAUSE
            val buttonText = if (isPaused) "Resume" else "Pause"
            views.setTextViewText(R.id.widget_btn_pause, buttonText)

            val actionIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                action = buttonAction
            }
            val actionPendingIntent = PendingIntent.getBroadcast(
                context, appWidgetId, actionIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_pause, actionPendingIntent)

            // Open App on clicking steps layout
            val appIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val appPendingIntent = PendingIntent.getActivity(
                context, appWidgetId + 100, appIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_large_steps, appPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val thisAppWidget = ComponentName(context.packageName, MoveNowLargeWidgetProvider::class.java.name)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
        onUpdate(context, appWidgetManager, appWidgetIds)
    }
}
