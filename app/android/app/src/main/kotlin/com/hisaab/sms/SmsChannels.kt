package com.hisaab.sms

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Channels `com.hisaab/sms` and `com.hisaab/sms_live`. Needs only a [Context], so the
 * same handlers serve the UI engine and the headless engine (no Activity).
 */
class SmsChannels(context: Context) {
    private val context = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private var smsChannel: MethodChannel? = null
    private var liveChannel: EventChannel? = null

    /** [withLive] is false in the headless engine: nothing listens there. */
    fun attach(messenger: BinaryMessenger, withLive: Boolean) {
        smsChannel = MethodChannel(messenger, "com.hisaab/sms").also {
            it.setMethodCallHandler { call, result -> onSms(call, result) }
        }
        if (withLive) {
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
    }

    /** UI engine only: a headless engine must never clear the UI engine's sink. */
    fun detach() {
        smsChannel?.setMethodCallHandler(null)
        smsChannel = null
        if (liveChannel != null) {
            liveChannel?.setStreamHandler(null)
            liveChannel = null
            SmsStore.sink = null
        }
    }

    private fun granted(permission: String) =
        context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun onSms(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(
                granted(Manifest.permission.READ_SMS) && granted(Manifest.permission.RECEIVE_SMS),
            )
            "drainPending" -> result.success(SmsStore.drain(context))
            "configureLive" -> {
                val enabled = call.argument<Boolean>("enabled") ?: true
                SmsStore.configure(context, enabled, call.argument<String>("senderPattern"))
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
                val page = SmsInbox.read(context, since, afterId, limit, pattern)
                main.post { result.success(page) }
            } catch (e: SecurityException) {
                main.post { result.error("permission", "READ_SMS denied", null) }
            } catch (e: Exception) {
                // Class name only: never include message text.
                main.post { result.error("read_failed", e.javaClass.simpleName, null) }
            }
        }.start()
    }
}
