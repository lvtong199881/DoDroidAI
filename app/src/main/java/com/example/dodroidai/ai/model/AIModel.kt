package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.config.AIConfig

/**
 * AI 模型接口，定义 AI 对话能力
 */
interface AIModel {
    val provider: AIProvider

    suspend fun chat(messages: List<ChatMessage>): ChatResponse

    fun getDefaultConfig(): AIConfig
}