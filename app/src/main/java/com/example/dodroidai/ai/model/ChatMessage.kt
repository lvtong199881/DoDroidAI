package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.tools.ToolCall
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
    val toolCalls: List<ToolCallDisplay>? = emptyList(),
    /**
     * assistant 工具调用的原始载荷，仅用于请求构建（OpenAI 需要 assistant tool_calls 消息）。
     * UI 展示仍使用 [toolCalls]。
     */
    @SerializedName("toolCallPayloads")
    val toolCallPayloads: List<ToolCall>? = null,
    @SerializedName("attachments")
    val attachments: List<ChatAttachment>? = null,
    @SerializedName("toolCallId")
    val toolCallId: String? = null,
    @SerializedName("reasoningContent")
    val reasoningContent: String? = null,
    @SerializedName("reasoningElapsedSeconds")
    val reasoningElapsedSeconds: Int = 0,
    @SerializedName("isError")
    val isError: Boolean? = null,
    @SerializedName("isReasoningExpanded")
    val isReasoningExpanded: Boolean = false
) {
    companion object {
        const val ROLE_USER = "user"
        const val ROLE_ASSISTANT = "assistant"
        const val ROLE_SYSTEM = "system"
        const val ROLE_TOOL = "tool"

        const val LOADING_THINKING = "thinking"
        const val LOADING_ATTACHMENTS = "attachments"
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