package com.nossabolso.envelope_flutter_v2

import android.app.Notification
import android.os.Bundle
import android.service.notification.StatusBarNotification
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.nossabolso/active_notifications"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method == "getActiveNotifications") {
                result.success(getActiveNotifications())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getActiveNotifications(): List<Map<String, String?>> {
        val listener = ActiveNotificationBridge.instance
            ?: return emptyList()

        return try {
            listener.activeNotifications?.mapNotNull { sbn ->
                val extras = sbn.notification?.extras ?: return@mapNotNull null
                mapOf(
                    "packageName" to sbn.packageName,
                    "id" to sbn.id.toString(),
                    "title" to extras.getString(Notification.EXTRA_TITLE),
                    "text" to extras.getCharSequence(Notification.EXTRA_TEXT)?.toString(),
                    "bigText" to extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString(),
                )
            } ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }
}
