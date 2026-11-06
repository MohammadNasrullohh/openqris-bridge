package com.openqris.bridge.qris_bridge

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel

class QrisNotificationListenerService : NotificationListenerService() {

    companion object {
        var eventSink: EventChannel.EventSink? = null

        // Cache of recently processed notifications to prevent duplicate trigger
        private val recentKeys = LinkedHashMap<String, Long>()
        private const val DEDUP_WINDOW_MS = 3000L
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        val extras = sbn.notification?.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""

        val effectiveMessage = when {
            bigText.isNotEmpty() -> bigText
            text.isNotEmpty() -> text
            else -> subText
        }

        if (title.isEmpty() && effectiveMessage.isEmpty()) return

        // Deduplication check
        val dedupKey = "$packageName|$title|$effectiveMessage"
        val now = System.currentTimeMillis()
        val lastSeen = recentKeys[dedupKey]
        if (lastSeen != null && (now - lastSeen) < DEDUP_WINDOW_MS) {
            return
        }
        recentKeys[dedupKey] = now
        if (recentKeys.size > 100) {
            val oldest = recentKeys.keys.first()
            recentKeys.remove(oldest)
        }

        val data = mapOf(
            "package_name" to packageName,
            "title" to title,
            "message" to effectiveMessage,
            "timestamp" to sbn.postTime
        )

        eventSink?.let { sink ->
            sink.success(data)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
    }
}
