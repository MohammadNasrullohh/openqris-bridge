package com.openqris.bridge.qris_bridge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        for (sms in messages) {
            val sender = sms.displayOriginatingAddress ?: "SMS"
            val body = sms.displayMessageBody ?: ""
            val timestamp = sms.timestampMillis

            val data = mapOf(
                "package_name" to "android.telephony.sms",
                "title" to sender,
                "message" to body,
                "timestamp" to timestamp
            )

            QrisNotificationListenerService.eventSink?.success(data)
        }
    }
}
