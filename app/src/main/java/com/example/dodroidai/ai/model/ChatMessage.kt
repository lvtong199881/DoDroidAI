package com.example.dodroidai.ai.model

import kotlinx.serialization.Serializable

/**
 * AI 提供商枚举，支持 OpenAI、DeepSeek、MiniMax 及自定义
 */
enum class AIProvider {
    OPENAI,
    DEEPSEEK,
    MINIMAX,
    CUSTOM
}

/**
 * 聊天消息结构
 */
@Serializable
data class ChatMessage(
    val role: String,
    val content: String
)

/**
 * 聊天响应结构
 */
@Serializable
data class ChatResponse(
    val content: String,
    val provider: AIProvider,
    val model: String
)