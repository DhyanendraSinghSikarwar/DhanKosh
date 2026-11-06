package com.hisaab.notifications

import android.content.Context
import com.hisaab.sms.BackgroundScheduler
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
    private const val KEY_SEEN = "seen"
    private const val KEY_CONNECTED_AT = "connected_at"
    private const val KEY_DISCONNECTED_AT = "disconnected_at"
    private const val KEY_LAST_READ_AT = "last_read_at"
    private const val KEY_READ_COUNT = "read_count"
    private const val MAX_QUEUE = 200
    private const val MAX_SEEN = 60

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

    /** The in-app switch; nothing is read or noted while it is off. */
    fun enabled(context: Context): Boolean = prefs(context).getBoolean(KEY_ENABLED, false)

    /** False when the setting is off, not yet configured, or the package is not allow-listed. */
    fun accepts(context: Context, packageName: String): Boolean {
        val p = prefs(context)
        if (!p.getBoolean(KEY_ENABLED, false)) return false
        val set = p.getStringSet(KEY_PACKAGES, null) ?: return false
        return packageName in set
    }

    /**
     * Remembers that [packageName] posted a notification, so the user can add an app the
     * allow-list does not know yet (FR-04-20). Package name, label and time only: the
     * notification's own extras are never touched for an app that is not watched.
     */
    @Synchronized
    fun noteSeen(context: Context, packageName: String, label: String?, postTime: Long) {
        val p = prefs(context)
        val o = JSONObject(p.getString(KEY_SEEN, "{}"))
        val row = o.optJSONObject(packageName) ?: JSONObject()
        row.put("label", label ?: row.optString("label", packageName))
        row.put("lastSeen", postTime)
        row.put("count", row.optInt("count", 0) + 1)
        o.put(packageName, row)
        // Keep the most recent apps when the list grows past the cap.
        if (o.length() > MAX_SEEN) {
            val oldest = o.keys().asSequence()
                .sortedBy { o.getJSONObject(it).optLong("lastSeen", 0L) }
                .take(o.length() - MAX_SEEN)
                .toList()
            for (k in oldest) o.remove(k)
        }
        p.edit().putString(KEY_SEEN, o.toString()).apply()
    }

    /** Apps that posted notifications and are not watched; newest first. */
    @Synchronized
    fun seen(context: Context): List<Map<String, Any?>> {
        val o = JSONObject(prefs(context).getString(KEY_SEEN, "{}"))
        val watched = prefs(context).getStringSet(KEY_PACKAGES, null) ?: emptySet()
        return o.keys().asSequence()
            .filter { it !in watched }
            .map {
                val row = o.getJSONObject(it)
                mapOf(
                    "packageName" to it,
                    "label" to row.optString("label", it),
                    "lastSeen" to row.optLong("lastSeen", 0L),
                    "count" to row.optInt("count", 0),
                )
            }
            .sortedByDescending { it["lastSeen"] as Long }
            .toList()
    }

    /** Clears the seen-apps list. */
    @Synchronized
    fun forgetSeen(context: Context) {
        prefs(context).edit().remove(KEY_SEEN).apply()
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
        // No Dart listener (app closed): wake a headless engine to ingest the queue now, as for
        // SMS, instead of leaving the payment unseen until the app is next opened (FR-04-21).
        try {
            BackgroundScheduler.oneOff(
                context,
                BackgroundScheduler.UNIQUE_NOTIF_DRAIN,
                BackgroundScheduler.TASK_NOTIF_DRAIN,
                false,
            )
        } catch (e: Exception) {
            // The queue is kept; Dart drains it on the next app start or resume.
        }
    }

    /** The system bound the listener (FR-04-22). */
    fun markConnected(context: Context) {
        prefs(context).edit().putLong(KEY_CONNECTED_AT, System.currentTimeMillis()).apply()
    }

    /** The system unbound the listener (FR-04-22). */
    fun markDisconnected(context: Context) {
        prefs(context).edit().putLong(KEY_DISCONNECTED_AT, System.currentTimeMillis()).apply()
    }

    /** A watched app's notification was handed over: time and count only (FR-04-22). */
    fun markRead(context: Context, postTime: Long) {
        val p = prefs(context)
        p.edit()
            .putLong(KEY_LAST_READ_AT, postTime)
            .putInt(KEY_READ_COUNT, p.getInt(KEY_READ_COUNT, 0) + 1)
            .apply()
    }

    /** Listener health for the Data sources card; no notification text (FR-04-22). */
    fun health(context: Context): Map<String, Any?> {
        val p = prefs(context)
        val queued = try {
            JSONArray(p.getString(KEY_QUEUE, "[]")).length()
        } catch (e: Exception) {
            0
        }
        return mapOf(
            "connectedAt" to p.getLong(KEY_CONNECTED_AT, 0L),
            "disconnectedAt" to p.getLong(KEY_DISCONNECTED_AT, 0L),
            "lastReadAt" to p.getLong(KEY_LAST_READ_AT, 0L),
            "readCount" to p.getInt(KEY_READ_COUNT, 0),
            "queued" to queued,
        )
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
