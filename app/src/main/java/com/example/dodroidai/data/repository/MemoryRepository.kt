package com.example.dodroidai.data.repository

import android.content.Context
import com.example.dodroidai.data.local.AppDatabase
import com.example.dodroidai.data.local.MemoryFactEntity
import kotlinx.coroutines.flow.Flow

class MemoryRepository(context: Context) {

    private val dao = AppDatabase.get(context).memoryFactDao()

    fun observeAll(): Flow<List<MemoryFactEntity>> = dao.observeAll()

    suspend fun remember(key: String, value: String, sourceSessionId: String? = null): Long {
        val now = System.currentTimeMillis()
        dao.insert(
            MemoryFactEntity(
                key = key.trim(),
                value = value.trim(),
                sourceSessionId = sourceSessionId,
                createdAt = now,
                updatedAt = now
            )
        )
        return now
    }

    suspend fun delete(fact: MemoryFactEntity) = dao.delete(fact)

    /**
     * 取与当前输入相关的记忆；没有命中时退回最近几条，保证偏好类信息也能被带上。
     */
    suspend fun findRelevant(query: String): List<MemoryFactEntity> {
        if (query.isBlank()) return dao.recent(3)
        val matched = dao.search(query.trim(), 8)
        return matched.ifEmpty { dao.recent(3) }
    }
}
