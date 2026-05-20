package com.example.dodroidai.ai.config

import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ai.model.ApiFormat
import com.google.gson.annotations.SerializedName

/**
 * AI 配置数据类
 */
data class AIConfig(
    @SerializedName("provider")
    val provider: AIProvider,
    @SerializedName("apiKey")
    val apiKey: String,
    @SerializedName("baseUrl")
    val baseUrl: String,
    @SerializedName("model")
    val model: String,
    @SerializedName("providerName")
    val providerName: String = "",
    @SerializedName("description")
    val description: String = "",
    @SerializedName("officialUrl")
    val officialUrl: String = "",
    @SerializedName("apiFormat")
    val apiFormat: ApiFormat = ApiFormat.ANTHROPIC_MESSAGES,
    @SerializedName("mainModel")
    val mainModel: String = "",
    @SerializedName("haikuModel")
    val haikuModel: String = "",
    @SerializedName("sonnetModel")
    val sonnetModel: String = "",
    @SerializedName("opusModel")
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
                    baseUrl = "https://api.deepseek.com/anthropic",
                    model = "DeepSeek-V4-Flash",
                    providerName = "DeepSeek",
                    officialUrl = "https://platform.deepseek.com",
                    apiFormat = ApiFormat.ANTHROPIC_MESSAGES,
                    mainModel = "DeepSeek-V4-Flash",
                    haikuModel = "DeepSeek-V4-Flash",
                    sonnetModel = "DeepSeek-V4-Flash",
                    opusModel = "DeepSeek-V4-Flash"
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

    fun isValid(): Boolean = apiKey.isNotBlank() && model.isNotBlank()
}