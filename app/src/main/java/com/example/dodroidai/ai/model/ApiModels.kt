package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.tools.ToolCall
import com.example.dodroidai.ai.tools.ToolDefinition
import kotlinx.serialization.Serializable

/**
 * API 请求/响应数据模型，内部使用
 */
@Serializable
internal data class ChatRequestBody(
    val model: String,
    val messages: List<ChatMessage>,
    val tools: List<ToolDefinition>? = null
)

@Serializable
internal data class ChatResponseBody(
    val id: String = "",
    val model: String = "",
    val choices: List<Choice> = emptyList()
)

@Serializable
internal data class Choice(
    val message: Message
)

@Serializable
internal data class Message(
    val content: String = "",
    val toolCalls: List<ToolCall>? = null
)

/**
 * 工具调用结果消息（用于继续对话）
 */
@Serializable
internal data class ToolMessage(
    val role: String = "tool",
    val toolCallId: String,
    val content: String
)