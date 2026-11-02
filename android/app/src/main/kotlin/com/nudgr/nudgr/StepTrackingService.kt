package com.nudgr.nudgr

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ServiceCompat

class StepTrackingService : Service(), SensorEventListener {
    private var sensorManager: SensorManager? = null
    private var registered = false
    private var baseline = 0
    private var todaySteps = 0
    private var goal = 10000

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        StepNotifications.ensureChannels(this)
        val prefs = prefs()
        if (intent?.action == StepContract.ACTION_SEND_NOTIFICATION) {
            startAsForeground()
            StepNotifications.postGoalAlert(
                this,
                intent.getStringExtra(StepContract.ARG_TITLE) ?: "Nudgr",
                intent.getStringExtra(StepContract.ARG_BODY) ?: "",
            )
            return START_STICKY
        }
        load(prefs)
        if (intent != null) {
            intent.getIntExtra(StepContract.ARG_BASELINE, baseline).let { baseline = it }
            intent.getIntExtra(StepContract.ARG_GOAL, goal).let { goal = it }
            intent.getIntExtra(StepContract.ARG_STEPS, todaySteps).let {
                if (it > todaySteps) todaySteps = it
            }
        }
        startAsForeground()
        registerSensor()
        save(prefs)
        return START_STICKY
    }

    private fun prefs(): SharedPreferences =
        getSharedPreferences(STORE_NAME, Context.MODE_PRIVATE)

    private fun load(prefs: SharedPreferences) {
        val today = StepDateKeys.today()
        if (prefs.getString("flutter.$DATE_KEY", "") != today) {
            baseline = 0
            todaySteps = 0
            return
        }
        baseline = prefs.getInt("flutter.$BASELINE_KEY", 0)
        todaySteps = prefs.getInt("flutter.$STEPS_KEY", 0)
        goal = prefs.getInt("flutter.$GOAL_KEY", goal)
    }

    private fun save(prefs: SharedPreferences) {
        prefs.edit()
            .putString("flutter.$DATE_KEY", StepDateKeys.today())
            .putInt("flutter.$BASELINE_KEY", baseline)
            .putInt("flutter.$STEPS_KEY", todaySteps)
            .putInt("flutter.$GOAL_KEY", goal)
            .putBoolean("flutter.step_fg_stopped", false)
            .apply()
    }

    private fun startAsForeground() {
        val notification = StepNotifications.trackingNotification(this, todaySteps, goal)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceCompat.startForeground(
                this,
                StepNotifications.TRACKING_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH,
            )
        } else {
            startForeground(StepNotifications.TRACKING_NOTIFICATION_ID, notification)
        }
        NotificationManagerCompat.from(this)
            .notify(StepNotifications.TRACKING_NOTIFICATION_ID, notification)
    }

    private fun registerSensor() {
        if (registered) return
        val manager =
            sensorManager
                ?: (getSystemService(Context.SENSOR_SERVICE) as SensorManager).also {
                    sensorManager = it
                }
        val sensor = manager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) ?: return
        registered = manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        if (!registered) {
            stopSelf()
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_STEP_COUNTER) return
        val systemValue = event.values[0].toInt()
        StepChannelHolder.publishStepUpdate(systemValue)
        val prefs = prefs()
        if (prefs.getString("flutter.$DATE_KEY", "") != StepDateKeys.today()) {
            baseline = systemValue
            todaySteps = 0
            save(prefs)
            NotificationManagerCompat.from(this).notify(
                StepNotifications.TRACKING_NOTIFICATION_ID,
                StepNotifications.trackingNotification(this, todaySteps, goal),
            )
            return
        }
        if (systemValue < baseline) {
            baseline = systemValue
        }
        val measured = systemValue - baseline
        if (measured > todaySteps) {
            todaySteps = measured
            save(prefs)
            NotificationManagerCompat.from(this).notify(
                StepNotifications.TRACKING_NOTIFICATION_ID,
                StepNotifications.trackingNotification(this, todaySteps, goal),
            )
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onDestroy() {
        isRunning = false
        if (registered) {
            sensorManager?.unregisterListener(this)
            registered = false
        }
        super.onDestroy()
    }

    companion object {
        @JvmStatic
        var isRunning = false

        private const val STORE_NAME = "FlutterSharedPreferences"
        private const val DATE_KEY = "step_fg_date"
        private const val BASELINE_KEY = "step_fg_baseline"
        private const val STEPS_KEY = "step_fg_steps"
        private const val GOAL_KEY = "step_fg_goal"
    }
}
