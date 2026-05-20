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
    val toolCallId: String? = null,
    @SerializedName("reasoningContent")
    val reasoningContent: String? = null,
    @SerializedName("isReasoningExpanded")
    val isReasoningExpanded: Boolean = false
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
    val toolCalls: List<com.example.dodroidai.ai.tools.ToolCall> = emptyList(),
    @SerializedName("reasoningContent")
    val reasoningContent: String? = null
)