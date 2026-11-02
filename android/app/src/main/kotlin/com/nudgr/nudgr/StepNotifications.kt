package com.nudgr.nudgr

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

object StepNotifications {
    const val TRACKING_CHANNEL_ID = "step_tracking"
    const val ALERT_CHANNEL_ID = "step_alerts"
    const val TRACKING_NOTIFICATION_ID = 1001
    const val ALERT_NOTIFICATION_ID = 1002

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel(
                TRACKING_CHANNEL_ID,
                "Step tracking",
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
        manager.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL_ID,
                "Step goal alerts",
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
    }

    private fun canPostNotifications(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            context,
            android.Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun trackingNotification(context: Context, steps: Int, goal: Int) =
        NotificationCompat.Builder(context, TRACKING_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_nudgr)
            .setContentTitle("Tracking your steps")
            .setContentText("$steps / $goal steps")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .build()

    fun postGoalAlert(context: Context, title: String, body: String) {
        ensureChannels(context)
        if (!canPostNotifications(context)) return
        val notification =
            NotificationCompat.Builder(context, ALERT_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_nudgr)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setAutoCancel(true)
                .build()
        NotificationManagerCompat.from(context)
            .notify(ALERT_NOTIFICATION_ID, notification)
    }
}
