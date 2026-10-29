package com.example.dodroidai.ai.streaming

import com.example.dodroidai.ai.model.StreamingCallback
import com.example.dodroidai.ai.tools.ToolCall
import com.google.gson.JsonParser

/**
 * OpenAI Chat Completions 的 SSE 解析器。
 *
 * 纯逻辑实现（不依赖 Android API），便于 JVM 单元测试。
 * 支持文本、`reasoning_content`（DeepSeek 等）和分片的 `tool_calls`。
 */
class OpenAiSseParser(private val callback: StreamingCallback) {

    private val content = StringBuilder()
    private val reasoning = StringBuilder()
    private val toolCalls = mutableMapOf<Int, ToolCallBuffer>()
    private var completed = false

    fun onData(data: String) {
        if (completed) return
        if (data == "[DONE]") {
            complete()
            return
        }

        val root = try {
            JsonParser.parseString(data).asJsonObject
        } catch (e: Exception) {
            return
        }

        if (root.has("error")) {
            val message = try {
                root.getAsJsonObject("error")
                    ?.get("message")
                    ?.takeIf { !it.isJsonNull }
                    ?.asString
            } catch (e: Exception) {
                null
            } ?: "OpenAI API error"
            fail(RuntimeException(message))
            return
        }

        val choice = root.getAsJsonArray("choices")
            ?.firstOrNull()
            ?.asJsonObject
            ?: return

        choice.getAsJsonObject("delta")?.let { delta ->
            delta.get("content")?.takeIf { !it.isJsonNull }?.asString?.let {
                content.append(it)
                callback.onContentDelta(it)
            }

            val reasoningText = delta.get("reasoning_content") ?: delta.get("reasoning")
            reasoningText?.takeIf { !it.isJsonNull }?.asString?.let {
                reasoning.append(it)
                callback.onReasoningDelta(it)
            }

            delta.getAsJsonArray("tool_calls")?.forEach { element ->
                val toolCall = element.asJsonObject
                val index = toolCall.get("index")?.asInt ?: 0
                val buffer = toolCalls.getOrPut(index) { ToolCallBuffer() }
                toolCall.get("id")?.takeIf { !it.isJsonNull }?.asString?.let { buffer.id = it }
                toolCall.getAsJsonObject("function")?.let { function ->
                    function.get("name")?.takeIf { !it.isJsonNull }?.asString?.let { buffer.name = it }
                    function.get("arguments")?.takeIf { !it.isJsonNull }?.asString?.let {
                        buffer.arguments.append(it)
                    }
                }
            }
        }

        val finishReason = choice.get("finish_reason")
        if (finishReason != null && !finishReason.isJsonNull) {
            complete()
        }
    }

    fun onFailure(error: Throwable) {
        if (!completed) {
            completed = true
            callback.onError(error)
        }
    }

    private fun complete() {
        if (completed) return
        completed = true

        val calls = toolCalls.toSortedMap().values.mapNotNull { buffer ->
            if (buffer.name.isBlank()) {
                null
            } else {
                ToolCall(
                    id = buffer.id,
                    name = buffer.name,
                    arguments = buffer.arguments.toString().ifEmpty { "{}" }
                )
            }
        }
        calls.forEach { callback.onToolCallComplete(it.id, it.name, it.arguments) }
        callback.onComplete(content.toString(), reasoning.toString().ifEmpty { null }, calls)
    }

    private fun fail(error: Throwable) {
        if (!completed) {
            completed = true
            callback.onError(error)
        }
    }

    private class ToolCallBuffer {
        var id: String = ""
        var name: String = ""
        val arguments = StringBuilder()
    }
}
