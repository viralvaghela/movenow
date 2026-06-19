package com.viralvaghela.movenow

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlin.math.abs
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.viralvaghela.movenow/service"
    private val EVENT_CHANNEL = "com.viralvaghela.movenow/updates"

    private lateinit var dbHelper: DatabaseHelper
    private lateinit var prefs: SharedPreferences
    private var eventSink: EventChannel.EventSink? = null
    private var updateReceiver: BroadcastReceiver? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        dbHelper = DatabaseHelper(this)
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // Automatically start service on launch if it is enabled and permission is granted
        val serviceEnabled = prefs.getBoolean("service_enabled", true)
        val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            androidx.core.content.ContextCompat.checkSelfPermission(
                this, 
                android.Manifest.permission.ACTIVITY_RECOGNITION
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED
        } else {
            true
        }

        if (serviceEnabled && hasPermission) {
            val intent = Intent(this, MoveNowForegroundService::class.java).apply {
                action = MoveNowForegroundService.ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel Setup
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    // Mark service as enabled in preferences
                    prefs.edit().putBoolean("service_enabled", true).apply()
                    val intent = Intent(this, MoveNowForegroundService::class.java).apply {
                        action = MoveNowForegroundService.ACTION_START
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stopService" -> {
                    prefs.edit().putBoolean("service_enabled", false).apply()
                    val intent = Intent(this, MoveNowForegroundService::class.java).apply {
                        action = MoveNowForegroundService.ACTION_STOP
                    }
                    stopService(intent)
                    result.success(true)
                }
                "pauseService" -> {
                    sendServiceAction(MoveNowForegroundService.ACTION_PAUSE)
                    result.success(true)
                }
                "resumeService" -> {
                    sendServiceAction(MoveNowForegroundService.ACTION_RESUME)
                    result.success(true)
                }
                "resetTimer" -> {
                    sendServiceAction(MoveNowForegroundService.ACTION_RESET)
                    result.success(true)
                }
                "dismissAlarm" -> {
                    sendServiceAction(MoveNowForegroundService.ACTION_DISMISS_ALARM)
                    result.success(true)
                }
                "updateSettings" -> {
                    sendServiceAction(MoveNowForegroundService.ACTION_UPDATE_SETTINGS)
                    result.success(true)
                }
                "getServiceState" -> {
                    val stateMap = getServiceStateMap()
                    result.success(stateMap)
                }
                "getHistory" -> {
                    val history = dbHelper.getEventsList()
                    result.success(history)
                }
                "getHourlySteps" -> {
                    val hourly = dbHelper.getHourlyStepsList()
                    result.success(hourly)
                }
                "clearHistory" -> {
                    dbHelper.clearAll()
                    result.success(true)
                }
                "calibrateAccelerometer" -> {
                    val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
                    val accel = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                    if (accel == null) {
                        result.error("SENSOR_ERROR", "Accelerometer not found on this device", null)
                    } else {
                        val magnitudes = ArrayList<Double>()
                        val listener = object : SensorEventListener {
                            override fun onSensorChanged(event: SensorEvent?) {
                                if (event != null) {
                                    val x = event.values[0]
                                    val y = event.values[1]
                                    val z = event.values[2]
                                    val mag = sqrt((x * x + y * y + z * z).toDouble())
                                    magnitudes.add(mag)
                                }
                            }
                            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                        }

                        sensorManager.registerListener(listener, accel, SensorManager.SENSOR_DELAY_FASTEST)

                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            sensorManager.unregisterListener(listener)

                            if (magnitudes.isEmpty()) {
                                result.error("CALIBRATION_FAILED", "No sensor data collected", null)
                                return@postDelayed
                            }

                            val averageGravity = magnitudes.average()
                            var maxDeviation = 0.0
                            for (mag in magnitudes) {
                                val deviation = abs(mag - averageGravity)
                                if (deviation > maxDeviation) {
                                    maxDeviation = deviation
                                }
                            }

                            val rawThreshold = averageGravity + maxDeviation + 1.2
                            val threshold = rawThreshold.coerceIn(10.2, 15.0)

                            prefs.edit().putFloat("accelStepThreshold", threshold.toFloat()).apply()

                            sendServiceAction(MoveNowForegroundService.ACTION_UPDATE_SETTINGS)

                            val response = HashMap<String, Any>()
                            response["success"] = true
                            response["noiseFloor"] = maxDeviation
                            response["newThreshold"] = threshold
                            result.success(response)
                        }, 3000)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // EventChannel Setup
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerUpdateReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterUpdateReceiver()
                    eventSink = null
                }
            }
        )
    }

    private fun sendServiceAction(action: String) {
        val intent = Intent(this, MoveNowForegroundService::class.java).apply {
            this.action = action
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun getServiceStateMap(): Map<String, Any> {
        val map = HashMap<String, Any>()
        map["isPaused"] = prefs.getBoolean("isPaused", false)
        map["lastWalkTime"] = prefs.getLong("lastWalkTime", System.currentTimeMillis())
        map["currentPeriodSteps"] = prefs.getInt("currentPeriodSteps", 0)
        map["stepsToday"] = prefs.getInt("stepsToday", 0)
        map["distanceToday"] = prefs.getFloat("distanceToday", 0f).toDouble()
        map["currentActivity"] = prefs.getString("currentActivity", "STILL") ?: "STILL"
        map["isAlarmActive"] = prefs.getBoolean("isAlarmActive", false)
        map["inactivityTimeoutMs"] = prefs.getLong("flutter.inactivityTimeoutMs", 60 * 60 * 1000)
        
        val reqDistance = try {
            prefs.getFloat("flutter.requiredDistanceMeters", 100f).toDouble()
        } catch (e: Exception) {
            try {
                prefs.getLong("flutter.requiredDistanceMeters", 100L).toDouble()
            } catch (e2: Exception) {
                100.0
            }
        }
        map["requiredDistanceMeters"] = reqDistance
        map["serviceEnabled"] = prefs.getBoolean("service_enabled", true)
        return map
    }

    private fun registerUpdateReceiver() {
        if (updateReceiver == null) {
            updateReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == "com.viralvaghela.movenow.UPDATE") {
                        val map = HashMap<String, Any>()
                        map["isPaused"] = intent.getBooleanExtra("isPaused", false)
                        map["lastWalkTime"] = intent.getLongExtra("lastWalkTime", System.currentTimeMillis())
                        map["currentPeriodSteps"] = intent.getIntExtra("currentPeriodSteps", 0)
                        map["stepsToday"] = intent.getIntExtra("stepsToday", 0)
                        map["distanceToday"] = intent.getDoubleExtra("distanceToday", 0.0)
                        map["currentActivity"] = intent.getStringExtra("currentActivity") ?: "STILL"
                        map["isAlarmActive"] = intent.getBooleanExtra("isAlarmActive", false)
                        map["inactivityTimeoutMs"] = intent.getLongExtra("inactivityTimeoutMs", 60 * 60 * 1000)
                        map["requiredDistanceMeters"] = intent.getDoubleExtra("requiredDistanceMeters", 100.0)
                        
                        eventSink?.success(map)
                    }
                }
            }
            val filter = IntentFilter("com.viralvaghela.movenow.UPDATE")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(updateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(updateReceiver, filter)
            }
        }
    }

    private fun unregisterUpdateReceiver() {
        updateReceiver?.let {
            unregisterReceiver(it)
            updateReceiver = null
        }
    }

    override fun onDestroy() {
        unregisterUpdateReceiver()
        super.onDestroy()
    }
}
