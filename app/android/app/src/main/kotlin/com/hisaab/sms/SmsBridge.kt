package com.hisaab.sms

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Platform channels `sms`, `sms_live` and `permissions`. Names mirror channel_names.dart. */
class SmsBridge(private val activity: Activity) {
    private var pendingSms: MethodChannel.Result? = null
    private var smsChannel: MethodChannel? = null
    private var permChannel: MethodChannel? = null
    private var liveChannel: EventChannel? = null

    fun attach(messenger: BinaryMessenger) {
        smsChannel = MethodChannel(messenger, "com.hisaab/sms").also {
            it.setMethodCallHandler { call, result -> onSms(call, result) }
        }
        permChannel = MethodChannel(messenger, "com.hisaab/permissions").also {
            it.setMethodCallHandler { call, result -> onPermission(call, result) }
        }
        liveChannel = EventChannel(messenger, "com.hisaab/sms_live").also {
            it.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    SmsStore.sink = events
                }

                override fun onCancel(arguments: Any?) {
                    SmsStore.sink = null
                }
            })
        }
    }

    fun detach() {
        smsChannel?.setMethodCallHandler(null)
        permChannel?.setMethodCallHandler(null)
        liveChannel?.setStreamHandler(null)
        SmsStore.sink = null
        pendingSms = null
    }

    /** Called from MainActivity.onRequestPermissionsResult. */
    fun onPermissionResult(requestCode: Int) {
        if (requestCode == REQ_SMS) {
            pendingSms?.success(null) // Dart re-reads the real state; the result map is ignored.
            pendingSms = null
        }
    }

    private fun granted(permission: String) =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun hasSms() = granted(Manifest.permission.READ_SMS) &&
        granted(Manifest.permission.RECEIVE_SMS)

    private fun onSms(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasSms())
            "drainPending" -> result.success(SmsStore.drain(activity))
            "configureLive" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                SmsStore.configure(activity, enabled, call.argument<String>("senderPattern"))
                result.success(null)
            }
            "readInbox" -> readInbox(call, result)
            else -> result.notImplemented()
        }
    }

    private fun readInbox(call: MethodCall, result: MethodChannel.Result) {
        if (!granted(Manifest.permission.READ_SMS)) {
            result.error("permission", "READ_SMS not granted", null)
            return
        }
        val since = call.argument<Number>("sinceMillis")?.toLong() ?: 0L
        val afterId = call.argument<Number>("afterId")?.toLong() ?: Long.MAX_VALUE
        val limit = call.argument<Number>("limit")?.toInt() ?: 500
        val pattern = call.argument<String>("senderPattern")?.let {
            try {
                Regex(it, RegexOption.IGNORE_CASE)
            } catch (e: Exception) {
                null
            }
        }
        Thread {
            try {
                val page = SmsInbox.read(activity, since, afterId, limit, pattern)
                activity.runOnUiThread { result.success(page) }
            } catch (e: SecurityException) {
                activity.runOnUiThread { result.error("permission", "READ_SMS denied", null) }
            } catch (e: Exception) {
                // Class name only: never include message text.
                activity.runOnUiThread { result.error("read_failed", e.javaClass.simpleName, null) }
            }
        }.start()
    }

    private fun onPermission(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "smsStatus" -> result.success(
                mapOf(
                    "granted" to hasSms(),
                    "rationale" to activity.shouldShowRequestPermissionRationale(
                        Manifest.permission.READ_SMS,
                    ),
                ),
            )
            "requestSms" -> {
                if (pendingSms != null) {
                    result.error("busy", "Request in progress", null)
                    return
                }
                pendingSms = result
                activity.requestPermissions(
                    arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS),
                    REQ_SMS,
                )
            }
            "requestNotifications" -> {
                if (Build.VERSION.SDK_INT >= 33) {
                    activity.requestPermissions(
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        REQ_NOTIF,
                    )
                    result.success(true)
                } else {
                    result.success(false)
                }
            }
            "openAppSettings" -> {
                val intent = Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:" + activity.packageName),
                )
                activity.startActivity(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private companion object {
        const val REQ_SMS = 4101
        const val REQ_NOTIF = 4102
    }
}
