package com.example.dodroidai.ai.streaming

import com.example.dodroidai.ai.model.PreparedRequest
import com.example.dodroidai.ai.model.StreamingCallback
import okhttp3.OkHttpClient
import okhttp3.sse.EventSource
import okhttp3.sse.EventSources

/**
 * 流式 Chat 客户端。
 */
class StreamingChatClient(private val httpClient: OkHttpClient) {

    private var currentEventSource: EventSource? = null

    /**
     * 发起已经构建好的请求，自动取消之前的连接。
     */
    fun stream(
        prepared: PreparedRequest,
        callback: StreamingCallback
    ): EventSource {
        currentEventSource?.cancel()
        currentEventSource = null

        val factory = EventSources.createFactory(httpClient)
        val eventSource = factory.newEventSource(
            prepared.request,
            prepared.listenerFactory(callback)
        )
        currentEventSource = eventSource
        return eventSource
    }

    /**
     * 主动中止当前流式请求。可在任意线程调用。
     */
    fun cancel() {
        currentEventSource?.cancel()
        currentEventSource = null
    }
}
