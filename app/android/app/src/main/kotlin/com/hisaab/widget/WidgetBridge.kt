package com.hisaab.widget

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Platform channel `widget` (memory 31): external hand-offs only (browser,
 * UPI chooser, release page). Widget data goes through the home_widget
 * plugin. Name mirrors channel_names.dart. Never logs URLs.
 */
class WidgetBridge(private val activity: Activity) {
    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "com.hisaab/widget").also {
            it.setMethodCallHandler { call, result -> onCall(call, result) }
        }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openUrl" -> openUrl(call, result)
            else -> result.notImplemented()
        }
    }

    private fun openUrl(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrBlank()) {
            result.error("bad_args", "url required", null)
            return
        }
        val view = Intent(Intent.ACTION_VIEW, Uri.parse(url))
        val chooser = call.argument<Boolean>("chooser") ?: false
        val title = call.argument<String>("chooserTitle") ?: "Open with"
        try {
            if (chooser) {
                if (view.resolveActivity(activity.packageManager) == null) {
                    result.success(false)
                    return
                }
                activity.startActivity(Intent.createChooser(view, title))
            } else {
                activity.startActivity(view)
            }
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.success(false)
        }
    }
}
