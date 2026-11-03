package com.example.dodroidai.data.repository

import android.content.Context
import android.util.Log
import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.data.local.AppDatabase
import com.example.dodroidai.data.local.RequestTraceEntity
import com.google.gson.GsonBuilder
import kotlinx.coroutines.flow.Flow

class RequestTraceRepository(context: Context) {

    private val dao = AppDatabase.get(context).requestTraceDao()

    fun observeRecent(limit: Int = 50): Flow<List<RequestTraceEntity>> = dao.observeRecent(limit)

    suspend fun record(
        config: AIConfig?,
        sessionId: String?,
        startedAt: Long,
        durationMs: Long,
        success: Boolean,
        error: String?,
        toolCallCount: Int,
        messageCount: Int
    ) {
        try {
            dao.insert(
                RequestTraceEntity(
                    provider = config?.provider?.name ?: "unknown",
                    apiFormat = config?.apiFormat?.name ?: "unknown",
                    model = config?.model ?: "unknown",
                    sessionId = sessionId,
                    startedAt = startedAt,
                    durationMs = durationMs,
                    success = success,
                    error = error?.take(200),
                    toolCallCount = toolCallCount,
                    messageCount = messageCount
                )
            )
        } catch (e: Exception) {
            Log.w(TAG, "写入请求 trace 失败: ${e.javaClass.simpleName}")
        }
    }

    suspend fun clear() = dao.clear()

    suspend fun exportJson(limit: Int = 50): String {
        val traces = dao.recent(limit)
        return GsonBuilder().setPrettyPrinting().create().toJson(traces)
    }

    companion object {
        private const val TAG = "RequestTraceRepository"
    }
}
