package com.example.dodroidai.ai.tools

import android.content.Context
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.example.dodroidai.data.repository.ScheduledTaskRepository
import com.example.dodroidai.worker.TaskWorker
import java.util.concurrent.TimeUnit

/**
 * 安排一个后台定时任务（到点执行一次，完成后通知）
 */
@ToolProvider
object ScheduleTaskTool {

    fun spec(): ToolSpec = ToolSpec(
        name = "schedule_task",
        description = "在指定分钟数后执行一个后台 AI 任务，完成后通过通知返回结果",
        parameters = ToolParameters(
            properties = mapOf(
                "prompt" to ToolProperty("string", "到点后要执行的任务描述，例如 提醒我喝水"),
                "delay_minutes" to ToolProperty(
                    type = "integer",
                    description = "多少分钟后执行，1-1440",
                    minimum = 1,
                    maximum = 1440
                )
            ),
            required = listOf("prompt", "delay_minutes")
        ),
        riskLevel = RiskLevel.MEDIUM,
        execute = { ctx, args ->
            val prompt = args.requireString("prompt")
            val delayMinutes = args.requireInt("delay_minutes", 1..1440)
            try {
                val runAt = System.currentTimeMillis() + delayMinutes * 60_000L
                val taskId = ScheduledTaskRepository(ctx.appContext).create(prompt, runAt)
                enqueue(ctx.appContext, taskId, delayMinutes * 60_000L)
                ToolOutput("已安排任务（$delayMinutes 分钟后执行）：$prompt")
            } catch (e: Exception) {
                ToolOutput("安排任务失败: ${e.javaClass.simpleName}", isError = true)
            }
        }
    )

    private fun enqueue(context: Context, taskId: Long, delayMs: Long) {
        val request = OneTimeWorkRequestBuilder<TaskWorker>()
            .setInitialDelay(delayMs, TimeUnit.MILLISECONDS)
            .setInputData(workDataOf(TaskWorker.KEY_TASK_ID to taskId))
            .build()
        WorkManager.getInstance(context).enqueue(request)
    }
}
