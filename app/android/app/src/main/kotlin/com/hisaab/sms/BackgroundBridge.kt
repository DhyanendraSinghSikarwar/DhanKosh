package com.hisaab.sms

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Channel `com.hisaab/background`. UI engine: scheduling (`scheduleOneOff`, `schedulePeriodic`,
 * `cancel`). Headless engine ([task] set): also `getTask` and `done`.
 */
class BackgroundBridge(
    context: Context,
    private val task: String?,
    private val onDone: ((Boolean) -> Unit)?,
) {
    private val context = context.applicationContext
    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "com.hisaab/background").also {
            it.setMethodCallHandler { call, result -> onCall(call, result) }
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getTask" -> result.success(task)
                "done" -> {
                    result.success(null)
                    onDone?.invoke(call.argument<Boolean>("ok") ?: true)
                }
                "scheduleOneOff" -> {
                    BackgroundScheduler.oneOff(
                        context,
                        call.argument<String>("uniqueName") ?: "",
                        call.argument<String>("task") ?: "",
                        call.argument<Boolean>("replace") ?: false,
                    )
                    result.success(null)
                }
                "schedulePeriodic" -> {
                    BackgroundScheduler.periodic(
                        context,
                        call.argument<String>("uniqueName") ?: "",
                        call.argument<String>("task") ?: "",
                        call.argument<Number>("intervalMinutes")?.toLong() ?: 1440L,
                        call.argument<Number>("initialDelayMinutes")?.toLong() ?: 0L,
                        call.argument<Boolean>("requiresBatteryNotLow") ?: true,
                    )
                    result.success(null)
                }
                "cancel" -> {
                    BackgroundScheduler.cancel(context, call.argument<String>("uniqueName") ?: "")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("background_failed", e.javaClass.simpleName, null)
        }
    }
}
