package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.tools.ToolCallDisplay
import com.google.gson.annotations.SerializedName

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

    fun isValid(): Boolean = apiKey.isNotBlank() && model.isNotBlank()
}

/**
 * 聊天消息结构
 */
data class ChatMessage(
    @SerializedName("role")
    val role: String,
    @SerializedName("content")
    val content: String,
    @SerializedName("timestamp")
    val timestamp: Long = System.currentTimeMillis(),
    @SerializedName("isLoading")
    val isLoading: Boolean = false,
    @SerializedName("loadingState")
    val loadingState: String? = null,
    @SerializedName("loadingSeconds")
    val loadingSeconds: Int = 0,
    @SerializedName("toolCalls")
    val toolCalls: List<ToolCallDisplay> = emptyList(),
    @SerializedName("toolCallId")
    val toolCallId: String? = null
) {
    companion object {
        const val ROLE_USER = "user"
        const val ROLE_ASSISTANT = "assistant"
        const val ROLE_SYSTEM = "system"
        const val ROLE_TOOL = "tool"

        const val LOADING_THINKING = "thinking"
    }
}

/**
 * 聊天响应结构
 */
data class ChatResponse(
    @SerializedName("content")
    val content: String,
    @SerializedName("provider")
    val provider: AIProvider,
    @SerializedName("model")
    val model: String,
    @SerializedName("toolCalls")
    val toolCalls: List<com.example.dodroidai.ai.tools.ToolCall> = emptyList()
)