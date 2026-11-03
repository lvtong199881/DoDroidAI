package com.example.dodroidai.data.repository

import android.content.Context
import com.example.dodroidai.ai.tools.ToolCall
import com.example.dodroidai.ai.tools.ToolResult
import com.example.dodroidai.data.local.AppDatabase
import com.example.dodroidai.data.local.ToolAuditEntity
import kotlinx.coroutines.flow.Flow

class ToolAuditRepository(context: Context) {

    private val dao = AppDatabase.get(context).toolAuditDao()

    fun observeRecent(limit: Int = 100): Flow<List<ToolAuditEntity>> = dao.observeRecent(limit)

    suspend fun record(toolCall: ToolCall, result: ToolResult) {
        dao.insert(
            ToolAuditEntity(
                toolName = result.toolName,
                argsSummary = toolCall.arguments.take(200),
                success = result.success,
                error = result.error
            )
        )
    }

    suspend fun clear() = dao.clear()
}
