package com.nudgr.nudgr

import io.flutter.plugin.common.MethodChannel

object StepContract {
    const val CHANNEL = "com.nudgr.nudgr/step_counter"
    const val IS_SENSOR_AVAILABLE = "isSensorAvailable"
    const val REQUEST_ACTIVITY_PERMISSION = "requestActivityPermission"
    const val IS_ACTIVITY_PERMISSION_GRANTED = "isActivityPermissionGranted"
    const val START_LISTENING = "startListening"
    const val STOP_LISTENING = "stopListening"
    const val START_FOREGROUND_TRACKING = "startForegroundTracking"
    const val STOP_FOREGROUND_TRACKING = "stopForegroundTracking"
    const val SEND_NOTIFICATION = "sendNotification"
    const val ON_STEP_UPDATE = "onStepUpdate"
    const val ON_PERMISSION_RESULT = "onPermissionResult"
    const val ARG_BASELINE = "baseline"
    const val ARG_GOAL = "goal"
    const val ARG_STEPS = "steps"
    const val ARG_TITLE = "title"
    const val ARG_BODY = "body"
    const val ACTION_SEND_NOTIFICATION = "com.nudgr.nudgr.ACTION_SEND_NOTIFICATION"
    const val PERMISSION_REQUEST_CODE = 5203
}

object StepChannelHolder {
    private var channel: MethodChannel? = null

    fun attach(target: MethodChannel) {
        channel = target
    }

    fun publishStepUpdate(systemValue: Int) {
        val target = channel ?: return
        try {
            target.invokeMethod(StepContract.ON_STEP_UPDATE, systemValue)
        } catch (_: Exception) {
        }
    }

    fun publishPermissionResult(granted: Boolean) {
        val target = channel ?: return
        try {
            target.invokeMethod(StepContract.ON_PERMISSION_RESULT, granted)
        } catch (_: Exception) {
        }
    }
}

object StepDateKeys {
    fun today(): String {
        val calendar = java.util.Calendar.getInstance()
        val year = calendar.get(java.util.Calendar.YEAR)
        val month = calendar.get(java.util.Calendar.MONTH) + 1
        val day = calendar.get(java.util.Calendar.DAY_OF_MONTH)
        return "%04d-%02d-%02d".format(year, month, day)
    }
}
