package com.viralvaghela.movenow

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.database.sqlite.SQLiteDatabase
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.sqrt

class MoveNowForegroundService : Service(), SensorEventListener {

    companion object {
        private const val TAG = "MoveNowService"
        private const val CHANNEL_ID = "MoveNowServiceChannel"
        private const val ALARM_CHANNEL_ID = "MoveNowAlarmChannel"
        private const val NOTIFICATION_ID = 888
        private const val ALARM_NOTIFICATION_ID = 999

        // Action constants
        const val ACTION_START = "com.viralvaghela.movenow.START"
        const val ACTION_STOP = "com.viralvaghela.movenow.STOP"
        const val ACTION_PAUSE = "com.viralvaghela.movenow.PAUSE"
        const val ACTION_RESUME = "com.viralvaghela.movenow.RESUME"
        const val ACTION_RESET = "com.viralvaghela.movenow.RESET"
        const val ACTION_DISMISS_ALARM = "com.viralvaghela.movenow.DISMISS_ALARM"
        const val ACTION_UPDATE_SETTINGS = "com.viralvaghela.movenow.UPDATE_SETTINGS"
    }

    private lateinit var sensorManager: SensorManager
    private var stepCounterSensor: Sensor? = null
    private var stepDetectorSensor: Sensor? = null
    private var accelerometerSensor: Sensor? = null

    // Database and Prefs
    private lateinit var dbHelper: DatabaseHelper
    private lateinit var prefs: SharedPreferences

    // Service State
    private var isPaused = false
    private var lastWalkTime: Long = 0
    private var startStepsVal = -1
    private var currentPeriodSteps = 0
    private var stepsToday = 0
    private var distanceToday = 0.0
    private var currentActivity = "STILL"
    private var isAlarmActive = false
    private var alarmStartTime: Long = 0

    // Configurable Settings (cached, updated on update_settings)
    private var inactivityTimeoutMs: Long = 60 * 60 * 1000 // 60 min
    private var requiredDistanceMeters: Double = 100.0 // 100 meters
    private var metersPerStep: Double = 0.762
    private var alarmVolume: Int = 100
    private var alarmSoundPath: String = ""
    private var vibratePatternIndex: Int = 0 // 0 = standard, 1 = heartbeat, 2 = fast
    private var quietHoursEnabled: Boolean = false
    private var quietHoursStart: String = "22:00"
    private var quietHoursEnd: String = "07:00"
    private var units: String = "meters" // meters or km

    // Fallback Step Detector variables
    private var lastAccelMagnitude = 0.0
    private var lastStepDetectionTime: Long = 0
    private val stepCooldownMs = 300
    private var accelStepThreshold = 11.8 // m/s^2

    // Media and Vibrator
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: android.os.PowerManager.WakeLock? = null

    // Background Thread Handler
    private val handler = Handler(Looper.getMainLooper())
    private val ticker = object : Runnable {
        override fun run() {
            onTick()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate() {
        super.onCreate()
        
        // Acquire partial wake lock to keep CPU awake for background tracking
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
            wakeLock = powerManager.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "MoveNow::TrackingWakeLock").apply {
                acquire()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to acquire WakeLock: ${e.message}")
        }

        dbHelper = DatabaseHelper(this)
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepCounterSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        stepDetectorSensor = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        accelerometerSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibratorManager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }

        // Initialize state
        loadSettings()
        loadServiceState()
        createNotificationChannels()
        registerSensors()

        // Log service start
        dbHelper.insertEvent("inactivity", 0, 0, 0.0, "Service started, tracking initiated.")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START
        Log.d(TAG, "onStartCommand action: $action")

        if (action != ACTION_STOP) {
            startForegroundServiceCompat()
        }

        when (action) {
            ACTION_START -> {
                handler.removeCallbacks(ticker)
                handler.post(ticker)
            }
            ACTION_STOP -> {
                stopForegroundService()
            }
            ACTION_PAUSE -> {
                pauseMonitoring()
            }
            ACTION_RESUME -> {
                resumeMonitoring()
            }
            ACTION_RESET -> {
                resetInactivityTimer(manual = true)
            }
            ACTION_DISMISS_ALARM -> {
                dismissAlarm(manual = true)
            }
            ACTION_UPDATE_SETTINGS -> {
                loadSettings()
                registerSensors()
                updateWidgets()
                sendUpdateBroadcast()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(ticker)
        unregisterSensors()
        stopAlarmHardware()
        saveServiceState()
        
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release WakeLock: ${e.message}")
        }

        dbHelper.insertEvent("inactivity", 0, 0, 0.0, "Service stopped.")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // Register Pedometer and Accelerometer Sensors
    private fun registerSensors() {
        // Unregister first to avoid duplicate listeners
        sensorManager.unregisterListener(this)

        val hasActivityPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            androidx.core.content.ContextCompat.checkSelfPermission(
                this, 
                android.Manifest.permission.ACTIVITY_RECOGNITION
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        if (hasActivityPermission) {
            if (stepDetectorSensor != null) {
                sensorManager.registerListener(this, stepDetectorSensor, SensorManager.SENSOR_DELAY_FASTEST)
                Log.d(TAG, "Hardware step detector sensor registered successfully")
            } else if (stepCounterSensor != null) {
                sensorManager.registerListener(this, stepCounterSensor, SensorManager.SENSOR_DELAY_NORMAL)
                Log.d(TAG, "Hardware step counter sensor registered successfully")
            } else {
                Log.d(TAG, "No hardware step sensors available on this device")
            }
        } else {
            Log.d(TAG, "ACTIVITY_RECOGNITION permission not granted. Relying on accelerometer fallback.")
        }

        // Always register accelerometer for activity recognition and step fallback
        if (accelerometerSensor != null) {
            sensorManager.registerListener(this, accelerometerSensor, SensorManager.SENSOR_DELAY_UI)
        }
    }

    private fun unregisterSensors() {
        sensorManager.unregisterListener(this)
    }

    // Load configs from SharedPreferences
    private fun loadSettings() {
        inactivityTimeoutMs = prefs.getLong("flutter.inactivityTimeoutMs", 60 * 60 * 1000)
        requiredDistanceMeters = try {
            prefs.getFloat("flutter.requiredDistanceMeters", 100f).toDouble()
        } catch (e: Exception) {
            try {
                prefs.getLong("flutter.requiredDistanceMeters", 100L).toDouble()
            } catch (e2: Exception) {
                100.0
            }
        }
        metersPerStep = try {
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
        alarmVolume = try {
            prefs.getLong("flutter.alarmVolume", 100L).toInt()
        } catch (e: Exception) {
            try {
                prefs.getInt("flutter.alarmVolume", 100)
            } catch (e2: Exception) {
                100
            }
        }
        alarmSoundPath = prefs.getString("flutter.alarmSoundPath", "") ?: ""
        vibratePatternIndex = try {
            prefs.getLong("flutter.vibratePatternIndex", 0L).toInt()
        } catch (e: Exception) {
            try {
                prefs.getInt("flutter.vibratePatternIndex", 0)
            } catch (e2: Exception) {
                0
            }
        }
        quietHoursEnabled = prefs.getBoolean("flutter.quietHoursEnabled", false)
        quietHoursStart = prefs.getString("flutter.quietHoursStart", "22:00") ?: "22:00"
        quietHoursEnd = prefs.getString("flutter.quietHoursEnd", "07:00") ?: "07:00"
        units = prefs.getString("flutter.units", "meters") ?: "meters"
        accelStepThreshold = prefs.getFloat("accelStepThreshold", 11.8f).toDouble()
    }

    private fun loadServiceState() {
        isPaused = prefs.getBoolean("isPaused", false)
        lastWalkTime = prefs.getLong("lastWalkTime", System.currentTimeMillis())
        startStepsVal = prefs.getInt("startStepsVal", -1)
        currentPeriodSteps = prefs.getInt("currentPeriodSteps", 0)
        stepsToday = prefs.getInt("stepsToday", 0)
        distanceToday = prefs.getFloat("distanceToday", 0f).toDouble()
        isAlarmActive = prefs.getBoolean("isAlarmActive", false)
        currentActivity = prefs.getString("currentActivity", "STILL") ?: "STILL"
        if (isAlarmActive) {
            alarmStartTime = prefs.getLong("alarmStartTime", System.currentTimeMillis())
            // If it was ringing when destroyed, ring again!
            triggerAlarm()
        }
    }

    private fun saveServiceState() {
        prefs.edit().apply {
            putBoolean("isPaused", isPaused)
            putLong("lastWalkTime", lastWalkTime)
            putInt("startStepsVal", startStepsVal)
            putInt("currentPeriodSteps", currentPeriodSteps)
            putInt("stepsToday", stepsToday)
            putFloat("distanceToday", distanceToday.toFloat())
            putBoolean("isAlarmActive", isAlarmActive)
            putLong("alarmStartTime", alarmStartTime)
            putString("currentActivity", currentActivity)
            apply()
        }
        updateWidgets()
        sendUpdateBroadcast()
    }

    // 1-second Tick Loop
    private fun onTick() {
        val now = System.currentTimeMillis()
        
        // Midnight reset check
        val lastDate = prefs.getString("lastDateString", "")
        val currentDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        if (lastDate != currentDate) {
            // Log daily summary
            if (stepsToday > 0) {
                dbHelper.insertEvent("walk", 0, stepsToday, distanceToday, "Daily activity transition reset.")
            }
            stepsToday = 0
            distanceToday = 0.0
            prefs.edit().putString("lastDateString", currentDate).apply()
            resetInactivityTimer(manual = false)
        }

        // Active countdown check
        if (!isPaused && !isAlarmActive) {
            val elapsedTime = now - lastWalkTime
            if (elapsedTime >= inactivityTimeoutMs) {
                if (shouldTriggerAlarm()) {
                    triggerAlarm()
                } else {
                    // Suppressed (e.g. Quiet Hours) - extend timer slightly so it doesn't try to trigger every second
                    lastWalkTime = now - inactivityTimeoutMs + (5 * 60 * 1000)
                    saveServiceState()
                }
            }
        }

        // Update active stats
        saveServiceState()
        updateNotification()
        updateWidgets()

        // Send Broadcast update for real-time Flutter EventChannel
        sendUpdateBroadcast()
    }

    private fun sendUpdateBroadcast() {
        val intent = Intent("com.viralvaghela.movenow.UPDATE").apply {
            setPackage(packageName)
        }
        intent.putExtra("isPaused", isPaused)
        intent.putExtra("lastWalkTime", lastWalkTime)
        intent.putExtra("currentPeriodSteps", currentPeriodSteps)
        intent.putExtra("stepsToday", stepsToday)
        intent.putExtra("distanceToday", distanceToday)
        intent.putExtra("currentActivity", currentActivity)
        intent.putExtra("isAlarmActive", isAlarmActive)
        intent.putExtra("inactivityTimeoutMs", inactivityTimeoutMs)
        intent.putExtra("requiredDistanceMeters", requiredDistanceMeters)
        sendBroadcast(intent)
    }

    private fun shouldTriggerAlarm(): Boolean {
        if (quietHoursEnabled) {
            val nowCalendar = Calendar.getInstance()
            val hour = nowCalendar.get(Calendar.HOUR_OF_DAY)
            val minute = nowCalendar.get(Calendar.MINUTE)
            val nowTime = String.format(Locale.getDefault(), "%02d:%02d", hour, minute)

            // Simple check: start <= nowTime || nowTime <= end (handles overnight quiet hours)
            if (quietHoursStart < quietHoursEnd) {
                if (nowTime >= quietHoursStart && nowTime <= quietHoursEnd) return false
            } else { // Over midnight quiet hours
                if (nowTime >= quietHoursStart || nowTime <= quietHoursEnd) return false
            }
        }
        return true
    }

    // Monitoring Management
    private fun pauseMonitoring() {
        isPaused = true
        currentActivity = "PAUSED"
        dbHelper.insertEvent("inactivity", 0, 0, 0.0, "Monitoring paused.")
        if (isAlarmActive) dismissAlarm(manual = true)
        saveServiceState()
        updateNotification()
        updateWidgets()
    }

    private fun resumeMonitoring() {
        isPaused = false
        currentActivity = "STILL"
        lastWalkTime = System.currentTimeMillis()
        startStepsVal = -1
        currentPeriodSteps = 0
        dbHelper.insertEvent("inactivity", 0, 0, 0.0, "Monitoring resumed.")
        saveServiceState()
        updateNotification()
        updateWidgets()
    }

    private fun resetInactivityTimer(manual: Boolean) {
        val now = System.currentTimeMillis()
        val duration = ((now - lastWalkTime) / 1000).toInt()

        if (manual) {
            dbHelper.insertEvent("inactivity", duration, currentPeriodSteps, currentPeriodSteps * metersPerStep, "Timer manually reset.")
        } else if (currentPeriodSteps > 0) {
            dbHelper.insertEvent("walk", duration, currentPeriodSteps, currentPeriodSteps * metersPerStep, "Walking threshold reached, timer reset.")
        }

        lastWalkTime = now
        startStepsVal = -1
        currentPeriodSteps = 0
        if (isAlarmActive) dismissAlarm(manual = false)
        saveServiceState()
        updateNotification()
        updateWidgets()
    }

    // Alarm Trigger and Actions
    private fun triggerAlarm() {
        if (isAlarmActive && mediaPlayer?.isPlaying == true) return

        isAlarmActive = true
        alarmStartTime = System.currentTimeMillis()
        saveServiceState()

        dbHelper.insertEvent("alarm_trigger", 0, 0, 0.0, "Inactivity threshold exceeded! Alarm triggered.")

        // Start playing alarm sound
        startAlarmHardware()

        // Show High Priority ringing notification
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(ALARM_NOTIFICATION_ID, buildAlarmNotification())
    }

    private fun startAlarmHardware() {
        // Sound
        try {
            mediaPlayer?.release()
            
            val soundUri = if (alarmSoundPath.isNotEmpty()) {
                Uri.parse(alarmSoundPath)
            } else {
                android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI
                    ?: android.provider.Settings.System.DEFAULT_RINGTONE_URI
            }

            mediaPlayer = MediaPlayer().apply {
                setDataSource(this@MoveNowForegroundService, soundUri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                isLooping = true
                val volume = alarmVolume / 100f
                setVolume(volume, volume)
                prepare()
                start()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting alarm media player: ${e.message}")
        }

        // Vibration
        try {
            val pattern = when (vibratePatternIndex) {
                1 -> longArrayOf(0, 1000, 500, 1000, 500) // Heartbeat
                2 -> longArrayOf(0, 300, 200, 300, 200, 300, 200) // Fast
                else -> longArrayOf(0, 1000, 1000) // Standard continuous
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0)) // Loop from index 0
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(pattern, 0)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting vibrator: ${e.message}")
        }
    }

    private fun stopAlarmHardware() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping media player: ${e.message}")
        }

        try {
            vibrator?.cancel()
        } catch (e: Exception) {
            Log.e(TAG, "Error canceling vibrator: ${e.message}")
        }
    }

    private fun dismissAlarm(manual: Boolean) {
        if (!isAlarmActive) return

        isAlarmActive = false
        stopAlarmHardware()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(ALARM_NOTIFICATION_ID)

        val duration = ((System.currentTimeMillis() - alarmStartTime) / 1000).toInt()
        val detailMsg = if (manual) "Alarm manually dismissed by user." else "Alarm auto-dismissed (walking threshold achieved)."
        dbHelper.insertEvent("alarm_dismiss", duration, currentPeriodSteps, currentPeriodSteps * metersPerStep, detailMsg)

        // Reset the timer when alarm is resolved!
        lastWalkTime = System.currentTimeMillis()
        startStepsVal = -1
        currentPeriodSteps = 0
        saveServiceState()
        updateNotification()
        updateWidgets()
    }

    // Step Counter and Sensor Listeners
    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return

        if (event.sensor.type == Sensor.TYPE_STEP_DETECTOR) {
            onStepDetected()
        } else if (event.sensor.type == Sensor.TYPE_STEP_COUNTER) {
            val totalStepsVal = event.values[0].toInt()
            onStepTaken(totalStepsVal)
        } else if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
            processAccelerometer(event.values[0], event.values[1], event.values[2])
        }
    }

    private fun onStepDetected() {
        if (isPaused) return

        currentPeriodSteps += 1
        stepsToday += 1
        
        val distDelta = 1 * metersPerStep
        distanceToday += distDelta

        currentActivity = "WALKING"

        // Log hourly steps in the DB
        dbHelper.logHourlySteps(1, distDelta)

        // Check if required distance in the current inactivity period has been reached
        val currentDistance = currentPeriodSteps * metersPerStep
        if (currentDistance >= requiredDistanceMeters) {
            resetInactivityTimer(manual = false)
        }
        saveServiceState()
    }

    private fun onStepTaken(totalStepsVal: Int) {
        if (isPaused) return

        if (startStepsVal == -1) {
            startStepsVal = totalStepsVal
            saveServiceState()
            return
        }

        val stepDelta = totalStepsVal - (startStepsVal + currentPeriodSteps)
        if (stepDelta > 0) {
            currentPeriodSteps += stepDelta
            stepsToday += stepDelta
            
            val distDelta = stepDelta * metersPerStep
            distanceToday += distDelta

            currentActivity = "WALKING"

            // Log hourly steps in the DB
            dbHelper.logHourlySteps(stepDelta, distDelta)

            // Check if required distance in the current inactivity period has been reached
            val currentDistance = currentPeriodSteps * metersPerStep
            if (currentDistance >= requiredDistanceMeters) {
                resetInactivityTimer(manual = false)
            }
            saveServiceState()
        }
    }

    // Fallback Step Detector & Activity Recognition via Accelerometer
    private fun processAccelerometer(x: Float, y: Float, z: Float) {
        val magnitude = sqrt((x * x + y * y + z * z).toDouble())
        
        // Activity determination based on motion intensity
        val diff = Math.abs(magnitude - 9.8)
        currentActivity = when {
            isPaused -> "PAUSED"
            diff > 3.5 -> "RUNNING"
            diff > 0.8 -> "WALKING"
            diff > 0.2 -> "STANDING"
            else -> "STILL"
        }

        val hasActivityPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            androidx.core.content.ContextCompat.checkSelfPermission(
                this, 
                android.Manifest.permission.ACTIVITY_RECOGNITION
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        // Fallback Step Detector if hardware sensors are missing or permission is denied
        val useAccelerometerFallback = (stepDetectorSensor == null && stepCounterSensor == null) || !hasActivityPermission
        if (useAccelerometerFallback) {
            val now = System.currentTimeMillis()
            if (magnitude > accelStepThreshold && (now - lastStepDetectionTime) > stepCooldownMs) {
                lastStepDetectionTime = now
                // Simulate a step count update
                if (startStepsVal == -1) startStepsVal = 0
                
                currentPeriodSteps += 1
                stepsToday += 1
                
                val distDelta = 1 * metersPerStep
                distanceToday += distDelta
                
                dbHelper.logHourlySteps(1, distDelta)

                val currentDistance = currentPeriodSteps * metersPerStep
                if (currentDistance >= requiredDistanceMeters) {
                    resetInactivityTimer(manual = false)
                }
                saveServiceState()
            }
        }
        lastAccelMagnitude = magnitude
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    // Foreground service startup and notification logic
    private fun startForegroundServiceCompat() {
        val notification = buildForegroundNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopForegroundService() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildForegroundNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Broadcast intents for actions
        val pauseIntent = Intent(this, NotificationActionReceiver::class.java).apply { action = ACTION_PAUSE }
        val pausePendingIntent = PendingIntent.getBroadcast(this, 1, pauseIntent, PendingIntent.FLAG_IMMUTABLE)

        val resumeIntent = Intent(this, NotificationActionReceiver::class.java).apply { action = ACTION_RESUME }
        val resumePendingIntent = PendingIntent.getBroadcast(this, 2, resumeIntent, PendingIntent.FLAG_IMMUTABLE)

        val resetIntent = Intent(this, NotificationActionReceiver::class.java).apply { action = ACTION_RESET }
        val resetPendingIntent = PendingIntent.getBroadcast(this, 3, resetIntent, PendingIntent.FLAG_IMMUTABLE)

        val timeString = formatTimeRemaining()
        val distanceString = formatDistanceRemaining()

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("MoveNow - Tracking Active")
            .setContentText("$timeString left | $distanceString remaining")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setContentIntent(pendingIntent)
            .setOngoing(true)

        if (isPaused) {
            builder.setContentTitle("MoveNow - Monitoring Paused")
            builder.setContentText("Activity monitoring is suspended")
            builder.addAction(android.R.drawable.ic_media_play, "Resume", resumePendingIntent)
        } else {
            builder.addAction(android.R.drawable.ic_media_pause, "Pause", pausePendingIntent)
            builder.addAction(android.R.drawable.ic_menu_rotate, "Reset Timer", resetPendingIntent)
        }

        return builder.build()
    }

    private fun buildAlarmNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val dismissIntent = Intent(this, NotificationActionReceiver::class.java).apply { action = ACTION_DISMISS_ALARM }
        val dismissPendingIntent = PendingIntent.getBroadcast(this, 4, dismissIntent, PendingIntent.FLAG_IMMUTABLE)

        return NotificationCompat.Builder(this, ALARM_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Inactivity Warning!")
            .setContentText("You have been sitting too long. Walk 100 meters to clear.")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(Notification.CATEGORY_ALARM)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true) // Launches main screen directly
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Dismiss Alarm", dismissPendingIntent)
            .build()
    }

    private fun updateNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, buildForegroundNotification())

        if (isAlarmActive) {
            notificationManager.notify(ALARM_NOTIFICATION_ID, buildAlarmNotification())
        }
    }

    private fun formatTimeRemaining(): String {
        if (isPaused) return "Paused"
        val remainingMs = inactivityTimeoutMs - (System.currentTimeMillis() - lastWalkTime)
        if (remainingMs <= 0) return "0 min"
        val min = (remainingMs / (1000 * 60)).toInt()
        return "$min min"
    }

    private fun formatDistanceRemaining(): String {
        val currentDistance = currentPeriodSteps * metersPerStep
        val remaining = requiredDistanceMeters - currentDistance
        if (remaining <= 0) return "0m"
        
        return if (units == "km") {
            String.format(Locale.getDefault(), "%.2f km", remaining / 1000.0)
        } else {
            "${remaining.toInt()}m"
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Background Service Channel
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "MoveNow Tracker Channel",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows the active sitting tracker status."
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(serviceChannel)

            // Alarm Channel
            val alarmChannel = NotificationChannel(
                ALARM_CHANNEL_ID,
                "MoveNow Alarm Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Sounds alarms when you remain inactive for too long."
                enableVibration(true)
                enableLights(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(alarmChannel)
        }
    }

    // Update Widgets
    private fun updateWidgets() {
        // Small Widget
        val updateSmallIntent = Intent(this, MoveNowSmallWidgetProvider::class.java).apply {
            action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        sendBroadcast(updateSmallIntent)

        // Large Widget
        val updateLargeIntent = Intent(this, MoveNowLargeWidgetProvider::class.java).apply {
            action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        sendBroadcast(updateLargeIntent)
    }
}
