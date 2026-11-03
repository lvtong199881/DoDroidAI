package com.example.dodroidai.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * 单次 AI 请求的诊断记录（不含消息正文与 Key）
 */
@Entity(tableName = "request_traces")
data class RequestTraceEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val provider: String,
    val apiFormat: String,
    val model: String,
    val sessionId: String?,
    val startedAt: Long,
    val durationMs: Long,
    val success: Boolean,
    val error: String?,
    val toolCallCount: Int,
    val messageCount: Int
)
