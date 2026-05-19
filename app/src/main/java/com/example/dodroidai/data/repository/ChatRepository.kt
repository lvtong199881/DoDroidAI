package com.example.dodroidai.data.repository

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.example.dodroidai.data.model.ChatSession
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.util.UUID

private val Context.chatDataStore: DataStore<Preferences> by preferencesDataStore(name = "chat_sessions")

/**
 * 聊天会话仓库，负责持久化聊天会话
 */
class ChatRepository(private val context: Context) {

    private val gson = Gson()

    private val sessionsKey = stringPreferencesKey("sessions")

    val sessionsFlow: Flow<List<ChatSession>> = context.chatDataStore.data.map { preferences ->
        val sessionsJson = preferences[sessionsKey] ?: "[]"
        try {
            val type = object : TypeToken<List<ChatSession>>() {}.type
            gson.fromJson<List<ChatSession>>(sessionsJson, type) ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun saveSession(session: ChatSession) {
        context.chatDataStore.edit { preferences ->
            val currentSessions = try {
                val type = object : TypeToken<List<ChatSession>>() {}.type
                gson.fromJson<List<ChatSession>>(preferences[sessionsKey] ?: "[]", type) ?: emptyList()
            } catch (e: Exception) {
                emptyList()
            }

            val updatedSessions = currentSessions.filter { it.id != session.id } + session
            preferences[sessionsKey] = gson.toJson(updatedSessions)
        }
    }

    suspend fun deleteSession(sessionId: String) {
        context.chatDataStore.edit { preferences ->
            val currentSessions = try {
                val type = object : TypeToken<List<ChatSession>>() {}.type
                gson.fromJson<List<ChatSession>>(preferences[sessionsKey] ?: "[]", type) ?: emptyList()
            } catch (e: Exception) {
                emptyList()
            }

            val updatedSessions = currentSessions.filter { it.id != sessionId }
            preferences[sessionsKey] = gson.toJson(updatedSessions)
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