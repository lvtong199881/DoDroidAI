package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.tools.ToolCall
import com.example.dodroidai.ai.tools.ToolDefinition
import com.google.gson.annotations.SerializedName

/**
 * API 请求/响应数据模型，内部使用
 */
data class ChatRequestBody(
    @SerializedName("model")
    val model: String,
    @SerializedName("messages")
    val messages: List<ChatMessage>,
    @SerializedName("tools")
    val tools: List<ToolDefinition>? = null
)

data class ChatResponseBody(
    @SerializedName("id")
    val id: String = "",
    @SerializedName("model")
    val model: String = "",
    @SerializedName("choices")
    val choices: List<Choice> = emptyList()
)

data class Choice(
    @SerializedName("message")
    val message: Message
)

data class Message(
    @SerializedName("content")
    val content: String = "",
    @SerializedName("toolCalls")
    val toolCalls: List<ToolCall>? = null
)

/**
 * 工具调用结果消息（用于继续对话）
 */
data class ToolMessage(
    @SerializedName("role")
    val role: String = "tool",
    @SerializedName("toolCallId")
    val toolCallId: String,
    @SerializedName("content")
    val content: String
)