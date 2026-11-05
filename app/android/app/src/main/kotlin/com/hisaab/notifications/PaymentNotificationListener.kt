package com.hisaab.notifications

import android.app.Notification
import android.content.ComponentName
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Reads notifications from the allow-listed payment apps only (FR-04-01, FR-04-02, FR-04-03,
 * FR-04-04, FR-04-05). Other packages are dropped before any extra is touched. Parsing happens
 * in Dart; this class only extracts the text parts and forwards them via [NotificationStore].
 */
class PaymentNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        try {
            handle(sbn)
        } catch (e: Exception) {
            // One bad notification never kills the service.
        }
    }

    private fun handle(sbn: StatusBarNotification) {
        if (!NotificationStore.accepts(applicationContext, sbn.packageName)) {
            noteUnwatched(sbn)
            return
        }
        val n = sbn.notification ?: return
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        if (n.flags and Notification.FLAG_ONGOING_EVENT != 0) return
        val extras = n.extras ?: return
        val raw = ArrayList<CharSequence?>()
        raw.add(extras.getCharSequence(Notification.EXTRA_TITLE))
        raw.add(extras.getCharSequence(Notification.EXTRA_TITLE_BIG))
        raw.add(extras.getCharSequence(Notification.EXTRA_TEXT))
        raw.add(extras.getCharSequence(Notification.EXTRA_BIG_TEXT))
        raw.add(extras.getCharSequence(Notification.EXTRA_SUB_TEXT))
        raw.add(extras.getCharSequence(Notification.EXTRA_INFO_TEXT))
        raw.add(extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT))
        extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)?.forEach { raw.add(it) }
        val parts = raw.mapNotNull { it?.toString()?.trim() }.filter { it.isNotEmpty() }.distinct()
        if (parts.isEmpty()) return
        val hasMessages = extras.containsKey(Notification.EXTRA_MESSAGES)
        val channel = if (Build.VERSION.SDK_INT >= 26) n.channelId else null
        if (sbn.packageName in CHAT_APPS &&
            !isChatPayment(n.category, hasMessages, channel, parts)
        ) return
        NotificationStore.deliver(
            applicationContext,
            mapOf(
                "packageName" to sbn.packageName,
                "key" to sbn.key,
                "postTime" to sbn.postTime,
                "parts" to parts,
                "isGroupSummary" to false,
                "isOngoing" to false,
                "category" to n.category,
                "hasMessagesExtra" to hasMessages,
                "channelId" to channel,
            ),
        )
    }

    /**
     * Records that an app the allow-list does not know posted something, so the user can add it
     * on the Watched apps screen (FR-04-20). Only its package name, launcher label and post time
     * are kept: the notification's extras are never read here, and nothing is noted while the
     * in-app switch is off.
     */
    private fun noteUnwatched(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName) return
        if (!NotificationStore.enabled(applicationContext)) return
        val n = sbn.notification ?: return
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        if (n.flags and Notification.FLAG_ONGOING_EVENT != 0) return
        NotificationStore.noteSeen(
            applicationContext,
            sbn.packageName,
            labelOf(sbn.packageName),
            sbn.postTime,
        )
    }

    /** The app's own name as the launcher shows it; null when it cannot be read. */
    private fun labelOf(pkg: String): String? = try {
        val pm = applicationContext.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (e: Exception) {
        null
    }

    /** Ask the system to rebind after the process was killed (reliability, memory 04 section 6). */
    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        if (Build.VERSION.SDK_INT >= 24) {
            try {
                requestRebind(ComponentName(this, PaymentNotificationListener::class.java))
            } catch (e: Exception) {
                // Access revoked meanwhile.
            }
        }
    }

    private companion object {
        val CHAT_APPS = setOf("com.whatsapp", "com.whatsapp.w4b")

        val CHAT_PAYMENT = Regex(
            """^\s*(?:you\s+(?:have\s+)?(?:paid|sent|received)|payment\s+(?:of|to|from|successful|received|sent|completed)|(?:₹|rs\.?|inr)\s?[\d,]+(?:\.\d{1,2})?\s+(?:paid|sent|received))""",
            RegexOption.IGNORE_CASE,
        )

        /** WhatsApp: payment notifications only, never a conversation (FR-04-05). */
        fun isChatPayment(
            category: String?,
            hasMessages: Boolean,
            channel: String?,
            parts: List<String>,
        ): Boolean {
            if (category == Notification.CATEGORY_MESSAGE) return false
            if (hasMessages) return false
            if (channel != null && channel.contains("chat", ignoreCase = true)) return false
            return parts.joinToString("\n").lines().any { CHAT_PAYMENT.containsMatchIn(it) }
        }
    }
}
