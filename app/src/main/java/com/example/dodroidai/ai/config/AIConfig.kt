package com.example.dodroidai.ai.config

import com.example.dodroidai.ai.model.AIProvider

/**
 * AI 配置数据类，包含 API Key、模型、地址等配置
 */
data class AIConfig(
    val provider: AIProvider,
    val apiKey: String,
    val baseUrl: String,
    val model: String
) {
    companion object {
        fun default(provider: AIProvider): AIConfig {
            return when (provider) {
                AIProvider.OPENAI -> AIConfig(
                    provider = AIProvider.OPENAI,
                    apiKey = "",
                    baseUrl = "https://api.openai.com/v1",
                    model = "gpt-4o"
                )
                AIProvider.DEEPSEEK -> AIConfig(
                    provider = AIProvider.DEEPSEEK,
                    apiKey = "",
                    baseUrl = "https://api.deepseek.com/v1",
                    model = "deepseek-chat"
                )
                AIProvider.MINIMAX -> AIConfig(
                    provider = AIProvider.MINIMAX,
                    apiKey = "sk-cp-QuJOenSRuFksTFTxJHGkRPsGUWXf_fz0Op_B6CXcIqiCgvSVMm6RBwmkc2Z_RjhcFASkiaKOpU8WFTTY1LFVdlrhW2M0YTTlM5QffL5QKBhevK-6y2jKju4",
                    baseUrl = "https://api.minimaxi.com/anthropic",
                    model = "MiniMax-M2.7"
                )
                AIProvider.CUSTOM -> AIConfig(
                    provider = AIProvider.CUSTOM,
                    apiKey = "",
                    baseUrl = "",
                    model = ""
                )
            }
        }
    }
}