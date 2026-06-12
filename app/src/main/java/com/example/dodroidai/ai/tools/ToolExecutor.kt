package com.example.dodroidai.ai.tools

import android.app.Activity
import android.content.Context
import okhttp3.OkHttpClient
import java.io.Closeable
import java.util.concurrent.TimeUnit

/**
 * 工具执行器，负责管理所有工具并分发执行
 */
class ToolExecutor(
    val context: Context
) : Closeable {
    private val httpClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(30L, TimeUnit.SECONDS)
        .readTimeout(30L, TimeUnit.SECONDS)
        .build()

    private val tools: Map<String, Tool> = listOf(
        GetCurrentTimeTool(),
        SetAlarmTool(),
        AddCalendarEventTool(context),
        SendSmsTool(context),
        AddNoteTool(),
        WebSearchTool(httpClient)
    ).associateBy { it.name }

    fun getTool(name: String): Tool? = tools[name]

    fun getTools(): List<Tool> = tools.values.toList()

    /**
     * 获取所有工具定义，用于传给 LLM
     */
    fun getToolDefinitions(): List<ToolDefinition> = ToolsDefinition.getTools()

    /**
     * 获取工具风险等级
     */
    fun getToolRiskLevel(toolName: String): RiskLevel {
        return tools[toolName]?.riskLevel ?: RiskLevel.HIGH
    }

    /**
     * 检查工具需要的权限是否已授予
     */
    fun hasRequiredPermissions(toolName: String): Boolean {
        return tools[toolName]?.hasPermissions(context) ?: false
    }

    /**
     * 获取工具需要的权限列表
     */
    fun getRequiredPermissions(toolName: String): List<String> {
        return tools[toolName]?.requiredPermissions ?: emptyList()
    }

    fun execute(toolCall: ToolCall): ToolResult {
        return tools[toolCall.name]?.execute(context, toolCall.arguments)
            ?: ToolResult(
                toolCallId = toolCall.id,
                toolName = toolCall.name,
                success = false,
                result = "",
                error = "未知工具: ${toolCall.name}"
            )
    }

    fun hasPermissions(toolName: String): Boolean {
        return tools[toolName]?.hasPermissions(context) ?: false
    }

    fun requestPermissions(toolName: String, activity: Activity, callback: (Boolean) -> Unit) {
        tools[toolName]?.requestPermissions(activity, callback)
    }

    /**
     * 检查工具是否存在
     */
    fun hasTool(toolName: String): Boolean = tools[toolName] != null

    companion object {
        val TOOL_NAMES = listOf(
            "get_current_time",
            "set_alarm",
            "add_calendar_event",
            "send_sms",
            "add_note",
            "web_search"
        )
    }

    override fun close() {
        httpClient.dispatcher.executorService.shutdown()
        httpClient.connectionPool.evictAll()
    }
}