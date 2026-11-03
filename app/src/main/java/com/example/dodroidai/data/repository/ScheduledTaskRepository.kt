package com.example.dodroidai.data.repository

import android.content.Context
import com.example.dodroidai.data.local.AppDatabase
import com.example.dodroidai.data.local.ScheduledTaskEntity
import kotlinx.coroutines.flow.Flow

class ScheduledTaskRepository(context: Context) {

    private val dao = AppDatabase.get(context).scheduledTaskDao()

    fun observeAll(): Flow<List<ScheduledTaskEntity>> = dao.observeAll()

    suspend fun find(id: Long): ScheduledTaskEntity? = dao.find(id)

    suspend fun create(prompt: String, runAt: Long): Long =
        dao.insert(ScheduledTaskEntity(prompt = prompt, runAt = runAt, status = "pending", result = null))

    suspend fun complete(id: Long, status: String, result: String?) =
        dao.updateStatus(id, status, result)

    suspend fun delete(task: ScheduledTaskEntity) = dao.delete(task)
}
