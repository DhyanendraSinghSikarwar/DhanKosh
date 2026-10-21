package com.hisaab.notifications

import android.content.Context
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Notification hand-off (FR-04-01, FR-04-02). Delivers to Dart over the EventChannel when a
 * listener is attached, otherwise persists a small SharedPreferences queue that Dart drains with
 * `drainPending`. Notification text is never logged and the queue is cleared on drain.
 */
object NotificationStore {
    private const val PREFS = "hisaab_notifications"
    private const val KEY_QUEUE = "pending"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_PACKAGES = "packages"
    private const val MAX_QUEUE = 200

    /** Set by the EventChannel stream handler (main thread). */
    @Volatile
    var sink: EventChannel.EventSink? = null

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Dart pushes `app_notifications` and the allow-list; native reads nothing until configured. */
    fun configure(context: Context, enabled: Boolean, packages: List<String>) {
        prefs(context).edit()
            .putBoolean(KEY_ENABLED, enabled)
            .putStringSet(KEY_PACKAGES, packages.toSet())
            .apply()
    }

    /** False when the setting is off, not yet configured, or the package is not allow-listed. */
    fun accepts(context: Context, packageName: String): Boolean {
        val p = prefs(context)
        if (!p.getBoolean(KEY_ENABLED, false)) return false
        val set = p.getStringSet(KEY_PACKAGES, null) ?: return false
        return packageName in set
    }

    fun deliver(context: Context, message: Map<String, Any?>) {
        val s = sink
        if (s != null) {
            try {
                s.success(message)
                return
            } catch (e: Exception) {
                // fall through to the queue
            }
        }
        enqueue(context, message)
    }

    @Synchronized
    private fun enqueue(context: Context, message: Map<String, Any?>) {
        val p = prefs(context)
        val old = JSONArray(p.getString(KEY_QUEUE, "[]"))
        val next = JSONArray()
        val start = maxOf(0, old.length() - MAX_QUEUE + 1)
        for (i in start until old.length()) next.put(old.get(i))
        val o = JSONObject()
        for ((k, v) in message) {
            if (k == "parts") {
                val arr = JSONArray()
                @Suppress("UNCHECKED_CAST")
                for (part in (v as List<String>)) arr.put(part)
                o.put(k, arr)
            } else {
                o.put(k, v ?: JSONObject.NULL)
            }
        }
        next.put(o)
        p.edit().putString(KEY_QUEUE, next.toString()).apply()
    }

    @Synchronized
    fun drain(context: Context): List<Map<String, Any?>> {
        val p = prefs(context)
        val arr = JSONArray(p.getString(KEY_QUEUE, "[]"))
        val out = ArrayList<Map<String, Any?>>(arr.length())
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val parts = ArrayList<String>()
            val pa = o.optJSONArray("parts")
            if (pa != null) for (j in 0 until pa.length()) parts.add(pa.getString(j))
            out.add(
                mapOf(
                    "packageName" to o.optString("packageName", ""),
                    "key" to o.optString("key", ""),
                    "postTime" to o.optLong("postTime", 0L),
                    "parts" to parts,
                    "isGroupSummary" to o.optBoolean("isGroupSummary", false),
                    "isOngoing" to o.optBoolean("isOngoing", false),
                    "category" to (if (o.isNull("category")) null else o.optString("category")),
                    "hasMessagesExtra" to o.optBoolean("hasMessagesExtra", false),
                    "channelId" to (if (o.isNull("channelId")) null else o.optString("channelId")),
                ),
            )
        }
        p.edit().remove(KEY_QUEUE).apply()
        return out
    }
}
