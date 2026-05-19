package com.example.dodroidai.data.model

import com.example.dodroidai.ai.model.ChatMessage
import com.google.gson.annotations.SerializedName

/**
 * 聊天会话数据模型
 */
data class ChatSession(
    @SerializedName("id")
    val id: String,
    @SerializedName("title")
    val title: String,
    @SerializedName("messages")
    val messages: List<ChatMessage>,
    @SerializedName("createdAt")
    val createdAt: Long,
    @SerializedName("updatedAt")
    val updatedAt: Long
)