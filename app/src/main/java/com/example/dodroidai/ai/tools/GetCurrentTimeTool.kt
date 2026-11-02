package com.example.dodroidai.ai.tools

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 获取当前时间工具
 */
@ToolProvider
object GetCurrentTimeTool {

    fun spec(): ToolSpec = ToolSpec(
        name = "get_current_time",
        description = "获取当前日期和时间",
        parameters = ToolParameters(),
        riskLevel = RiskLevel.LOW,
        execute = { _, _ ->
            val now = Date()
            val dateFormat = SimpleDateFormat("yyyy年MM月dd日 HH:mm:ss", Locale.getDefault())
            ToolOutput(dateFormat.format(now))
        }
    )
}
