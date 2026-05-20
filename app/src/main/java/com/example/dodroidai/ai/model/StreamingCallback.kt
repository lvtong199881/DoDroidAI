package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.tools.ToolCall

/**
 * 流式聊天回调接口
 */
interface StreamingCallback {
    fun onContentDelta(content: String)
    fun onReasoningDelta(content: String)
    fun onToolCallDelta(toolCallId: String, name: String, argumentsDelta: String)
    fun onToolCallComplete(toolCallId: String, name: String, arguments: String)
    fun onComplete(fullContent: String, reasoningContent: String?, toolCalls: List<ToolCall>)
    fun onError(error: Throwable)
}
