package com.hisaab.notifications

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Platform channels `notifications` and `notifications_live`. Names mirror channel_names.dart. */
class NotificationsBridge(private val activity: Activity) {
    private var channel: MethodChannel? = null
    private var liveChannel: EventChannel? = null

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "com.hisaab/notifications").also {
            it.setMethodCallHandler { call, result -> onCall(call, result) }
        }
        liveChannel = EventChannel(messenger, "com.hisaab/notifications_live").also {
            it.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NotificationStore.sink = events
                }

                override fun onCancel(arguments: Any?) {
                    NotificationStore.sink = null
                }
            })
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        liveChannel?.setStreamHandler(null)
        NotificationStore.sink = null
    }

    private fun hasAccess(): Boolean {
        val flat = Settings.Secure.getString(
            activity.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return flat.split(":").any {
            it.startsWith(activity.packageName + "/") || it.startsWith(activity.packageName + ":")
        }
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAccessEnabled" -> result.success(hasAccess())
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "openAccessSettings" -> {
                activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                result.success(null)
            }
            "drainPending" -> result.success(NotificationStore.drain(activity))
            "configure" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                NotificationStore.configure(activity, enabled, packages)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
