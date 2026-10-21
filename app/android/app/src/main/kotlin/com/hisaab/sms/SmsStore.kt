package com.hisaab.sms

import android.content.Context
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Live-SMS hand-off. Delivers to Dart over the EventChannel when a listener is
 * attached, otherwise persists to a small SharedPreferences queue that Dart
 * drains with `drainPending`. Only counts/ids are ever logged, never bodies.
 */
object SmsStore {
    private const val PREFS = "hisaab_sms"
    private const val KEY_QUEUE = "pending"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_PATTERN = "pattern"
    private const val MAX_QUEUE = 500

    /** Set by the EventChannel stream handler (main thread). */
    @Volatile
    var sink: EventChannel.EventSink? = null

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Dart pushes `sms_enabled` and the sender regex; native never reads other senders. */
    fun configure(context: Context, enabled: Boolean, pattern: String?) {
        prefs(context).edit()
            .putBoolean(KEY_ENABLED, enabled)
            .putString(KEY_PATTERN, pattern)
            .apply()
    }

    /** False when paused, not yet configured, or the sender does not match. */
    fun accepts(context: Context, sender: String): Boolean {
        val p = prefs(context)
        if (!p.getBoolean(KEY_ENABLED, true)) return false
        val pattern = p.getString(KEY_PATTERN, null) ?: return false
        return try {
            Regex(pattern, RegexOption.IGNORE_CASE).containsMatchIn(sender)
        } catch (e: Exception) {
            true // bad pattern: keep the message, Dart filters again
        }
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
        next.put(JSONObject(message))
        p.edit().putString(KEY_QUEUE, next.toString()).apply()
    }

    @Synchronized
    fun drain(context: Context): List<Map<String, Any?>> {
        val p = prefs(context)
        val arr = JSONArray(p.getString(KEY_QUEUE, "[]"))
        val out = ArrayList<Map<String, Any?>>(arr.length())
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            out.add(
                mapOf(
                    "id" to o.optString("id", ""),
                    "sender" to o.optString("sender", ""),
                    "body" to o.optString("body", ""),
                    "timestamp" to o.optLong("timestamp", 0L),
                    "sentTimestamp" to o.optLong("sentTimestamp", 0L),
                ),
            )
        }
        p.edit().remove(KEY_QUEUE).apply()
        return out
    }
}
