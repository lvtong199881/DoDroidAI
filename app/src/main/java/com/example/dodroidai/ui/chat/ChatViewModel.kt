package com.example.dodroidai.ui.chat

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.config.AIConfigManager
import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ai.model.ChatMessage
import com.example.dodroidai.ai.model.ChatMessage.Companion.LOADING_THINKING
import com.example.dodroidai.ai.model.ChatMessage.Companion.ROLE_ASSISTANT
import com.example.dodroidai.ai.model.ChatMessage.Companion.ROLE_USER
import com.example.dodroidai.data.model.ChatSession
import com.example.dodroidai.data.repository.ChatRepository
import com.example.dodroidai.ai.repository.DeepSeekModel
import com.example.dodroidai.ai.repository.MiniMaxModel
import com.example.dodroidai.ai.repository.OpenAIModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

/**
 * 聊天列表 UI 状态
 */
data class ChatUiState(
    val messages: List<ChatMessage> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val sessionId: String? = null,
    val sessionName: String? = null
)

/**
 * 聊天页面 ViewModel
 */
class ChatViewModel(
    private val configManager: AIConfigManager,
    private val chatRepository: ChatRepository,
    private val sessionId: String? = null
) : ViewModel() {

    companion object {
        private const val MAX_CONTEXT_MESSAGES = 20
    }

    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    private val openAIModel = OpenAIModel()
    private val deepSeekModel = DeepSeekModel()
    private val miniMaxModel = MiniMaxModel()

    init {
        if (sessionId != null) {
            loadSession(sessionId)
        }
    }

    private fun loadSession(sessionId: String) {
        viewModelScope.launch {
            val sessions = chatRepository.sessionsFlow.first()
            val session = sessions.find { it.id == sessionId }
            session?.let {
                _uiState.value = _uiState.value.copy(
                    messages = it.messages,
                    sessionId = sessionId,
                    sessionName = it.title
                )
            }
        }
    }

    fun sendMessage(content: String) {
        if (content.isBlank()) return

        viewModelScope.launch {
            val userMessage = ChatMessage(
                role = ROLE_USER,
                content = content.trim()
            )

            val loadingMessage = ChatMessage(
                role = ROLE_ASSISTANT,
                content = "",
                isLoading = true,
                loadingState = LOADING_THINKING,
                loadingSeconds = 0
            )

            _uiState.value = _uiState.value.copy(
                messages = _uiState.value.messages + userMessage + loadingMessage,
                isLoading = true,
                error = null
            )

            var seconds = 0
            val loadingJob = launch {
                while (true) {
                    delay(1000L)
                    seconds++

                    val currentMessages = _uiState.value.messages.toMutableList()
                    val lastIndex = currentMessages.lastIndex
                    if (lastIndex >= 0 && currentMessages[lastIndex].isLoading) {
                        currentMessages[lastIndex] = currentMessages[lastIndex].copy(
                            loadingSeconds = seconds
                        )
                        _uiState.value = _uiState.value.copy(messages = currentMessages)
                    } else {
                        break
                    }
                }
            }

            try {
                val config = getCurrentConfig()
                val historyMessages = _uiState.value.messages.filter { !it.isLoading }
                val recentMessages = if (historyMessages.size > MAX_CONTEXT_MESSAGES) {
                    historyMessages.takeLast(MAX_CONTEXT_MESSAGES)
                } else {
                    historyMessages
                }
                val allMessages = recentMessages + userMessage
                val response = withContext(Dispatchers.IO) {
                    when (config.provider) {
                        AIProvider.OPENAI -> openAIModel.executeChat(config, allMessages)
                        AIProvider.DEEPSEEK -> deepSeekModel.executeChat(config, allMessages)
                        AIProvider.MINIMAX -> miniMaxModel.executeChat(config, allMessages)
                        AIProvider.CUSTOM -> throw IllegalStateException("Custom provider not supported")
                    }
                }

                loadingJob.cancel()

                val currentMessages = _uiState.value.messages.toMutableList()
                val lastIndex = currentMessages.lastIndex
                if (lastIndex >= 0 && currentMessages[lastIndex].isLoading) {
                    currentMessages[lastIndex] = ChatMessage(
                        role = ROLE_ASSISTANT,
                        content = response.content
                    )
                }

                _uiState.value = _uiState.value.copy(
                    messages = currentMessages,
                    isLoading = false
                )

                saveCurrentSession()
            } catch (e: Exception) {
                loadingJob.cancel()

                val currentMessages = _uiState.value.messages.toMutableList()
                val lastIndex = currentMessages.lastIndex
                if (lastIndex >= 0 && currentMessages[lastIndex].isLoading) {
                    currentMessages[lastIndex] = ChatMessage(
                        role = ROLE_ASSISTANT,
                        content = e.message ?: "Unknown error",
                        isLoading = false
                    )
                }

                _uiState.value = _uiState.value.copy(
                    messages = currentMessages,
                    isLoading = false
                )
            }
        }
    }

    private suspend fun saveCurrentSession() {
        val currentState = _uiState.value
        val messages = currentState.messages.filter { !it.isLoading }

        if (messages.isEmpty()) return

        val existingSession = if (currentState.sessionId != null) {
            chatRepository.sessionsFlow.first().find { it.id == currentState.sessionId }
        } else null

        val session = if (existingSession != null) {
            existingSession.copy(
                messages = messages,
                title = if (existingSession.messages.isEmpty()) messages.first().content.take(20) else existingSession.title,
                updatedAt = System.currentTimeMillis()
            )
        } else {
            val firstMessage = messages.first().content
            val newSession = ChatSession(
                id = UUID.randomUUID().toString(),
                title = firstMessage.take(20),
                messages = messages,
                createdAt = System.currentTimeMillis(),
                updatedAt = System.currentTimeMillis()
            )
            Log.d("ChatViewModel", "Creating new session: ${newSession.id}, title: ${newSession.title}")
            newSession
        }

        chatRepository.saveSession(session)
        _uiState.value = _uiState.value.copy(sessionId = session.id)
    }

    private suspend fun getCurrentConfig(): AIConfig {
        return configManager.configFlow.first()
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    class Factory(
        private val configManager: AIConfigManager,
        private val chatRepository: ChatRepository,
        private val sessionId: String? = null
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            return ChatViewModel(configManager, chatRepository, sessionId) as T
        }
    }
}