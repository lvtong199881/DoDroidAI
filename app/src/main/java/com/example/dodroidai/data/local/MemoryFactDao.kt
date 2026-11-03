package com.example.dodroidai.data.local

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface MemoryFactDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(fact: MemoryFactEntity)

    @Delete
    suspend fun delete(fact: MemoryFactEntity)

    @Query("SELECT * FROM memory_facts ORDER BY updatedAt DESC")
    fun observeAll(): Flow<List<MemoryFactEntity>>

    @Query("SELECT * FROM memory_facts ORDER BY updatedAt DESC LIMIT :limit")
    suspend fun recent(limit: Int): List<MemoryFactEntity>

    @Query(
        "SELECT * FROM memory_facts WHERE key LIKE '%' || :query || '%' " +
            "OR value LIKE '%' || :query || '%' ORDER BY updatedAt DESC LIMIT :limit"
    )
    suspend fun search(query: String, limit: Int): List<MemoryFactEntity>
}
