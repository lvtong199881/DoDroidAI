package com.example.dodroidai.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface ToolAuditDao {

    @Insert
    suspend fun insert(entry: ToolAuditEntity)

    @Query("SELECT * FROM tool_audit_log ORDER BY createdAt DESC LIMIT :limit")
    fun observeRecent(limit: Int = 100): Flow<List<ToolAuditEntity>>

    @Query("DELETE FROM tool_audit_log")
    suspend fun clear()
}
