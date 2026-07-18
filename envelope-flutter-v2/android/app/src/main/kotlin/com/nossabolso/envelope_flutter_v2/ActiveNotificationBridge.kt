package com.nossabolso.envelope_flutter_v2

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Instância estática do NotificationListenerService para que a MainActivity
 * possa consultar as notificações ativas da bandeja.
 *
 * O plugin flutter_notification_listener já registra seu próprio listener.
 * Este bridge é separado — serve apenas para leitura em tempo real.
 */
class ActiveNotificationBridge : NotificationListenerService() {

    companion object {
        @Volatile
        var instance: ActiveNotificationBridge? = null
    }

    override fun onListenerConnected() {
        instance = this
    }

    override fun onListenerDisconnected() {
        if (instance === this) instance = null
    }
}
