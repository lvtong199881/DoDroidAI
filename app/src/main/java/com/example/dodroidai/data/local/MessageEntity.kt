package com.example.dodroidai.data.local

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index

@Entity(
    tableName = "messages",
    primaryKeys = ["sessionId", "orderIndex"],
    foreignKeys = [
        ForeignKey(
            entity = SessionEntity::class,
            parentColumns = ["id"],
            childColumns = ["sessionId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("sessionId")]
)
data class MessageEntity(
    val sessionId: String,
    val orderIndex: Int,
    val role: String,
    val content: String,
    val reasoning: String?,
    val timestamp: Long,
    val toolCallsJson: String?,
    val toolCallPayloadsJson: String?,
    val attachmentsJson: String?,
    val toolCallId: String?,
    val isError: Boolean?,
    val isReasoningExpanded: Boolean
)
