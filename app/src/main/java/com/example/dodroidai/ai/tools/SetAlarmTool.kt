package com.example.dodroidai.ai.tools

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.provider.AlarmClock
import android.util.Log
import com.example.dodroidai.util.GsonUtil
import java.util.Locale

/**
 * 设置闹钟工具
 */
class SetAlarmTool : Tool {
    /** 工具名称 */
    override val name = "set_alarm"

    /** 无需运行时权限，使用系统 Intent */
    override val requiredPermissions = emptyList<String>()

    /** 风险等级中 */
    override val riskLevel = RiskLevel.MEDIUM

    override fun hasPermissions(context: Context): Boolean = true

    override fun requestPermissions(activity: Activity, callback: (Boolean) -> Unit) {
        callback(true)
    }

    override fun execute(context: Context, arguments: String): ToolResult {
        val args = parseArgs(arguments) ?: return failure("参数解析失败")

        val label = args.label ?: "闹钟"
        val timeStr = String.format(Locale.getDefault(), "%02d:%02d", args.hour, args.minute)

        val alarmIntent = Intent().apply {
            action = AlarmClock.ACTION_SET_ALARM
            putExtra(AlarmClock.EXTRA_HOUR, args.hour)
            putExtra(AlarmClock.EXTRA_MINUTES, args.minute)
            putExtra(AlarmClock.EXTRA_MESSAGE, label)
            putExtra(AlarmClock.EXTRA_SKIP_UI, true)
        }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        return try {
            context.startActivity(alarmIntent)
            ToolResult(
                toolCallId = "",
                toolName = name,
                success = true,
                result = "闹钟已设置: $timeStr，标签: $label"
            )
        } catch (e: SecurityException) {
            val fallbackIntent = Intent(AlarmClock.ACTION_SHOW_ALARMS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                context.startActivity(fallbackIntent)
                ToolResult(
                    toolCallId = "",
                    toolName = name,
                    success = true,
                    result = "已打开闹钟应用，请手动设置 $timeStr 的闹钟"
                )
            } catch (e2: Exception) {
                failure("无法打开闹钟应用: ${e2.message}")
            }
        } catch (e: Exception) {
            failure("设置闹钟失败: ${e.message}")
        }
    }

    private fun failure(error: String): ToolResult {
        return ToolResult(
            toolCallId = "",
            toolName = name,
            success = false,
            result = "",
            error = error
        )
    }

    private data class Args(val hour: Int, val minute: Int, val label: String? = null)

    private fun parseArgs(json: String): Args? {
        return try {
            GsonUtil.fromJson(json, Args::class.java)
        } catch (e: Exception) {
            null
        }
    }
}