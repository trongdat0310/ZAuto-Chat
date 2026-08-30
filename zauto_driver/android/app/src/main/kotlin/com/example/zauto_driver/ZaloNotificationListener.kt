package com.example.zauto_driver

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class ZaloNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)

        if (sbn == null) return

        val packageName = sbn.packageName ?: return

        if (packageName != "com.zing.zalo") return

        val extras = sbn.notification.extras

        val title = extras.getCharSequence(
            Notification.EXTRA_TITLE
        )?.toString() ?: ""

        val text = extras.getCharSequence(
            Notification.EXTRA_TEXT
        )?.toString() ?: ""

        if (title.isBlank() && text.isBlank()) return

        Log.d(
            "ZALO_NOTIFICATION",
            "Title: $title | Text: $text"
        )

        ZaloEventStream.send(
            title,
            text,
            System.currentTimeMillis()
        )
    }
}