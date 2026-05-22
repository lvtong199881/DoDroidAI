package com.example.dodroidai.ai.tools

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 获取当前时间工具
 */
class GetCurrentTimeTool : Tool {
    /** 工具名称 */
    override val name = "get_current_time"

    /** 无需权限 */
    override val requiredPermissions = emptyList<String>()

    /** 风险等级低 */
    override val riskLevel = RiskLevel.LOW

    override fun hasPermissions(context: Context): Boolean = true

    override fun requestPermissions(activity: android.app.Activity, callback: (Boolean) -> Unit) {
        callback(true)
    }

    override fun execute(context: Context, arguments: String): ToolResult {
        val now = Date()
        val dateFormat = SimpleDateFormat("yyyy年MM月dd日 HH:mm:ss", Locale.getDefault())
        return ToolResult(
            toolCallId = "",
            toolName = name,
            success = true,
            result = dateFormat.format(now)
        )
    }
}