package com.example.dodroidai.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * 工具调用审计记录（只保留必要字段，参数截断存储）
 */
@Entity(tableName = "tool_audit_log")
data class ToolAuditEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val toolName: String,
    val argsSummary: String,
    val success: Boolean,
    val error: String?,
    val createdAt: Long = System.currentTimeMillis()
)
