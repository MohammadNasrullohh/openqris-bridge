package com.openqris.bridge.qris_bridge

import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.openqris.bridge/listener"
    private val EVENT_CHANNEL = "com.openqris.bridge/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel for permission and service control
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> {
                    val isGranted = isNotificationServiceEnabled()
                    result.success(isGranted)
                }
                "openPermissionSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "startForegroundService" -> {
                    BridgeForegroundService.start(context)
                    result.success(true)
                }
                "stopForegroundService" -> {
                    BridgeForegroundService.stop(context)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // EventChannel for streaming notifications live into Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    QrisNotificationListenerService.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    QrisNotificationListenerService.eventSink = null
                }
            }
        )
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val packageName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (flat != null && flat.isNotEmpty()) {
            val names = flat.split(":")
            for (name in names) {
                if (name.contains(packageName)) {
                    return true
                }
            }
        }
        return false
    }
}
