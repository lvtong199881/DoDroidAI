package com.example.dodroidai.ai.model

import kotlinx.serialization.Serializable

/**
 * AI 提供商枚举
 */
enum class AIProvider {
    OPENAI,
    DEEPSEEK,
    MINIMAX,
    CUSTOM
}

/**
 * AI 配置数据类
 */
@Serializable
data class AIConfig(
    val provider: AIProvider = AIProvider.OPENAI,
    val apiKey: String = "",
    val baseUrl: String = "",
    val model: String = "",
    val temperature: Float = 0.7f
) {
    fun isValid(): Boolean = apiKey.isNotBlank() && model.isNotBlank()

    companion object {
        val DEFAULT_OPENAI = AIConfig(
            provider = AIProvider.OPENAI,
            baseUrl = "https://api.openai.com/v1",
            model = "gpt-4o"
        )

        val DEFAULT_DEEPSEEK = AIConfig(
            provider = AIProvider.DEEPSEEK,
            baseUrl = "https://api.deepseek.com/v1",
            model = "deepseek-chat"
        )

        val DEFAULT_MINIMAX = AIConfig(
            provider = AIProvider.MINIMAX,
            baseUrl = "https://api.minimaxi.com/anthropic",
            model = "abab6.5s-chat"
        )
    }
}

/**
 * 聊天消息结构
 */
@Serializable
data class ChatMessage(
    val role: String,
    val content: String,
    val timestamp: Long = System.currentTimeMillis(),
    val isLoading: Boolean = false,
    val loadingState: String? = null,
    val loadingSeconds: Int = 0
) {
    companion object {
        const val ROLE_USER = "user"
        const val ROLE_ASSISTANT = "assistant"
        const val ROLE_SYSTEM = "system"

        const val LOADING_THINKING = "thinking"
    }
}

/**
 * 聊天响应结构
 */
@Serializable
data class ChatResponse(
    val content: String,
    val provider: AIProvider,
    val model: String
)