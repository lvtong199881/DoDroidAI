package com.example.dodroidai.data.local

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface ScheduledTaskDao {

    @Insert
    suspend fun insert(task: ScheduledTaskEntity): Long

    @Delete
    suspend fun delete(task: ScheduledTaskEntity)

    @Query("SELECT * FROM scheduled_tasks WHERE id = :id")
    suspend fun find(id: Long): ScheduledTaskEntity?

    @Query("SELECT * FROM scheduled_tasks ORDER BY runAt DESC")
    fun observeAll(): Flow<List<ScheduledTaskEntity>>

    @Query("UPDATE scheduled_tasks SET status = :status, result = :result WHERE id = :id")
    suspend fun updateStatus(id: Long, status: String, result: String?)
}
