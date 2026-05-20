package com.example.dodroidai.ai.streaming

import android.util.Log
import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.model.ChatMessage
import com.example.dodroidai.ai.model.StreamingCallback
import com.example.dodroidai.ai.model.createStreamingRequest
import com.example.dodroidai.ai.tools.ToolDefinition
import okhttp3.OkHttpClient
import okhttp3.sse.EventSource
import okhttp3.sse.EventSources

/**
 * 流式 Chat 客户端
 */
class StreamingChatClient(private val httpClient: OkHttpClient) {

    private var currentEventSource: EventSource? = null

    /**
     * 发起流式请求，自动取消之前的连接
     */
    fun stream(
        config: AIConfig,
        messages: List<ChatMessage>,
        tools: List<ToolDefinition>?,
        callback: StreamingCallback
    ): EventSource {
        // 取消之前的连接
        currentEventSource?.cancel()
        currentEventSource = null

        val request = createStreamingRequest(config, messages, tools)
        val factory = EventSources.createFactory(httpClient)
        val eventSource = factory.newEventSource(request, AnthropicSseListener(callback))
        currentEventSource = eventSource
        return eventSource
    }

    companion object {
        private const val TAG = "StreamingChatClient"
    }
}
