package com.example.dodroidai.ai.tools

import android.content.Context
import okhttp3.OkHttpClient

/**
 * 工具的唯一来源：名称、描述、Schema、风险、权限、超时、执行器都在这一个对象里。
 *
 * 由 KSP 自动收集（见 [ToolProvider]），无需在注册表里手写一行。
 */
data class ToolSpec(
    val name: String,
    val description: String,
    val parameters: ToolParameters,
    val riskLevel: RiskLevel,
    val requiredPermissions: List<String> = emptyList(),
    val timeoutMillis: Long = 15_000,
    val execute: suspend (ToolContext, ToolArgs) -> ToolOutput
) {
    fun toDefinition(): ToolDefinition = ToolDefinition(
        name = name,
        description = description,
        parameters = parameters,
        riskLevel = riskLevel
    )
}

data class ToolContext(
    val appContext: Context,
    val call: ToolCall,
    val httpClient: OkHttpClient
)

data class ToolOutput(
    val text: String,
    val isError: Boolean = false,
    val errorCode: ToolErrorCode? = null
)

enum class ToolErrorCode {
    INVALID_ARGS,
    PERMISSION_DENIED,
    TIMEOUT,
    EXEC_FAILED,
    UNKNOWN_TOOL
}
