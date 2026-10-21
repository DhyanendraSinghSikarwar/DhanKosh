package com.hisaab.sms

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Platform channels `sms`, `sms_live` and `permissions`. Names mirror channel_names.dart. */
class SmsBridge(private val activity: Activity) {
    private var pendingSms: MethodChannel.Result? = null
    private val smsChannels = SmsChannels(activity)
    private val background = BackgroundBridge(activity, null, null)
    private var permChannel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        smsChannels.attach(messenger, withLive = true)
        background.attach(messenger)
        permChannel = MethodChannel(messenger, "com.hisaab/permissions").also {
            it.setMethodCallHandler { call, result -> onPermission(call, result) }
        }
    }

    fun detach() {
        smsChannels.detach()
        background.detach()
        permChannel?.setMethodCallHandler(null)
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
