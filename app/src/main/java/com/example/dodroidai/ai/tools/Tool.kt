package com.example.dodroidai.ai.tools

import com.google.gson.annotations.SerializedName

/**
 * 工具调用的风险等级
 */
enum class RiskLevel {
    LOW,
    MEDIUM,
    HIGH
}

/**
 * 工具定义（用于传给 LLM）
 */
data class ToolDefinition(
    @SerializedName("name")
    val name: String,
    @SerializedName("description")
    val description: String,
    @SerializedName("parameters")
    val parameters: ToolParameters,
    @SerializedName("riskLevel")
    val riskLevel: RiskLevel = RiskLevel.MEDIUM
)

data class ToolParameters(
    @SerializedName("type")
    val type: String = "object",
    @SerializedName("properties")
    val properties: Map<String, ToolProperty> = emptyMap(),
    @SerializedName("required")
    val required: List<String> = emptyList()
)

data class ToolProperty(
    @SerializedName("type")
    val type: String,
    @SerializedName("description")
    val description: String
)

/**
 * LLM 返回的工具调用请求
 */
data class ToolCall(
    @SerializedName("id")
    val id: String,
    @SerializedName("name")
    val name: String,
    @SerializedName("arguments")
    val arguments: String
)

/**
 * 工具执行结果
 */
data class ToolResult(
    @SerializedName("toolCallId")
    val toolCallId: String,
    @SerializedName("toolName")
    val toolName: String,
    @SerializedName("success")
    val success: Boolean,
    @SerializedName("result")
    val result: String,
    @SerializedName("error")
    val error: String? = null
)

/**
 * 工具调用在消息中的展示信息
 */
data class ToolCallDisplay(
    @SerializedName("name")
    val name: String,
    @SerializedName("argsSummary")
    val argsSummary: String,
    @SerializedName("isRunning")
    val isRunning: Boolean = false,
    @SerializedName("isSuccess")
    val isSuccess: Boolean? = null,
    @SerializedName("resultSummary")
    val resultSummary: String? = null
)