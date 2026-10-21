package com.hisaab.sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/** Manifest-registered receiver for live SMS (FR-02-01, FR-02-02, FR-02-03, FR-02-05). */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        // Join multi-part messages per sender, in arrival order.
        val bodies = LinkedHashMap<String, StringBuilder>()
        val sentAt = HashMap<String, Long>()
        for (part in parts) {
            val sender = part.originatingAddress ?: continue
            bodies.getOrPut(sender) { StringBuilder() }.append(part.messageBody ?: "")
            if (!sentAt.containsKey(sender)) sentAt[sender] = part.timestampMillis
        }
        val now = System.currentTimeMillis()
        for ((sender, body) in bodies) {
            if (!SmsStore.accepts(context, sender)) continue // body of other senders is dropped
            SmsStore.deliver(
                context,
                mapOf(
                    "id" to "",
                    "sender" to sender,
                    "body" to body.toString(),
                    "timestamp" to now,
                    "sentTimestamp" to (sentAt[sender] ?: 0L),
                ),
            )
        }
    }
}
