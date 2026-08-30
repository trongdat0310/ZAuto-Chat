package com.example.zauto_driver

import io.flutter.plugin.common.EventChannel

object ZaloEventStream {
    var eventSink: EventChannel.EventSink? = null

    fun send(title: String, text: String, timestamp: Long) {
        val data = mapOf(
            "title" to title,
            "text" to text,
            "timestamp" to timestamp
        )

        eventSink?.success(data)
    }
}