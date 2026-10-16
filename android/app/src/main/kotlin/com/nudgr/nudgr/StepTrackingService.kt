package com.nudgr.nudgr

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class StepTrackingService : Service(), SensorEventListener {

    private var sensorManager: SensorManager? = null
    private var registered = false
    private var baseline = 0
    private var baselineValid = false
    private var offset = 0
    private var goal = 10000
    private var lastDailySteps = -1
    private var todayKey = ""
    private val dayFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            prefs().edit().putBoolean(PREF_STOPPED, true).apply()
            stopSelf()
            return START_NOT_STICKY
        }

        goal = intent?.getIntExtra(EXTRA_GOAL, 10000) ?: 10000
        todayKey = dayFormat.format(Date())

        val storedDate = prefs().getString(PREF_DATE, null)
        val storedBaseline = prefs().getInt(PREF_BASELINE, -1)
        val storedOffset = prefs().getInt(PREF_OFFSET, 0)
        var initialSteps: Int
        if (storedDate == todayKey && storedBaseline > 0) {
            baseline = storedBaseline
            baselineValid = true
            offset = storedOffset.coerceAtLeast(0)
            initialSteps = prefs().getInt(PREF_STEPS, 0).coerceAtLeast(0)
        } else {
            val passedBaseline = intent?.getIntExtra(EXTRA_BASELINE, 0) ?: 0
            val passedSteps = intent?.getIntExtra(EXTRA_STEPS, 0) ?: 0
            baseline = passedBaseline
            baselineValid = passedBaseline > 0
            offset = 0
            initialSteps = if (baselineValid) passedSteps.coerceAtLeast(0) else 0
        }
        lastDailySteps = initialSteps

        val notification = buildNotification(initialSteps, goal)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        isRunning = true

        if (!registered) {
            sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            val sensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
            if (sensor != null) {
                sensorManager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)
                registered = true
            }
        }
        return START_STICKY
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type != Sensor.TYPE_STEP_COUNTER) return
        val cumulative = event.values.firstOrNull()?.toInt() ?: return
        if (cumulative <= 0) return

        val today = dayFormat.format(Date())
        if (today != todayKey) {
            todayKey = today
            val lastCum = prefs().getInt(PREF_LAST_CUM, 0)
            baseline = if (lastCum in 1..cumulative) lastCum else cumulative
            baselineValid = true
            offset = 0
            lastDailySteps = -1
        }

        if (!baselineValid) {
            val lastCum = prefs().getInt(PREF_LAST_CUM, 0)
            val sameDayAnchor =
                prefs().getString(PREF_DATE, null) == todayKey && lastCum in 1..cumulative
            baseline = if (sameDayAnchor) lastCum else cumulative
            baselineValid = true
        } else if (cumulative < baseline) {
            val priorSteps = if (todayKey == prefs().getString(PREF_DATE, null)) {
                prefs().getInt(PREF_STEPS, 0)
            } else {
                0
            }
            offset = priorSteps.coerceAtLeast(0)
            baseline = cumulative
        }

        val steps = (offset + (cumulative - baseline)).coerceIn(0, 1000000)
        prefs().edit()
            .putInt(PREF_STEPS, steps)
            .putInt(PREF_BASELINE, baseline)
            .putInt(PREF_OFFSET, offset)
            .putInt(PREF_LAST_CUM, cumulative)
            .putString(PREF_DATE, todayKey)
            .putLong(PREF_UPDATED, System.currentTimeMillis())
            .apply()

        if (steps != lastDailySteps) {
            lastDailySteps = steps
            notifySteps(steps, goal)
        }

        try {
            MainActivity.stepChannel?.invokeMethod("onStepUpdate", cumulative)
        } catch (_: Exception) {
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onDestroy() {
        if (registered) {
            sensorManager?.unregisterListener(this)
            registered = false
        }
        isRunning = false
        super.onDestroy()
    }

    private fun prefs() = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Step Tracking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows your daily step progress"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(steps: Int, goal: Int): Notification {
        val stopIntent = PendingIntent.getService(
            this, 0,
            Intent(this, StepTrackingService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Nudgr is counting your steps")
            .setContentText("$steps of $goal steps today")
            .setSmallIcon(android.R.drawable.ic_menu_directions)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(goal.coerceAtLeast(1), steps.coerceAtMost(goal), false)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Pause",
                stopIntent
            )
            .build()
    }

    private fun notifySteps(steps: Int, goal: Int) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(steps, goal))
    }

    companion object {
        const val CHANNEL_ID = "step_tracking"
        const val NOTIFICATION_ID = 4242
        const val ACTION_STOP = "com.nudgr.nudgr.STOP_STEP_TRACKING"
        const val EXTRA_BASELINE = "baseline"
        const val EXTRA_GOAL = "goal"
        const val EXTRA_STEPS = "steps"

        const val PREF_STEPS = "flutter.step_fg_steps"
        const val PREF_BASELINE = "flutter.step_fg_baseline"
        const val PREF_OFFSET = "flutter.step_fg_offset"
        const val PREF_LAST_CUM = "flutter.step_fg_last_cum"
        const val PREF_DATE = "flutter.step_fg_date"
        const val PREF_UPDATED = "flutter.step_fg_updated"
        const val PREF_STOPPED = "flutter.step_fg_stopped"

        var isRunning = false
    }
}
