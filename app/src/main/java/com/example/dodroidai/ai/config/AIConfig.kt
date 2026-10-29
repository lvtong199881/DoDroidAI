package com.example.dodroidai.ai.config

import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ai.model.ApiFormat
import com.google.gson.annotations.SerializedName
import java.util.UUID

/**
 * AI 配置数据类
 */
data class AIConfig(
    @SerializedName("id")
    val id: String = UUID.randomUUID().toString(),
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
    val opusModel: String = "",
    /**
     * 当前端点是否支持图片输入。
     *
     * 使用可空类型是为了兼容旧配置：Gson 反序列化不会应用 Kotlin 默认值，
     * 缺失字段会变成 null；读取时统一用 `supportsVision ?: true`。
     */
    @SerializedName("supportsVision")
    val supportsVision: Boolean? = null,
    @SerializedName("createdAt")
    val createdAt: Long = System.currentTimeMillis(),
    @SerializedName("updatedAt")
    val updatedAt: Long = System.currentTimeMillis()
) {
    companion object {
        fun default(provider: AIProvider): AIConfig {
            return when (provider) {
                AIProvider.OPENAI -> AIConfig(
                    provider = AIProvider.OPENAI,
                    apiKey = "",
                    baseUrl = "https://api.openai.com",
                    model = "gpt-4o",
                    providerName = "OpenAI",
                    officialUrl = "https://openai.com",
                    apiFormat = ApiFormat.OPENAI_CHAT_COMPLETIONS,
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