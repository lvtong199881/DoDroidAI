package com.example.dodroidai.data.repository

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.example.dodroidai.ai.model.ChatAttachment
import com.example.dodroidai.ai.model.ChatMessage
import com.example.dodroidai.ai.tools.ToolCall
import com.example.dodroidai.ai.tools.ToolCallDisplay
import com.example.dodroidai.data.local.AppDatabase
import com.example.dodroidai.data.local.ChatDao
import com.example.dodroidai.data.local.MessageEntity
import com.example.dodroidai.data.local.SessionEntity
import com.example.dodroidai.data.model.ChatSession
import com.example.dodroidai.util.GsonUtil
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

private val Context.chatDataStore: DataStore<Preferences> by preferencesDataStore(name = "chat_sessions")

/**
 * 聊天会话仓库：会话/消息关系化存储在 Room（sessions / messages 表）。
 *
 * 首次启动时会把旧版 DataStore JSON 迁移到 Room，然后清空旧键。
 */
class ChatRepository(private val context: Context) {

    private val dao: ChatDao = AppDatabase.get(context).chatDao()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val sessionsKey = stringPreferencesKey("sessions")

    val sessionsFlow: Flow<List<ChatSession>> = dao.observeSessions().map { sessions ->
        sessions.map { it.toChatSession() }
    }

    init {
        scope.launch { migrateLegacyIfNeeded() }
    }

    suspend fun saveSession(session: ChatSession) {
        // pinned 由会话菜单维护，保存消息时保留原值
        val existingPinned = dao.findSession(session.id)?.pinned ?: false
        dao.replaceSession(
            session = SessionEntity(
                id = session.id,
                title = session.title,
                createdAt = session.createdAt,
                updatedAt = session.updatedAt,
                pinned = existingPinned
            ),
            messages = session.messages.mapIndexed { index, message ->
                message.toEntity(session.id, index)
            }
        )
    }

    suspend fun deleteSession(sessionId: String) {
        dao.deleteSession(sessionId)
    }

    suspend fun renameSession(sessionId: String, title: String) {
        dao.renameSession(sessionId, title.trim().ifBlank { "新对话" }, System.currentTimeMillis())
    }

    suspend fun setPinned(sessionId: String, pinned: Boolean) {
        dao.setPinned(sessionId, pinned)
    }

    suspend fun searchSessions(query: String): List<ChatSession> {
        if (query.isBlank()) return emptyList()
        return dao.searchSessions(query.trim()).map { it.toChatSession() }
    }

    /**
     * 导出会话为 Markdown 文本。
     */
    suspend fun exportSession(sessionId: String): String {
        val entity = dao.findSession(sessionId) ?: return ""
        val messages = dao.messagesOf(sessionId)
        return buildString {
            appendLine("# ${entity.title}")
            appendLine()
            messages.forEach { message ->
                val who = when (message.role) {
                    ChatMessage.ROLE_USER -> "用户"
                    ChatMessage.ROLE_ASSISTANT -> "助手"
                    else -> message.role
                }
                appendLine("**$who**：${message.content}")
                appendLine()
            }
        }
    }

    private suspend fun SessionEntity.toChatSession(): ChatSession = ChatSession(
        id = id,
        title = title,
        messages = dao.messagesOf(id).map { it.toChatMessage() },
        createdAt = createdAt,
        updatedAt = updatedAt,
        pinned = pinned
    )

    private suspend fun migrateLegacyIfNeeded() {
        val legacyJson = try {
            context.chatDataStore.data.first()[sessionsKey]
        } catch (e: Exception) {
            null
        } ?: return

        if (legacyJson.isBlank() || legacyJson == "[]") {
            clearLegacy()
            return
        }
        // Room 已有数据时以 Room 为准，直接清掉旧 JSON
        if (dao.countSessions() > 0) {
            clearLegacy()
            return
        }

        val sessions = try {
            GsonUtil.fromJsonWithTypeToken(
                legacyJson,
                object : TypeToken<List<ChatSession>>() {}
            ) ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }

        sessions.forEach { saveSession(it) }
        clearLegacy()
    }

    private suspend fun clearLegacy() {
        try {
            context.chatDataStore.edit { it.remove(sessionsKey) }
        } catch (e: Exception) {
            // 迁移失败不影响 Room 主流程
        }
    }

    private fun MessageEntity.toChatMessage(): ChatMessage = ChatMessage(
        role = role,
        content = content,
        timestamp = timestamp,
        toolCalls = decodeList<ToolCallDisplay>(toolCallsJson),
        toolCallPayloads = decodeList<ToolCall>(toolCallPayloadsJson),
        attachments = decodeList<ChatAttachment>(attachmentsJson),
        toolCallId = toolCallId,
        reasoningContent = reasoning,
        isError = isError,
        isReasoningExpanded = isReasoningExpanded
    )

    private inline fun <reified T> decodeList(json: String?): List<T>? = json?.let {
        try {
            GsonUtil.fromJsonWithTypeToken(it, object : TypeToken<List<T>>() {})
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun ChatMessage.toEntity(sessionId: String, orderIndex: Int): MessageEntity =
        MessageEntity(
            sessionId = sessionId,
            orderIndex = orderIndex,
            role = role,
            content = content,
            reasoning = reasoningContent,
            timestamp = timestamp,
            toolCallsJson = GsonUtil.toJson(toolCalls),
            toolCallPayloadsJson = GsonUtil.toJson(toolCallPayloads),
            attachmentsJson = GsonUtil.toJson(attachments),
            toolCallId = toolCallId,
            isError = isError,
            isReasoningExpanded = isReasoningExpanded
        )

    companion object {
        @Volatile
        private var INSTANCE: ChatRepository? = null

        fun getInstance(context: Context): ChatRepository {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: ChatRepository(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
}
