package com.hisaab.alerts

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
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
                "takeSharedFile" -> {
                    val path = pendingShared
                    pendingShared = null
                    result.success(path)
                }
                "setSecure" -> {
                    val on = call.argument<Boolean>("on") ?: false
                    app.getSharedPreferences(WINDOW_PREFS, Context.MODE_PRIVATE)
                        .edit().putBoolean(KEY_SECURE, on).apply()
                    secureHandler?.invoke(on)
                    result.success(secureHandler != null)
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
        private const val EXTRA_SHARED_DONE = "hisaab_shared_done"

        const val WINDOW_PREFS = "hisaab_window"
        const val KEY_SECURE = "block_screenshots"
        private const val SHARED_DIR = "shared_in"
        private const val MAX_SHARED_BYTES = 50L * 1024 * 1024
        private val SHARED_EXT = setOf("pdf", "csv", "xlsx", "xls")

        @Volatile
        private var pendingRoute: String? = null

        @Volatile
        private var pendingShared: String? = null

        /** Set by MainActivity: applies or clears FLAG_SECURE on its window. */
        @Volatile
        var secureHandler: ((Boolean) -> Unit)? = null

        /**
         * Copies a PDF, CSV or XLSX shared to the app (ACTION_SEND) or opened
         * with it (ACTION_VIEW) into the cache and remembers its path for
         * `takeSharedFile`. Only content:// URIs are read. Names and contents
         * are never logged.
         */
        fun captureShared(context: Context, intent: Intent?) {
            if (intent == null) return
            val action = intent.action
            if (action != Intent.ACTION_SEND && action != Intent.ACTION_VIEW) return
            val uri: Uri? = if (action == Intent.ACTION_SEND) {
                if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
                }
            } else {
                intent.data
            }
            if (uri == null || uri.scheme != "content") return
            // A launch from history replays the old intent; take each once.
            if (intent.getBooleanExtra(EXTRA_SHARED_DONE, false)) return
            intent.putExtra(EXTRA_SHARED_DONE, true)
            try {
                val resolver = context.contentResolver
                val name: String? = resolver
                    .query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                    ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
                val base = (name ?: uri.lastPathSegment ?: "shared")
                    .substringAfterLast('/')
                    .replace(Regex("[^A-Za-z0-9._-]"), "_")
                var ext = base.substringAfterLast('.', "").lowercase()
                if (ext !in SHARED_EXT) {
                    ext = when (intent.type ?: resolver.getType(uri)) {
                        "application/pdf" -> "pdf"
                        "text/csv", "text/comma-separated-values" -> "csv"
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" -> "xlsx"
                        "application/vnd.ms-excel" -> "xls"
                        else -> return
                    }
                }
                val dir = java.io.File(context.cacheDir, SHARED_DIR)
                dir.mkdirs()
                dir.listFiles()?.forEach { it.delete() }
                val stem = base.substringBeforeLast('.').take(60).ifEmpty { "shared" }
                val out = java.io.File(dir, "$stem.$ext")
                var total = 0L
                resolver.openInputStream(uri)?.use { input ->
                    out.outputStream().use { output ->
                        val buf = ByteArray(64 * 1024)
                        while (true) {
                            val n = input.read(buf)
                            if (n < 0) break
                            total += n
                            if (total > MAX_SHARED_BYTES) {
                                out.delete()
                                return
                            }
                            output.write(buf, 0, n)
                        }
                    }
                } ?: return
                pendingShared = out.absolutePath
            } catch (e: Exception) {
                // Unreadable or revoked URI: ignore, nothing to import.
            }
        }

        /** Called by MainActivity for the launch intent and onNewIntent. */
        fun captureRoute(intent: Intent?) {
            val route = intent?.getStringExtra(EXTRA_ROUTE)
            if (route != null) pendingRoute = route
        }
    }
}
