package com.example.dodroidai.ai.streaming

import android.util.Log
import com.example.dodroidai.ai.model.AnthropicSseChunk
import com.example.dodroidai.ai.model.StreamingCallback
import com.example.dodroidai.ai.tools.ToolCall
import com.example.dodroidai.util.GsonUtil
import okhttp3.sse.EventSource
import okhttp3.sse.EventSourceListener
import okhttp3.Response

/**
 * Anthropic SSE 事件监听器
 */
class AnthropicSseListener(
    private val callback: StreamingCallback
) : EventSourceListener() {

    private val contentBuilder = StringBuilder()
    private val reasoningBuilder = StringBuilder()
    private val toolCallBuffer = mutableMapOf<Int, ToolCallBufferEntry>()
    private var currentToolCallIndex: Int = -1
    private var isProcessingToolCall: Boolean = false

    override fun onEvent(eventSource: EventSource, id: String?, type: String?, data: String) {
        Log.i(TAG, "SSE event: $data")

        if (data == "[DONE]") {
            // [DONE] 是旧格式，保留作为 fallback
            flushToolCall()
            callback.onComplete(
                contentBuilder.toString(),
                reasoningBuilder.toString().ifEmpty { null },
                toolCallBuffer.values.map { ToolCall(id = it.id, name = it.name, arguments = it.inputBuilder.toString()) }
            )
            return
        }

        val chunk = GsonUtil.fromJson(data, AnthropicSseChunk::class.java) ?: return
        processChunk(chunk)
    }

    private fun processChunk(chunk: AnthropicSseChunk) {
        when (chunk.type) {
            "message_stop" -> {
                // 消息结束，触发完成回调
                flushToolCall()
                callback.onComplete(
                    contentBuilder.toString(),
                    reasoningBuilder.toString().ifEmpty { null },
                    toolCallBuffer.values.map { ToolCall(id = it.id, name = it.name, arguments = it.inputBuilder.toString()) }
                )
            }
            "content_block_delta" -> {
                chunk.delta?.let { delta ->
                    when (delta.type) {
                        "text_delta" -> {
                            // 如果正在处理 tool_call，不发送 content delta
                            if (!isProcessingToolCall) {
                                delta.text?.let {
                                    contentBuilder.append(it)
                                    callback.onContentDelta(contentBuilder.toString())
                                }
                            }
                        }
                        "thinking_delta" -> {
                            delta.thinking?.let {
                                reasoningBuilder.append(it)
                                callback.onReasoningDelta(reasoningBuilder.toString())
                            }
                        }
                        "input_json_delta" -> {
                            delta.partialJson?.let {
                                val entry = toolCallBuffer[currentToolCallIndex]
                                entry?.inputBuilder?.append(it)
                            }
                        }
                    }
                }
            }
            "content_block_start" -> {
                chunk.contentBlock?.let { block ->
                    if (block.type == "tool_use") {
                        // tool_use 开始，清空 content，记录 index、id 和 name
                        contentBuilder.clear()
                        isProcessingToolCall = true
                        currentToolCallIndex = chunk.index ?: 0
                        val entry = ToolCallBufferEntry()
                        entry.id = block.id ?: ""
                        entry.name = block.name ?: ""
                        toolCallBuffer[currentToolCallIndex] = entry
                    }
                }
            }
            "content_block_stop" -> {
                // content block 结束，重置状态
                currentToolCallIndex = -1
                isProcessingToolCall = false
            }
            "message_delta" -> {
                chunk.delta?.let { delta ->
                    if (delta.type == "input_json_delta") {
                        delta.partialJson?.let {
                            val entry = toolCallBuffer[currentToolCallIndex]
                            entry?.inputBuilder?.append(it)
                        }
                    }
                }
            }
        }
    }

    private fun flushToolCall() {
        toolCallBuffer.values.forEach { entry ->
            if (entry.id.isNotEmpty()) {
                callback.onToolCallComplete(entry.id, entry.name, entry.inputBuilder.toString())
            }
        }
    }

    override fun onFailure(eventSource: EventSource, t: Throwable?, response: Response?) {
        Log.e(TAG, "SSE connection failed. Response: $response", t)
        callback.onError(t ?: RuntimeException("SSE connection failed. Response: $response"))
    }

    private data class ToolCallBufferEntry(
        var id: String = "",
        var name: String = "",
        val inputBuilder: StringBuilder = StringBuilder()
    )

    companion object {
        private const val TAG = "AnthropicSseListener"
    }
}
