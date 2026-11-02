package com.example.dodroidai.ai.tools

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.provider.CalendarContract
import androidx.core.content.ContextCompat
import java.util.TimeZone

/**
 * 添加日历事件工具
 */
@ToolProvider
object AddCalendarEventTool {

    fun spec(): ToolSpec = ToolSpec(
        name = "add_calendar_event",
        description = "在日历中添加一个事件",
        parameters = ToolParameters(
            properties = mapOf(
                "title" to ToolProperty("string", "事件标题"),
                "description" to ToolProperty("string", "事件描述"),
                "start_time" to ToolProperty("string", "开始时间（ISO 8601 格式，如 2024-01-15T10:00:00）"),
                "end_time" to ToolProperty("string", "结束时间（ISO 8601 格式，如 2024-01-15T11:00:00）")
            ),
            required = listOf("title", "start_time")
        ),
        riskLevel = RiskLevel.MEDIUM,
        requiredPermissions = listOf(
            Manifest.permission.READ_CALENDAR,
            Manifest.permission.WRITE_CALENDAR
        ),
        execute = { ctx, args ->
            val title = args.requireString("title")
            val description = args.optionalString("description") ?: ""
            val startTimeMs = args.requireIsoTime("start_time")
            val endTimeMs = args.optionalIsoTime("end_time") ?: (startTimeMs + 3_600_000)

            val permissionsGranted = listOf(
                Manifest.permission.READ_CALENDAR,
                Manifest.permission.WRITE_CALENDAR
            ).all {
                ContextCompat.checkSelfPermission(ctx.appContext, it) == PackageManager.PERMISSION_GRANTED
            }

            if (!permissionsGranted) {
                ToolOutput(
                    "日历权限被拒绝，无法添加事件",
                    isError = true,
                    errorCode = ToolErrorCode.PERMISSION_DENIED
                )
            } else {
                val values = ContentValues().apply {
                    put(CalendarContract.Events.TITLE, title)
                    put(CalendarContract.Events.DESCRIPTION, description)
                    put(CalendarContract.Events.DTSTART, startTimeMs)
                    put(CalendarContract.Events.DTEND, endTimeMs)
                    put(CalendarContract.Events.CALENDAR_ID, 1)
                    put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
                }

                try {
                    val uri = ctx.appContext.contentResolver
                        .insert(CalendarContract.Events.CONTENT_URI, values)
                    if (uri != null) {
                        ToolOutput("日历事件已添加: $title")
                    } else {
                        ToolOutput("日历事件添加失败，请检查日历权限是否授予", isError = true)
                    }
                } catch (e: SecurityException) {
                    ToolOutput(
                        "日历权限被拒绝，无法添加事件",
                        isError = true,
                        errorCode = ToolErrorCode.PERMISSION_DENIED
                    )
                } catch (e: Exception) {
                    ToolOutput("添加日历事件失败: ${e.message}", isError = true)
                }
            }
        }
    )
}
