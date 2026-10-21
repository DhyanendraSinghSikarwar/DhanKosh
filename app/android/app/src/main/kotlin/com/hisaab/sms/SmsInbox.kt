package com.hisaab.sms

import android.content.Context
import android.provider.Telephony

/** Reads the SMS inbox oldest-first, paged by (date, _id) (FR-02-09). */
object SmsInbox {
    /**
     * Returns rows with (date > [since]) or (date == [since] and _id > [afterId]).
     * Rows whose address does not match [pattern] are counted but their body is never read.
     * Stops after [limit] matching rows; `done` is true when the inbox is exhausted.
     */
    fun read(
        context: Context,
        since: Long,
        afterId: Long,
        limit: Int,
        pattern: Regex?,
    ): Map<String, Any?> {
        val items = ArrayList<Map<String, Any?>>()
        var examined = 0
        var nextSince = since
        var nextAfterId = afterId
        var done = true
        val cursor = context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            arrayOf("_id", "address", "date", "date_sent", "body"),
            "date > ? OR (date = ? AND _id > ?)",
            arrayOf(since.toString(), since.toString(), afterId.toString()),
            "date ASC, _id ASC",
        )
        cursor?.use { c ->
            val iId = c.getColumnIndexOrThrow("_id")
            val iAddr = c.getColumnIndexOrThrow("address")
            val iDate = c.getColumnIndexOrThrow("date")
            val iSent = c.getColumnIndexOrThrow("date_sent")
            val iBody = c.getColumnIndexOrThrow("body")
            while (c.moveToNext()) {
                examined++
                nextSince = c.getLong(iDate)
                nextAfterId = c.getLong(iId)
                val sender = c.getString(iAddr) ?: ""
                if (pattern == null || pattern.containsMatchIn(sender)) {
                    items.add(
                        mapOf(
                            "id" to nextAfterId.toString(),
                            "sender" to sender,
                            "body" to (c.getString(iBody) ?: ""),
                            "timestamp" to nextSince,
                            "sentTimestamp" to c.getLong(iSent),
                        ),
                    )
                    if (items.size >= limit) {
                        done = !c.moveToNext() // peek: more rows remain
                        break
                    }
                }
            }
        }
        return mapOf(
            "items" to items,
            "examined" to examined,
            "nextSince" to nextSince,
            "nextAfterId" to nextAfterId,
            "done" to done,
        )
    }
}
