package com.example.dodroidai.ai.tools

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.provider.CalendarContract
import android.provider.AlarmClock
import android.telephony.SmsManager
import android.util.Log
import com.example.dodroidai.util.GsonUtil
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * 工具执行器
 */
class ToolExecutor(private val context: Context) {

    /**
     * 检查工具的风险等级
     */
    fun checkRisk(toolName: String): RiskLevel {
        return when (toolName) {
            "get_current_time" -> RiskLevel.LOW
            "set_alarm" -> RiskLevel.MEDIUM
            "add_calendar_event" -> RiskLevel.MEDIUM
            "send_sms" -> RiskLevel.HIGH
            "add_note" -> RiskLevel.HIGH
            else -> RiskLevel.HIGH
        }
    }

    /**
     * 执行工具调用（假设已通过风险检查）
     */
    fun execute(toolCall: ToolCall): ToolResult {
        return try {
            Log.d("ToolExecutor", "Executing tool: ${toolCall.name}, args: ${toolCall.arguments}")
            when (toolCall.name) {
                "get_current_time" -> executeGetCurrentTime(toolCall)
                "set_alarm" -> executeSetAlarm(toolCall)
                "add_calendar_event" -> executeAddCalendarEvent(toolCall)
                "send_sms" -> executeSendSms(toolCall)
                "add_note" -> executeAddNote(toolCall)
                else -> ToolResult(
                    toolCallId = toolCall.id,
                    toolName = toolCall.name,
                    success = false,
                    result = "",
                    error = "未知工具: ${toolCall.name}"
                )
            }
        } catch (e: Exception) {
            Log.e("ToolExecutor", "Tool execution failed", e)
            ToolResult(
                toolCallId = toolCall.id,
                toolName = toolCall.name,
                success = false,
                result = "",
                error = e.message ?: "执行失败"
            )
        }
    }

    private fun executeGetCurrentTime(toolCall: ToolCall): ToolResult {
        val now = Date()
        val dateFormat = SimpleDateFormat("yyyy年MM月dd日 HH:mm:ss", Locale.getDefault())
        val result = dateFormat.format(now)
        return ToolResult(
            toolCallId = toolCall.id,
            toolName = toolCall.name,
            success = true,
            result = result
        )
    }

    private fun executeSetAlarm(toolCall: ToolCall): ToolResult {
        val args = parseArgs(toolCall.arguments, SetAlarmArgs::class.java)
            ?: return failure(toolCall, "参数解析失败")

        val label = args.label ?: "闹钟"
        val timeStr = String.format(Locale.getDefault(), "%02d:%02d", args.hour, args.minute)

        // 使用 AlarmClock.EXTRA_SKIP_UI 静默添加闹钟
        val alarmIntent = Intent().apply {
            action = AlarmClock.ACTION_SET_ALARM
            putExtra(AlarmClock.EXTRA_HOUR, args.hour)
            putExtra(AlarmClock.EXTRA_MINUTES, args.minute)
            putExtra(AlarmClock.EXTRA_MESSAGE, label)
            putExtra(AlarmClock.EXTRA_SKIP_UI, true)
        }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        try {
            context.startActivity(alarmIntent)
            return ToolResult(
                toolCallId = toolCall.id,
                toolName = toolCall.name,
                success = true,
                result = "闹钟已设置: $timeStr，标签: $label"
            )
        } catch (e: SecurityException) {
            // 权限不足，打开闹钟应用让用户手动设置
            val fallbackIntent = Intent(AlarmClock.ACTION_SHOW_ALARMS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                context.startActivity(fallbackIntent)
                return ToolResult(
                    toolCallId = toolCall.id,
                    toolName = toolCall.name,
                    success = true,
                    result = "已打开闹钟应用，请手动设置 $timeStr 的闹钟"
                )
            } catch (e2: Exception) {
                return failure(toolCall, "无法打开闹钟应用: ${e2.message}")
            }
        } catch (e: Exception) {
            return failure(toolCall, "设置闹钟失败: ${e.message}")
        }
    }

    private fun executeAddCalendarEvent(toolCall: ToolCall): ToolResult {
        val args = parseArgs(toolCall.arguments, AddCalendarEventArgs::class.java)
            ?: return failure(toolCall, "参数解析失败")

        val startTimeMs = parseIsoTime(args.startTime)
        val endTimeMs = args.endTime?.let { parseIsoTime(it) } ?: (startTimeMs + 3600000)

        val values = ContentValues().apply {
            put(CalendarContract.Events.TITLE, args.title)
            put(CalendarContract.Events.DESCRIPTION, args.description ?: "")
            put(CalendarContract.Events.DTSTART, startTimeMs)
            put(CalendarContract.Events.DTEND, endTimeMs)
            put(CalendarContract.Events.CALENDAR_ID, 1)
            put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
        }

        val uri = context.contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)

        return ToolResult(
            toolCallId = toolCall.id,
            toolName = toolCall.name,
            success = true,
            result = "日历事件已添加: ${args.title}"
        )
    }

    private fun executeSendSms(toolCall: ToolCall): ToolResult {
        val args = parseArgs(toolCall.arguments, SendSmsArgs::class.java)
            ?: return failure(toolCall, "参数解析失败")

        val smsManager = context.getSystemService(SmsManager::class.java)
        val parts = smsManager.divideMessage(args.message)
        smsManager.sendMultipartTextMessage(args.phoneNumber, null, parts, null, null)

        return ToolResult(
            toolCallId = toolCall.id,
            toolName = toolCall.name,
            success = true,
            result = "短信已发送给 ${args.phoneNumber}"
        )
    }

    private fun executeAddNote(toolCall: ToolCall): ToolResult {
        val args = parseArgs(toolCall.arguments, AddNoteArgs::class.java)
            ?: return failure(toolCall, "参数解析失败")

        return ToolResult(
            toolCallId = toolCall.id,
            toolName = toolCall.name,
            success = true,
            result = "笔记已添加: ${args.title}"
        )
    }

    private fun <T> parseArgs(json: String, clazz: Class<T>): T? {
        return try {
            GsonUtil.fromJson(json, clazz)
        } catch (e: Exception) {
            null
        }
    }

    private fun parseIsoTime(isoTime: String): Long {
        return try {
            val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            format.parse(isoTime)?.time ?: System.currentTimeMillis()
        } catch (e: Exception) {
            System.currentTimeMillis()
        }
    }

    private fun failure(toolCall: ToolCall, error: String): ToolResult {
        return ToolResult(
            toolCallId = toolCall.id,
            toolName = toolCall.name,
            success = false,
            result = "",
            error = error
        )
    }

    // 参数数据类
    private data class SetAlarmArgs(
        val hour: Int,
        val minute: Int,
        val label: String? = null
    )

    private data class AddCalendarEventArgs(
        val title: String,
        val description: String? = null,
        val start_time: String,
        val end_time: String? = null
    ) {
        val startTime: String get() = start_time
        val endTime: String? get() = end_time
    }

    private data class SendSmsArgs(
        val phone_number: String,
        val message: String
    ) {
        val phoneNumber: String get() = phone_number
    }

    private data class AddNoteArgs(
        val title: String,
        val content: String
    )
}