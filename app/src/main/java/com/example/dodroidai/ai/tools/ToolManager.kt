package com.example.dodroidai.ai.tools

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat

/**
 * 工具管理器
 */
class ToolManager(private val context: Context) {

    private val toolExecutor = ToolExecutor(context)

    /**
     * 获取所有工具定义
     */
    fun getToolDefinitions(): List<ToolDefinition> {
        return ToolsDefinition.getTools()
    }

    /**
     * 获取工具风险等级
     */
    fun getToolRiskLevel(toolName: String): RiskLevel {
        return toolExecutor.checkRisk(toolName)
    }

    /**
     * 检查工具需要的权限是否已授予
     */
    fun hasRequiredPermissions(toolName: String): Boolean {
        return when (toolName) {
            "set_alarm" -> hasAlarmPermission()
            "add_calendar_event" -> hasCalendarPermission()
            "send_sms" -> hasSmsPermission()
            else -> true
        }
    }

    /**
     * 检查闹钟权限
     * set_alarm 使用系统 Intent，不需要运行时权限检查
     */
    fun hasAlarmPermission(): Boolean {
        return true
    }

    /**
     * 检查日历权限
     */
    fun hasCalendarPermission(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * 检查短信权限
     */
    fun hasSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * 获取工具需要的权限列表
     */
    fun getRequiredPermissions(toolName: String): List<String> {
        // set_alarm 使用系统 Intent，不需要运行时权限
        return when (toolName) {
            "add_calendar_event" -> listOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR)
            "send_sms" -> listOf(Manifest.permission.SEND_SMS)
            else -> emptyList()
        }
    }

    /**
     * 执行单个工具调用（已通过权限检查）
     */
    fun executeTool(toolCall: ToolCall): ToolResult {
        return toolExecutor.execute(toolCall)
    }

    /**
     * 批量执行工具调用
     */
    fun executeTools(toolCalls: List<ToolCall>): List<ToolResult> {
        return toolCalls.map { executeTool(it) }
    }

    /**
     * 检查工具是否存在
     */
    fun hasTool(toolName: String): Boolean {
        return getToolDefinitions().any { it.name == toolName }
    }

    /**
     * 获取工具定义
     */
    fun getToolDefinition(toolName: String): ToolDefinition? {
        return getToolDefinitions().find { it.name == toolName }
    }
}