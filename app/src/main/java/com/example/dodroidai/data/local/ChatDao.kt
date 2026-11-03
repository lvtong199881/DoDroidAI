package com.example.dodroidai.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import kotlinx.coroutines.flow.Flow

@Dao
interface ChatDao {

    @Query("SELECT * FROM sessions ORDER BY pinned DESC, updatedAt DESC")
    fun observeSessions(): Flow<List<SessionEntity>>

    @Query("UPDATE sessions SET title = :title, updatedAt = :now WHERE id = :id")
    suspend fun renameSession(id: String, title: String, now: Long)

    @Query("UPDATE sessions SET pinned = :pinned WHERE id = :id")
    suspend fun setPinned(id: String, pinned: Boolean)

    @Query(
        "SELECT * FROM sessions WHERE title LIKE '%' || :query || '%' " +
            "OR id IN (SELECT sessionId FROM messages WHERE content LIKE '%' || :query || '%') " +
            "ORDER BY pinned DESC, updatedAt DESC"
    )
    suspend fun searchSessions(query: String): List<SessionEntity>

    @Query("SELECT * FROM sessions WHERE id = :id")
    suspend fun findSession(id: String): SessionEntity?

    @Query("SELECT COUNT(*) FROM sessions")
    suspend fun countSessions(): Int

    @Query("SELECT * FROM messages WHERE sessionId = :sessionId ORDER BY orderIndex")
    suspend fun messagesOf(sessionId: String): List<MessageEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertSession(session: SessionEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMessages(messages: List<MessageEntity>)

    @Query("DELETE FROM messages WHERE sessionId = :sessionId")
    suspend fun deleteMessages(sessionId: String)

    @Query("DELETE FROM sessions WHERE id = :id")
    suspend fun deleteSession(id: String)

    /**
     * 整体替换一个会话及其消息（事务内先删消息再插入）。
     */
    @Transaction
    suspend fun replaceSession(session: SessionEntity, messages: List<MessageEntity>) {
        upsertSession(session)
        deleteMessages(session.id)
        insertMessages(messages)
    }
}
