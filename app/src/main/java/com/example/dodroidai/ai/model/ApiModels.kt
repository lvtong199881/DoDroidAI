package com.example.dodroidai.ai.model

import kotlinx.serialization.Serializable

/**
 * API 请求/响应数据模型，内部使用
 */
@Serializable
internal data class ChatRequestBody(
    val model: String,
    val messages: List<ChatMessage>
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
    val content: String = ""
)