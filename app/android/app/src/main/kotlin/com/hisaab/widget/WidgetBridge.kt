package com.hisaab.widget

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
            "canInstall" -> result.success(canInstall())
            "openInstallSettings" -> result.success(openInstallSettings())
            "installApk" -> installApk(call, result)
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

    // In-app update hand-off (memory 31). The APK is already SHA-256
    // verified by Dart; Android checks that the signature matches.

    private fun canInstall(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            activity.packageManager.canRequestPackageInstalls()
        } else {
            true
        }

    private fun openInstallSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:" + activity.packageName),
            )
            activity.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    private fun installApk(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path.isNullOrBlank()) {
            result.error("bad_args", "path required", null)
            return
        }
        // Only .apk files inside <cache>/updates may be handed over.
        val file = File(path).canonicalFile
        val root = File(activity.cacheDir, "updates").canonicalFile
        if (!file.path.startsWith(root.path + File.separator) ||
            !file.isFile ||
            !file.name.endsWith(".apk")
        ) {
            result.error("bad_path", "file not allowed", null)
            return
        }
        if (!canInstall()) {
            openInstallSettings()
            result.success("permission_needed")
            return
        }
        try {
            val uri = FileProvider.getUriForFile(
                activity,
                activity.packageName + ".updates",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW)
            intent.setDataAndType(uri, "application/vnd.android.package-archive")
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            activity.startActivity(intent)
            result.success("started")
        } catch (e: ActivityNotFoundException) {
            result.error("no_installer", "no package installer", null)
        } catch (e: IllegalArgumentException) {
            result.error("bad_path", "file not shareable", null)
        }
    }
}
