package com.nudgr.nudgr

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), SensorEventListener {
    private val STEP_CHANNEL = "com.nudgr.nudgr/step_counter"
    private val PERMISSION_CHANNEL = "com.nudgr.nudgr/permission"
    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null
    private var methodChannel: MethodChannel? = null
    private var isListening = false
    companion object {
        var stepChannel: MethodChannel? = null
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STEP_CHANNEL)
        stepChannel = methodChannel
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSensorAvailable" -> {
                    result.success(stepSensor != null)
                }
                "requestActivityPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else {
                            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), 1001)
                            result.success(false)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "isActivityPermissionGranted" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        result.success(ContextCompat.checkSelfPermission(this, Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED)
                    } else {
                        result.success(true)
                    }
                }
                "startListening" -> {
                    startStepListener()
                    result.success(null)
                }
                "stopListening" -> {
                    stopStepListener()
                    result.success(null)
                }
                "startForegroundTracking" -> {
                    val baseline = call.argument<Int>("baseline") ?: 0
                    val goal = call.argument<Int>("goal") ?: 10000
                    val steps = call.argument<Int>("steps") ?: 0
                    val intent = Intent(this, StepTrackingService::class.java)
                        .putExtra(StepTrackingService.EXTRA_BASELINE, baseline)
                        .putExtra(StepTrackingService.EXTRA_GOAL, goal)
                        .putExtra(StepTrackingService.EXTRA_STEPS, steps)
                    try {
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "stopForegroundTracking" -> {
                    stopService(Intent(this, StepTrackingService::class.java))
                    result.success(null)
                }
                "sendNotification" -> {
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    sendNotification(title, body)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    private fun startStepListener() {
        if (stepSensor != null && !isListening) {
            sensorManager?.registerListener(this, stepSensor, SensorManager.SENSOR_DELAY_UI)
            isListening = true
        }
    }
    private fun stopStepListener() {
        if (isListening) {
            sensorManager?.unregisterListener(this)
            isListening = false
        }
    }
    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_STEP_COUNTER) {
            val steps = event.values[0].toInt()
            methodChannel?.invokeMethod("onStepUpdate", steps)
        }
    }
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1001) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            methodChannel?.invokeMethod("onPermissionResult", granted)
            if (granted) {
                startStepListener()
            }
        }
    }
    private fun sendNotification(title: String, body: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    "general_alerts",
                    "Reminders",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "Goal achievements and reminders" }
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, "general_alerts")
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pending = if (launch != null) {
            PendingIntent.getActivity(
                this, 1, launch,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            null
        }
        builder.setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setSmallIcon(R.drawable.ic_stat_nudgr)
            .setAutoCancel(true)
        if (pending != null) {
            builder.setContentIntent(pending)
        }
        manager.notify(4343, builder.build())
    }
    override fun onPause() {
        super.onPause()
    }
    override fun onDestroy() {
        stopStepListener()
        super.onDestroy()
    }
}
