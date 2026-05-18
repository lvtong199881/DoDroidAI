package com.example.dodroidai.ai.config

import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ai.model.ApiFormat

/**
 * AI 配置数据类
 */
data class AIConfig(
    /** AI 提供商类型 */
    val provider: AIProvider,
    /** API 密钥 */
    val apiKey: String,
    /** API 请求地址 */
    val baseUrl: String,
    /** 默认模型 */
    val model: String,
    /** 供应商名称 */
    val providerName: String = "",
    /** 备注说明 */
    val description: String = "",
    /** 官网链接 */
    val officialUrl: String = "",
    /** API 格式 */
    val apiFormat: ApiFormat = ApiFormat.ANTHROPIC_MESSAGES,
    /** 主模型名称 */
    val mainModel: String = "",
    /** Haiku 默认模型 */
    val haikuModel: String = "",
    /** Sonnet 默认模型 */
    val sonnetModel: String = "",
    /** Opus 默认模型 */
    val opusModel: String = ""
) {
    companion object {
        fun default(provider: AIProvider): AIConfig {
            return when (provider) {
                AIProvider.OPENAI -> AIConfig(
                    provider = AIProvider.OPENAI,
                    apiKey = "",
                    baseUrl = "https://api.openai.com/v1",
                    model = "gpt-4o",
                    providerName = "OpenAI",
                    officialUrl = "https://openai.com",
                    apiFormat = ApiFormat.ANTHROPIC_MESSAGES,
                    mainModel = "gpt-4o",
                    haikuModel = "gpt-4o",
                    sonnetModel = "gpt-4o",
                    opusModel = "gpt-4o"
                )
                AIProvider.DEEPSEEK -> AIConfig(
                    provider = AIProvider.DEEPSEEK,
                    apiKey = "",
                    baseUrl = "https://api.deepseek.com/v1",
                    model = "deepseek-chat",
                    providerName = "DeepSeek",
                    officialUrl = "https://platform.deepseek.com",
                    apiFormat = ApiFormat.ANTHROPIC_MESSAGES,
                    mainModel = "deepseek-chat",
                    haikuModel = "deepseek-chat",
                    sonnetModel = "deepseek-chat",
                    opusModel = "deepseek-chat"
                )
                AIProvider.MINIMAX -> AIConfig(
                    provider = AIProvider.MINIMAX,
                    apiKey = "",
                    baseUrl = "https://api.minimaxi.com/anthropic",
                    model = "MiniMax-M2.7",
                    providerName = "MiniMax",
                    officialUrl = "https://platform.minimaxi.com",
                    apiFormat = ApiFormat.ANTHROPIC_MESSAGES,
                    mainModel = "MiniMax-M2.7",
                    haikuModel = "MiniMax-M2.7",
                    sonnetModel = "MiniMax-M2.7",
                    opusModel = "MiniMax-M2.7"
                )
                AIProvider.CUSTOM -> AIConfig(
                    provider = AIProvider.CUSTOM,
                    apiKey = "",
                    baseUrl = "",
                    model = "",
                    providerName = "",
                    apiFormat = ApiFormat.ANTHROPIC_MESSAGES
                )
            }
        }
    }
}