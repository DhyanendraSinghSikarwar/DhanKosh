package com.hisaab.notifications

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Platform channels `notifications` and `notifications_live`. Names mirror channel_names.dart.
 * Needs only a [Context], so the same handlers serve the UI engine and the headless engine that
 * ingests notifications while the app is closed (FR-04-21).
 */
class NotificationsBridge(context: Context) {
    private val context = context
    private var channel: MethodChannel? = null
    private var liveChannel: EventChannel? = null

    /** [withLive] is false in the headless engine: nothing listens there. */
    fun attach(messenger: BinaryMessenger, withLive: Boolean = true) {
        channel = MethodChannel(messenger, "com.hisaab/notifications").also {
            it.setMethodCallHandler { call, result -> onCall(call, result) }
        }
        if (withLive) {
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
    }

    /** UI engine only: a headless engine must never clear the UI engine's sink. */
    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        if (liveChannel != null) {
            liveChannel?.setStreamHandler(null)
            liveChannel = null
            NotificationStore.sink = null
        }
    }

    private fun hasAccess(): Boolean {
        val flat = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return flat.split(":").any {
            it.startsWith(context.packageName + "/") || it.startsWith(context.packageName + ":")
        }
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAccessEnabled" -> result.success(hasAccess())
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "openAccessSettings" -> {
                val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                if (context !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(null)
            }
            "drainPending" -> result.success(NotificationStore.drain(context))
            "seenPackages" -> result.success(NotificationStore.seen(context))
            "forgetSeen" -> {
                NotificationStore.forgetSeen(context)
                result.success(null)
            }
            "health" -> result.success(NotificationStore.health(context))
            "configure" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                NotificationStore.configure(context, enabled, packages)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
