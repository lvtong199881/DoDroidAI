package com.example.dodroidai.ai.tools

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import android.util.Log
import androidx.core.content.ContextCompat
import com.example.dodroidai.util.GsonUtil
import java.text.SimpleDateFormat
import java.util.TimeZone

/**
 * 添加日历事件工具
 */
class AddCalendarEventTool(private val context: Context) : Tool {
    /** 工具名称 */
    override val name = "add_calendar_event"

    /** 需要日历读写权限 */
    override val requiredPermissions = listOf(
        Manifest.permission.READ_CALENDAR,
        Manifest.permission.WRITE_CALENDAR
    )

    /** 风险等级中 */
    override val riskLevel = RiskLevel.MEDIUM

    override fun hasPermissions(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED
    }

    override fun requestPermissions(activity: Activity, callback: (Boolean) -> Unit) {
        activity.requestPermissions(requiredPermissions.toTypedArray(), REQUEST_CODE)
    }

    override fun execute(context: Context, arguments: String): ToolResult {
        if (!hasPermissions(context)) {
            return failure("日历权限被拒绝，无法添加事件")
        }

        val args = parseArgs(arguments) ?: return failure("参数解析失败")

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

        return try {
            val uri = context.contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)
            if (uri != null) {
                ToolResult(
                    toolCallId = "",
                    toolName = name,
                    success = true,
                    result = "日历事件已添加: ${args.title}"
                )
            } else {
                failure("日历事件添加失败，请检查日历权限是否授予")
            }
        } catch (e: SecurityException) {
            failure("日历权限被拒绝，无法添加事件")
        } catch (e: Exception) {
            failure("添加日历事件失败: ${e.message}")
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

    private data class Args(
        val title: String,
        val description: String? = null,
        val start_time: String,
        val end_time: String? = null
    ) {
        val startTime: String get() = start_time
        val endTime: String? get() = end_time
    }

    private fun parseArgs(json: String): Args? {
        return try {
            GsonUtil.fromJson(json, Args::class.java)
        } catch (e: Exception) {
            null
        }
    }

    private fun parseIsoTime(isoTime: String): Long {
        return try {
            val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.getDefault())
            format.parse(isoTime)?.time ?: System.currentTimeMillis()
        } catch (e: Exception) {
            System.currentTimeMillis()
        }
    }

    companion object {
        private const val REQUEST_CODE = 100
    }
}