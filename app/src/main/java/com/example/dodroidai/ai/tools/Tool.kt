package com.example.dodroidai.ai.tools

import android.app.Activity
import android.content.Context
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
 * 工具接口，所有工具实现类需实现此接口
 */
interface Tool {
    /** 工具名称，用于唯一标识 */
    val name: String

    /** 所需权限列表，无权限要求则为空列表 */
    val requiredPermissions: List<String>

    /** 工具风险等级 */
    val riskLevel: RiskLevel

    /** 检查是否已授予所需权限
     * @param context Android 上下文
     * @return true 表示已授予所有所需权限
     */
    fun hasPermissions(context: Context): Boolean

    /** 请求所需权限
     * @param activity 用于启动权限请求的 Activity
     * @param callback 权限授予结果回调，true 表示已授予
     */
    fun requestPermissions(activity: Activity, callback: (Boolean) -> Unit)

    /** 执行工具
     * @param context Android 上下文
     * @param arguments JSON 格式的工具参数
     * @return 工具执行结果
     */
    fun execute(context: Context, arguments: String): ToolResult

    /** 释放工具持有的资源,默认无操作 */
    fun close() {}
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