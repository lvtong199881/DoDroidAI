package com.example.dodroidai.data.model

import com.example.dodroidai.ai.model.ChatMessage
import kotlinx.serialization.Serializable

/**
 * 聊天会话数据模型
 */
@Serializable
data class ChatSession(
    val id: String,
    val title: String,
    val messages: List<ChatMessage>,
    val createdAt: Long,
    val updatedAt: Long
)