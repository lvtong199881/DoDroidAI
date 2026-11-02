package com.example.dodroidai.ai.tools

import android.content.Intent
import android.provider.AlarmClock
import java.util.Locale

/**
 * 设置闹钟工具
 */
@ToolProvider
object SetAlarmTool {

    fun spec(): ToolSpec = ToolSpec(
        name = "set_alarm",
        description = "设置一个闹钟。此工具会自动计算正确的日期（如果设置的时间已过，会自动设为明天），不需要先调用get_current_time。",
        parameters = ToolParameters(
            properties = mapOf(
                "hour" to ToolProperty("integer", "小时（0-23）", minimum = 0, maximum = 23),
                "minute" to ToolProperty("integer", "分钟（0-59）", minimum = 0, maximum = 59),
                "label" to ToolProperty("string", "闹钟标签/备注")
            ),
            required = listOf("hour", "minute")
        ),
        riskLevel = RiskLevel.MEDIUM,
        execute = { ctx, args ->
            val hour = args.requireInt("hour", 0..23)
            val minute = args.requireInt("minute", 0..59)
            val label = args.optionalString("label") ?: "闹钟"
            val timeStr = String.format(Locale.getDefault(), "%02d:%02d", hour, minute)

            val alarmIntent = Intent().apply {
                action = AlarmClock.ACTION_SET_ALARM
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                putExtra(AlarmClock.EXTRA_MESSAGE, label)
                putExtra(AlarmClock.EXTRA_SKIP_UI, true)
            }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            try {
                ctx.appContext.startActivity(alarmIntent)
                ToolOutput("闹钟已设置: $timeStr，标签: $label")
            } catch (e: SecurityException) {
                try {
                    val fallbackIntent = Intent(AlarmClock.ACTION_SHOW_ALARMS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    ctx.appContext.startActivity(fallbackIntent)
                    ToolOutput("已打开闹钟应用，请手动设置 $timeStr 的闹钟")
                } catch (e2: Exception) {
                    ToolOutput("无法打开闹钟应用: ${e2.message}", isError = true)
                }
            } catch (e: Exception) {
                ToolOutput("设置闹钟失败: ${e.message}", isError = true)
            }
        }
    )
}
