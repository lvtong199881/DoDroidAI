package com.example.dodroidai.data.repository

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.example.dodroidai.data.model.ChatSession
import com.example.dodroidai.util.GsonUtil
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.util.UUID

private val Context.chatDataStore: DataStore<Preferences> by preferencesDataStore(name = "chat_sessions")

/**
 * 聊天会话仓库，负责持久化聊天会话
 */
class ChatRepository(private val context: Context) {

    private val sessionsKey = stringPreferencesKey("sessions")

    val sessionsFlow: Flow<List<ChatSession>> = context.chatDataStore.data.map { preferences ->
        val sessionsJson = preferences[sessionsKey] ?: "[]"
        try {
            val type = object : TypeToken<List<ChatSession>>() {}.type
            GsonUtil.fromJsonWithTypeToken(sessionsJson, object : TypeToken<List<ChatSession>>() {}) ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun saveSession(session: ChatSession) {
        context.chatDataStore.edit { preferences ->
            val currentSessions = try {
                val type = object : TypeToken<List<ChatSession>>() {}.type
                GsonUtil.fromJsonWithTypeToken(preferences[sessionsKey] ?: "[]", object : TypeToken<List<ChatSession>>() {}) ?: emptyList()
            } catch (e: Exception) {
                emptyList()
            }

            val updatedSessions = currentSessions.filter { it.id != session.id } + session
            preferences[sessionsKey] = GsonUtil.toJson(updatedSessions) ?: "[]"
        }
    }

    suspend fun deleteSession(sessionId: String) {
        context.chatDataStore.edit { preferences ->
            val currentSessions = try {
                val type = object : TypeToken<List<ChatSession>>() {}.type
                GsonUtil.fromJsonWithTypeToken(preferences[sessionsKey] ?: "[]", object : TypeToken<List<ChatSession>>() {}) ?: emptyList()
            } catch (e: Exception) {
                emptyList()
            }

            val updatedSessions = currentSessions.filter { it.id != sessionId }
            preferences[sessionsKey] = GsonUtil.toJson(updatedSessions) ?: "[]"
        }
    }

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