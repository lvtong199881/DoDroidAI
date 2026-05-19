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
import com.example.dodroidai.ai.model.ChatMessage.Companion.ROLE_TOOL
import com.example.dodroidai.ai.model.ChatResponse
import com.example.dodroidai.ai.repository.DeepSeekModel
import com.example.dodroidai.ai.repository.MiniMaxModel
import com.example.dodroidai.ai.repository.OpenAIModel
import com.example.dodroidai.ai.tools.RiskLevel
import com.example.dodroidai.ai.tools.ToolCall
import com.example.dodroidai.ai.tools.ToolCallDisplay
import com.example.dodroidai.ai.tools.ToolDefinition
import com.example.dodroidai.ai.tools.ToolManager
import com.example.dodroidai.ai.tools.ToolResult
import com.example.dodroidai.data.model.ChatSession
import com.example.dodroidai.data.repository.ChatRepository
import com.google.gson.Gson
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
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
 * 工具调用确认请求
 */
data class ToolConfirmationRequest(
    val toolCall: ToolCall,
    val toolName: String,
    val argsSummary: String,
    val riskLevel: RiskLevel
)

/**
 * 工具权限请求
 */
data class ToolPermissionRequest(
    val toolCall: ToolCall,
    val toolName: String,
    val permission: String,
    val rationale: String
)

/**
 * 工具调用确认结果
 */
sealed class ToolConfirmationResult {
    data class Approved(val toolCall: ToolCall) : ToolConfirmationResult()
    data class Rejected(val toolCallId: String) : ToolConfirmationResult()
}

/**
 * 工具权限结果
 */
sealed class ToolPermissionResult {
    data class Granted(val toolCall: ToolCall) : ToolPermissionResult()
    data class Denied(val toolCallId: String) : ToolPermissionResult()
}

/**
 * 聊天页面 ViewModel
 */
class ChatViewModel(
    private val configManager: AIConfigManager,
    private val chatRepository: ChatRepository,
    private val toolManager: ToolManager,
    private val sessionId: String? = null
) : ViewModel() {

    companion object {
        private const val MAX_CONTEXT_MESSAGES = 20
        private const val MAX_TOOL_CALL_DEPTH = 5
    }

    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    /**
     * 发送工具调用确认请求给 UI
     */
    private val _toolConfirmation = MutableSharedFlow<ToolConfirmationRequest>()
    val toolConfirmation: SharedFlow<ToolConfirmationRequest> = _toolConfirmation.asSharedFlow()

    /**
     * 发送工具权限请求给 UI
     */
    private val _toolPermission = MutableSharedFlow<ToolPermissionRequest>()
    val toolPermission: SharedFlow<ToolPermissionRequest> = _toolPermission.asSharedFlow()

    /**
     * 已确认的工具调用（用户批准后执行）
     */
    private val confirmedToolCalls = mutableListOf<ToolCall>()

    /**
     * 已授予权限的工具调用
     */
    private val grantedPermissions = mutableListOf<ToolCall>()

    /**
     * 被拒绝权限的工具调用ID
     */
    private val deniedPermissionToolCalls = mutableSetOf<String>()

    /**
     * 是否正在等待权限授予
     */
    private var isAwaitingPermission = false

    private val openAIModel = OpenAIModel()
    private val deepSeekModel = DeepSeekModel()
    private val miniMaxModel = MiniMaxModel()

    private val gson = Gson()

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
                val historyMessages = getRecentMessages()
                val allMessages = historyMessages + userMessage
                val tools = toolManager.getToolDefinitions()

                var finalResponse = sendMessageWithTools(config, allMessages, tools)

                // 处理工具调用循环
                var toolCallDepth = 0
                while (finalResponse.toolCalls.isNotEmpty() && toolCallDepth < MAX_TOOL_CALL_DEPTH) {
                    toolCallDepth++
                    finalResponse = processToolCallsAndContinue(config, allMessages, userMessage, finalResponse.toolCalls, tools)
                }

                loadingJob.cancel()

                Log.d("ChatViewModel", "Final response: content='${finalResponse.content}', toolCalls=${finalResponse.toolCalls.size}")
                val toolDisplays = buildToolDisplays(finalResponse.toolCalls, emptyList())
                val assistantMessage = ChatMessage(
                    role = ROLE_ASSISTANT,
                    content = finalResponse.content,
                    toolCalls = toolDisplays
                )

                val currentMessages = _uiState.value.messages.toMutableList()
                val lastIndex = currentMessages.lastIndex
                if (lastIndex >= 0 && currentMessages[lastIndex].isLoading) {
                    currentMessages[lastIndex] = assistantMessage
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

    /**
     * 处理工具调用确认结果
     */
    fun onToolConfirmationResult(result: ToolConfirmationResult) {
        viewModelScope.launch {
            when (result) {
                is ToolConfirmationResult.Approved -> {
                    confirmedToolCalls.add(result.toolCall)
                }
                is ToolConfirmationResult.Rejected -> {
                    // 用户拒绝，无需处理（会记录为失败）
                }
            }
        }
    }

    /**
     * 处理工具权限结果
     */
    fun onPermissionResult(result: ToolPermissionResult) {
        viewModelScope.launch {
            when (result) {
                is ToolPermissionResult.Granted -> {
                    grantedPermissions.add(result.toolCall)
                }
                is ToolPermissionResult.Denied -> {
                    // 权限被拒绝，记录失败
                    deniedPermissionToolCalls.add(result.toolCallId)
                }
            }
            isAwaitingPermission = false
        }
    }

    private suspend fun sendMessageWithTools(
        config: AIConfig,
        messages: List<ChatMessage>,
        tools: List<ToolDefinition>
    ): ChatResponse {
        return withContext(Dispatchers.IO) {
            Log.d("ChatViewModel", "Sending ${messages.size} messages to LLM, tools: ${tools?.size ?: 0}")
            val response: ChatResponse = when (config.provider) {
                AIProvider.OPENAI -> openAIModel.executeChat(config, messages, tools)
                AIProvider.DEEPSEEK -> deepSeekModel.executeChat(config, messages, tools)
                AIProvider.MINIMAX -> miniMaxModel.executeChat(config, messages, tools)
                AIProvider.CUSTOM -> throw IllegalStateException("Custom provider not supported")
            }
            response
        }
    }

    private suspend fun processToolCallsAndContinue(
        config: AIConfig,
        allMessages: List<ChatMessage>,
        userMessage: ChatMessage,
        toolCalls: List<ToolCall>,
        tools: List<ToolDefinition>
    ): ChatResponse {
        // 显示正在执行的工具调用
        val toolDisplaysInProgress = toolCalls.map { call ->
            ToolCallDisplay(
                name = call.name,
                argsSummary = summarizeArgs(call.arguments),
                isRunning = true
            )
        }

        val loadingMessage = ChatMessage(
            role = ROLE_ASSISTANT,
            content = "",
            isLoading = true,
            loadingState = "tool_call",
            toolCalls = toolDisplaysInProgress
        )

        val currentMessages = _uiState.value.messages.toMutableList()
        val lastIndex = currentMessages.lastIndex
        if (lastIndex >= 0 && currentMessages[lastIndex].isLoading) {
            currentMessages[lastIndex] = loadingMessage
            _uiState.value = _uiState.value.copy(messages = currentMessages)
        }

        // 清空已确认的工具调用和权限状态
        confirmedToolCalls.clear()
        grantedPermissions.clear()
        deniedPermissionToolCalls.clear()

        // 检查每个工具的权限，对需要权限但未授权的工具发送权限请求
        for (toolCall in toolCalls) {
            if (!toolManager.hasRequiredPermissions(toolCall.name)) {
                val permissions = toolManager.getRequiredPermissions(toolCall.name)
                if (permissions.isNotEmpty()) {
                    _toolPermission.emit(
                        ToolPermissionRequest(
                            toolCall = toolCall,
                            toolName = toolCall.name,
                            permission = permissions.first(),
                            rationale = getPermissionRationale(toolCall.name)
                        )
                    )
                }
            }
        }

        // 等待权限授予（简化处理，实际应该等待用户响应）
        // 这里需要 UI 层调用 onPermissionResult
        delay(100)
        while (isAwaitingPermission) {
            delay(100)
        }
        delay(300) // 等待 UI 处理

        // 执行有权限的工具调用
        val toolResults = mutableListOf<ToolResult>()
        for (toolCall in toolCalls) {
            if (deniedPermissionToolCalls.contains(toolCall.id)) {
                // 权限被拒绝
                toolResults.add(
                    ToolResult(
                        toolCallId = toolCall.id,
                        toolName = toolCall.name,
                        success = false,
                        result = "",
                        error = "权限被拒绝"
                    )
                )
            } else if (!toolManager.hasRequiredPermissions(toolCall.name)) {
                // 没有权限且未授予
                toolResults.add(
                    ToolResult(
                        toolCallId = toolCall.id,
                        toolName = toolCall.name,
                        success = false,
                        result = "",
                        error = "缺少必要权限"
                    )
                )
            } else {
                // 执行工具
                val result = toolManager.executeTool(toolCall)
                toolResults.add(result)
            }
        }

        // 更新 UI 显示工具结果
        val toolDisplays = buildToolDisplays(toolCalls, toolResults)
        val messageAfterTools = ChatMessage(
            role = ROLE_ASSISTANT,
            content = "",
            toolCalls = toolDisplays
        )

        updateLastAssistantMessage(messageAfterTools)

        // 构建工具消息
        val toolMessages = toolResults.map { result ->
            ChatMessage(
                role = ROLE_TOOL,
                content = if (result.success) result.result else "Error: ${result.error}",
                toolCallId = result.toolCallId,
                toolCalls = listOf(
                    ToolCallDisplay(
                        name = result.toolName,
                        argsSummary = result.toolCallId,
                        isSuccess = result.success,
                        resultSummary = if (result.success) result.result else result.error
                    )
                )
            )
        }

        // 将工具结果追加到消息中，继续对话获取最终回复
        val messagesWithResults = allMessages + userMessage + messageAfterTools + toolMessages
        Log.d("ChatViewModel", "Sending ${toolMessages.size} tool messages to LLM, total messages: ${messagesWithResults.size}")

        return sendMessageWithTools(config, messagesWithResults, tools)
    }

    private fun getPermissionRationale(toolName: String): String {
        return when (toolName) {
            "set_alarm" -> "设置闹钟需要闹钟权限"
            "add_calendar_event" -> "添加日历事件需要日历权限"
            "send_sms" -> "发送短信需要短信权限"
            else -> "执行此工具需要相应权限"
        }
    }

    private fun buildToolDisplays(
        toolCalls: List<ToolCall>,
        results: List<ToolResult>
    ): List<ToolCallDisplay> {
        return toolCalls.map { call ->
            val result = results.find { it.toolCallId == call.id }
            ToolCallDisplay(
                name = call.name,
                argsSummary = summarizeArgs(call.arguments),
                isRunning = result == null,
                isSuccess = result?.success,
                resultSummary = result?.result
            )
        }
    }

    private fun summarizeArgs(argsJson: String): String {
        return try {
            val map: Map<String, Any> = gson.fromJson(argsJson, object : com.google.gson.reflect.TypeToken<Map<String, Any>>() {}.type)
            map.entries.joinToString(", ") { "${it.key}: ${it.value}" }
        } catch (e: Exception) {
            argsJson.take(50)
        }
    }

    private fun updateLastAssistantMessage(message: ChatMessage) {
        val messages = _uiState.value.messages.toMutableList()
        for (i in messages.indices.reversed()) {
            if (messages[i].role == ROLE_ASSISTANT) {
                messages[i] = message
                _uiState.value = _uiState.value.copy(messages = messages)
                return
            }
        }
    }

    private fun getRecentMessages(): List<ChatMessage> {
        val historyMessages = _uiState.value.messages.filter { !it.isLoading }
        return if (historyMessages.size > MAX_CONTEXT_MESSAGES) {
            historyMessages.takeLast(MAX_CONTEXT_MESSAGES)
        } else {
            historyMessages
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
        private val toolManager: ToolManager,
        private val sessionId: String? = null
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            return ChatViewModel(configManager, chatRepository, toolManager, sessionId) as T
        }
    }
}