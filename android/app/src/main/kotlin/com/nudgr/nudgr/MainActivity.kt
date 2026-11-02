package com.nudgr.nudgr

import android.Manifest
import android.content.Context
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
    private var sensorManager: SensorManager? = null
    private var inAppListening = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val serviceChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            StepContract.CHANNEL,
        )
        StepChannelHolder.attach(serviceChannel)
        serviceChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                StepContract.IS_SENSOR_AVAILABLE -> result.success(stepSensor() != null)
                StepContract.REQUEST_ACTIVITY_PERMISSION -> {
                    requestActivityPermission()
                    result.success(null)
                }
                StepContract.IS_ACTIVITY_PERMISSION_GRANTED ->
                    result.success(hasActivityPermission())
                StepContract.START_LISTENING -> {
                    startInAppListening()
                    result.success(null)
                }
                StepContract.STOP_LISTENING -> {
                    stopInAppListening()
                    result.success(null)
                }
                StepContract.START_FOREGROUND_TRACKING -> {
                    startForegroundTracking(call.arguments as? Map<*, *>)
                    result.success(null)
                }
                StepContract.STOP_FOREGROUND_TRACKING -> {
                    stopService(Intent(this, StepTrackingService::class.java))
                    result.success(null)
                }
                StepContract.SEND_NOTIFICATION -> {
                    postGoalNotification(call.arguments as? Map<*, *>)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun stepSensor(): Sensor? =
        sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

    private fun hasActivityPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACTIVITY_RECOGNITION,
            ) == PackageManager.PERMISSION_GRANTED

    private fun requestActivityPermission() {
        if (hasActivityPermission()) {
            StepChannelHolder.publishPermissionResult(true)
            return
        }
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
            StepContract.PERMISSION_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == StepContract.PERMISSION_REQUEST_CODE) {
            StepChannelHolder.publishPermissionResult(
                grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED,
            )
        }
    }

    private fun startInAppListening() {
        val sensor = stepSensor() ?: return
        sensorManager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        inAppListening = true
    }

    private fun stopInAppListening() {
        if (!inAppListening) return
        inAppListening = false
        sensorManager?.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_STEP_COUNTER) return
        StepChannelHolder.publishStepUpdate(event.values[0].toInt())
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun startForegroundTracking(arguments: Map<*, *>?) {
        val intent = Intent(this, StepTrackingService::class.java)
            .putExtra(
                StepContract.ARG_BASELINE,
                (arguments?.get(StepContract.ARG_BASELINE) as? Number)?.toInt() ?: 0,
            )
            .putExtra(
                StepContract.ARG_GOAL,
                (arguments?.get(StepContract.ARG_GOAL) as? Number)?.toInt() ?: 10000,
            )
            .putExtra(
                StepContract.ARG_STEPS,
                (arguments?.get(StepContract.ARG_STEPS) as? Number)?.toInt() ?: 0,
            )
        try {
            ContextCompat.startForegroundService(this, intent)
        } catch (_: Exception) {
            StepNotifications.postGoalAlert(
                this,
                "Step tracking unavailable",
                "Recent foreground service limits Nudgr from starting step tracking in the background.",
            )
        }
    }

    private fun postGoalNotification(arguments: Map<*, *>?) {
        val title = arguments?.get(StepContract.ARG_TITLE) as? String ?: "Nudgr"
        val body = arguments?.get(StepContract.ARG_BODY) as? String ?: ""
        if (StepTrackingService.isRunning) {
            try {
                startService(
                    Intent(this, StepTrackingService::class.java)
                        .setAction(StepContract.ACTION_SEND_NOTIFICATION)
                        .putExtra(StepContract.ARG_TITLE, title)
                        .putExtra(StepContract.ARG_BODY, body),
                )
                return
            } catch (_: Exception) {
            }
        }
        StepNotifications.postGoalAlert(this, title, body)
    }

    override fun onDestroy() {
        stopInAppListening()
        super.onDestroy()
    }
}
