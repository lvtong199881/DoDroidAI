package com.example.dodroidai.ai.tools

import kotlinx.serialization.Serializable

/**
 * 工具调用的风险等级
 */
enum class RiskLevel {
    LOW,    // 无风险，直接执行
    MEDIUM, // 中等风险，可选确认
    HIGH    // 高风险，需要用户确认
}

/**
 * 工具定义（用于传给 LLM）
 */
@Serializable
data class ToolDefinition(
    val name: String,
    val description: String,
    val parameters: ToolParameters,
    val riskLevel: RiskLevel = RiskLevel.MEDIUM
)

@Serializable
data class ToolParameters(
    val type: String = "object",
    val properties: Map<String, ToolProperty> = emptyMap(),
    val required: List<String> = emptyList()
)

@Serializable
data class ToolProperty(
    val type: String,
    val description: String
)

/**
 * LLM 返回的工具调用请求
 */
@Serializable
data class ToolCall(
    val id: String,
    val name: String,
    val arguments: String // JSON 字符串
)

/**
 * 工具执行结果
 */
data class ToolResult(
    val toolCallId: String,
    val toolName: String,
    val success: Boolean,
    val result: String,
    val error: String? = null
)

/**
 * 工具调用在消息中的展示信息
 */
data class ToolCallDisplay(
    val name: String,
    val argsSummary: String,
    val isRunning: Boolean = false,
    val isSuccess: Boolean? = null,
    val resultSummary: String? = null
)
