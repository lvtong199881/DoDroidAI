package com.example.dodroidai.ai.model

import com.google.gson.annotations.SerializedName

/**
 * Anthropic Content 类型枚举
 */
enum class ContentType(val value: String) {
    TEXT("text"),
    TOOL_USE("tool_use"),
    THINKING("thinking")
}

/**
 * Anthropic 兼容 API 的请求格式
 */
data class AnthropicRequestBody(
    @SerializedName("model")
    val model: String,
    @SerializedName("messages")
    val messages: List<AnthropicMessage>,
    @SerializedName("tools")
    val tools: List<AnthropicTool>? = null,
    @SerializedName("stream")
    val stream: Boolean = false
)

/**
 * Anthropic 消息结构
 */
data class AnthropicMessage(
    @SerializedName("role")
    val role: String,
    @SerializedName("content")
    val content: String,
    @SerializedName("tool_call_id")
    val toolCallId: String? = null
)

/**
 * Anthropic 工具定义
 */
data class AnthropicTool(
    @SerializedName("name")
    val name: String,
    @SerializedName("description")
    val description: String,
    @SerializedName("input_schema")
    val inputSchema: AnthropicInputSchema
)

/**
 * Anthropic 工具输入参数结构
 */
data class AnthropicInputSchema(
    @SerializedName("type")
    val type: String = "object",
    @SerializedName("properties")
    val properties: Map<String, AnthropicToolProperty> = emptyMap(),
    @SerializedName("required")
    val required: List<String> = emptyList()
)

/**
 * Anthropic 工具属性定义
 */
data class AnthropicToolProperty(
    @SerializedName("type")
    val type: String,
    @SerializedName("description")
    val description: String
)

/**
 * Anthropic API 响应格式
 */
data class AnthropicResponse(
    @SerializedName("id")
    val id: String,
    @SerializedName("type")
    val type: String,
    @SerializedName("role")
    val role: String,
    @SerializedName("content")
    val content: List<AnthropicContent>,
    @SerializedName("model")
    val model: String,
    @SerializedName("stop_reason")
    val stopReason: String?
)

/**
 * Anthropic Content 内容项
 */
data class AnthropicContent(
    @SerializedName("type")
    val type: String,
    @SerializedName("text")
    val text: String? = null,
    @SerializedName("id")
    val id: String? = null,
    @SerializedName("name")
    val name: String? = null,
    @SerializedName("tool_use_id")
    val toolUseId: String? = null,
    @SerializedName("input")
    val input: Map<String, Any>? = null,
    @SerializedName("thinking")
    val thinking: String? = null
)

/**
 * Anthropic SSE 块
 */
data class AnthropicSseChunk(
    @SerializedName("type")
    val type: String?,
    @SerializedName("index")
    val index: Int?,
    @SerializedName("delta")
    val delta: AnthropicDelta?,
    @SerializedName("content_block")
    val contentBlock: AnthropicContentBlock?
)

/**
 * Anthropic SSE content_block_start 的 content_block 字段
 */
data class AnthropicContentBlock(
    @SerializedName("type")
    val type: String?,
    @SerializedName("id")
    val id: String?,
    @SerializedName("name")
    val name: String?,
    @SerializedName("input")
    val input: Map<String, Any>?
)

/**
 * Anthropic SSE Delta
 */
data class AnthropicDelta(
    @SerializedName("type")
    val type: String?,
    @SerializedName("text")
    val text: String?,
    @SerializedName("thinking")
    val thinking: String?,
    @SerializedName("partial_json")
    val partialJson: String?,
    @SerializedName("id")
    val id: String?,
    @SerializedName("name")
    val name: String?
)

/**
 * Anthropic 流式工具调用缓冲项
 */
data class AnthropicToolCallBuffer(
    @SerializedName("id")
    val id: String = "",
    @SerializedName("name")
    val name: String = "",
    @SerializedName("inputBuilder")
    val inputBuilder: StringBuilder = StringBuilder()
)
