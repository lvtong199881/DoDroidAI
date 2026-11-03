package com.example.dodroidai.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface RequestTraceDao {

    @Insert
    suspend fun insert(trace: RequestTraceEntity)

    @Query("SELECT * FROM request_traces ORDER BY startedAt DESC LIMIT :limit")
    fun observeRecent(limit: Int = 50): Flow<List<RequestTraceEntity>>

    @Query("SELECT * FROM request_traces ORDER BY startedAt DESC LIMIT :limit")
    suspend fun recent(limit: Int): List<RequestTraceEntity>

    @Query("DELETE FROM request_traces")
    suspend fun clear()
}
