package com.example.dodroidai.ai.model

import okhttp3.Request
import okhttp3.sse.EventSourceListener

/**
 * 已按协议构建好的请求与对应的 SSE 监听器工厂。
 */
data class PreparedRequest(
    val request: Request,
    val listenerFactory: (StreamingCallback) -> EventSourceListener
)
