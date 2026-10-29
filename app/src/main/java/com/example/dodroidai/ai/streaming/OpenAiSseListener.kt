package com.example.dodroidai.ai.streaming

import android.util.Log
import com.example.dodroidai.ai.model.StreamingCallback
import okhttp3.Response
import okhttp3.sse.EventSource
import okhttp3.sse.EventSourceListener

/**
 * 把 OpenAI SSE 事件转交给 [OpenAiSseParser]。
 */
class OpenAiSseListener(callback: StreamingCallback) : EventSourceListener() {

    private val parser = OpenAiSseParser(callback)

    override fun onEvent(eventSource: EventSource, id: String?, type: String?, data: String) {
        parser.onData(data)
    }

    override fun onClosed(eventSource: EventSource) {
        // 部分兼容网关不发送 [DONE]，关闭连接时补一次完成
        parser.onData("[DONE]")
    }

    override fun onFailure(eventSource: EventSource, t: Throwable?, response: Response?) {
        val body = try {
            response?.body?.string()?.take(300)
        } catch (e: Exception) {
            null
        }
        Log.e(TAG, "OpenAI SSE failed. code=${response?.code} body=$body", t)
        val message = buildString {
            append("OpenAI SSE failed")
            response?.code?.let { append(" (HTTP ").append(it).append(")") }
            if (!body.isNullOrBlank()) append(": ").append(body)
        }
        parser.onFailure(RuntimeException(message, t))
    }

    companion object {
        private const val TAG = "OpenAiSseListener"
    }
}
