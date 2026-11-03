package com.example.dodroidai.worker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.dodroidai.R
import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.config.AppConfigManager
import com.example.dodroidai.ai.model.ApiRequestFactory
import com.example.dodroidai.ai.model.ChatMessage
import com.example.dodroidai.ai.model.StreamingCallback
import com.example.dodroidai.ai.streaming.StreamingChatClient
import com.example.dodroidai.ai.tools.ToolCall
import com.example.dodroidai.data.repository.ScheduledTaskRepository
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withTimeout
import okhttp3.OkHttpClient

/**
 * 执行定时任务：读取 prompt，调用一次 AI 请求，结果写库并发通知。
 */
class TaskWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    companion object {
        const val KEY_TASK_ID = "task_id"
        private const val CHANNEL_ID = "scheduled_tasks"
        private const val TIMEOUT_MS = 120_000L
    }

    override suspend fun doWork(): Result {
        val taskId = inputData.getLong(KEY_TASK_ID, -1L)
        if (taskId <= 0L) return Result.failure()

        val repository = ScheduledTaskRepository(applicationContext)
        val task = repository.find(taskId) ?: return Result.success()

        return try {
            val config = AppConfigManager.configFlow.first()
            val result = withTimeout(TIMEOUT_MS) { runRequest(config, task.prompt, taskId) }
            repository.complete(taskId, "done", result)
            notifyResult(taskId, result)
            Result.success()
        } catch (e: Exception) {
            repository.complete(taskId, "failed", e.message)
            notifyResult(taskId, "执行失败: ${e.javaClass.simpleName}")
            Result.failure()
        }
    }

    private suspend fun runRequest(config: AIConfig, prompt: String, taskId: Long): String {
        val client = StreamingChatClient(OkHttpClient())
        val prepared = ApiRequestFactory.build(
            config = config,
            messages = listOf(ChatMessage(role = ChatMessage.ROLE_USER, content = prompt)),
            encoded = emptyMap(),
            tools = emptyList(),
            sessionId = "task_$taskId"
        )
        val deferred = CompletableDeferred<String>()
        client.stream(prepared, object : StreamingCallback {
            override fun onContentDelta(content: String) = Unit
            override fun onReasoningDelta(content: String) = Unit
            override fun onToolCallDelta(toolCallId: String, name: String, argumentsDelta: String) = Unit
            override fun onToolCallComplete(toolCallId: String, name: String, arguments: String) = Unit

            override fun onComplete(
                fullContent: String,
                reasoningContent: String?,
                toolCalls: List<ToolCall>
            ) {
                if (!deferred.isCompleted) deferred.complete(fullContent)
            }

            override fun onError(error: Throwable) {
                if (!deferred.isCompleted) deferred.completeExceptionally(error)
            }
        })
        return deferred.await()
    }

    private fun notifyResult(taskId: Long, text: String) {
        val manager = NotificationManagerCompat.from(applicationContext)
        if (!manager.areNotificationsEnabled()) return
        ensureChannel()

        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(applicationContext.getString(R.string.scheduled_task_notification_title))
            .setContentText(text.take(120))
            .setStyle(NotificationCompat.BigTextStyle().bigText(text.take(2000)))
            .setAutoCancel(true)
            .build()
        try {
            manager.notify(taskId.toInt(), notification)
        } catch (e: SecurityException) {
            // 通知权限缺失时忽略
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = applicationContext.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                applicationContext.getString(R.string.scheduled_task_channel),
                NotificationManager.IMPORTANCE_DEFAULT
            )
        )
    }
}
