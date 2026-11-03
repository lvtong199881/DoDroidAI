package com.example.dodroidai.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "scheduled_tasks")
data class ScheduledTaskEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val prompt: String,
    val runAt: Long,
    /** pending / done / failed */
    val status: String,
    val result: String?,
    val createdAt: Long = System.currentTimeMillis()
)
