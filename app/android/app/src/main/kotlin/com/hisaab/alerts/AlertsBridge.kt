package com.hisaab.alerts

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Platform channel `alerts` (memory 21). Name mirrors channel_names.dart.
 * Works with an application context so the headless engine can post too.
 * Never logs notification text.
 */
class AlertsBridge(context: Context) {
    private val app: Context = context.applicationContext
    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "com.hisaab/alerts").also {
            it.setMethodCallHandler { call, result -> onCall(call, result) }
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun manager(): NotificationManager? =
        app.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

    /** False when the OS permission (SDK 33+) is denied or the app is blocked. */
    private fun enabled(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            app.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        return manager()?.areNotificationsEnabled() ?: false
    }

    private fun ensureChannel(id: String) {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = manager() ?: return
        if (nm.getNotificationChannel(id) != null) return
        val (name, importance) = when (id) {
            "budget" -> "Budget alerts" to NotificationManager.IMPORTANCE_DEFAULT
            "bills" -> "Bill reminders" to NotificationManager.IMPORTANCE_HIGH
            "cards" -> "Card bill reminders" to NotificationManager.IMPORTANCE_HIGH
            else -> "Info" to NotificationManager.IMPORTANCE_LOW
        }
        nm.createNotificationChannel(NotificationChannel(id, name, importance))
    }

    private fun post(call: MethodCall): Boolean {
        if (!enabled()) return false
        val nm = manager() ?: return false
        val id = call.argument<Int>("id") ?: return false
        val channelId = call.argument<String>("channelId") ?: "info"
        val title = call.argument<String>("title") ?: ""
        val body = call.argument<String>("body") ?: ""
        val route = call.argument<String>("route")
        ensureChannel(channelId)
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(app, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(app)
        }
        builder
            .setSmallIcon(app.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
        val launch = app.packageManager.getLaunchIntentForPackage(app.packageName)
        if (launch != null) {
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            if (route != null) launch.putExtra(EXTRA_ROUTE, route)
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
            builder.setContentIntent(PendingIntent.getActivity(app, id, launch, flags))
        }
        nm.notify(id, builder.build())
        return true
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "post" -> result.success(post(call))
                "cancel" -> {
                    val id = call.argument<Int>("id")
                    if (id != null) manager()?.cancel(id)
                    result.success(null)
                }
                "areEnabled" -> result.success(enabled())
                "takeLaunchRoute" -> {
                    val route = pendingRoute
                    pendingRoute = null
                    result.success(route)
                }
                else -> result.notImplemented()
            }
        } catch (e: SecurityException) {
            result.success(false)
        } catch (e: RuntimeException) {
            result.error("alerts_failed", e.javaClass.simpleName, null)
        }
    }

    companion object {
        const val EXTRA_ROUTE = "hisaab_route"

        @Volatile
        private var pendingRoute: String? = null

        /** Called by MainActivity for the launch intent and onNewIntent. */
        fun captureRoute(intent: Intent?) {
            val route = intent?.getStringExtra(EXTRA_ROUTE)
            if (route != null) pendingRoute = route
        }
    }
}
