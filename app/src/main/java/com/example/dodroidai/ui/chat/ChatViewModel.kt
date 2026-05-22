package com.example.dodroidai.ui.chat

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.config.AIConfigManager
import com.example.dodroidai.ai.model.ChatMessage
import com.example.dodroidai.ai.model.ChatMessage.Companion.LOADING_THINKING
import com.example.dodroidai.ai.model.ChatMessage.Companion.ROLE_ASSISTANT
import com.example.dodroidai.ai.model.ChatMessage.Companion.ROLE_USER
import com.example.dodroidai.ai.model.ChatMessage.Companion.ROLE_TOOL
import com.example.dodroidai.ai.model.StreamingCallback
import com.example.dodroidai.ai.streaming.StreamingChatClient
import com.example.dodroidai.ai.tools.RiskLevel
import com.example.dodroidai.ai.tools.Tool
import com.example.dodroidai.ai.tools.ToolCall
import com.example.dodroidai.ai.tools.ToolCallDisplay
import com.example.dodroidai.ai.tools.ToolDefinition
import com.example.dodroidai.ai.tools.ToolExecutor
import com.example.dodroidai.ai.tools.ToolResult
import com.example.dodroidai.data.model.ChatSession
import com.example.dodroidai.data.repository.ChatRepository
import com.google.gson.annotations.SerializedName
import com.google.gson.reflect.TypeToken
import com.example.dodroidai.util.GsonUtil
import okhttp3.OkHttpClient
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * 聊天列表 UI 状态
 */
data class ChatUiState(
    @SerializedName("messages")
    val messages: List<ChatMessage> = emptyList(),
    @SerializedName("isLoading")
    val isLoading: Boolean = false,
    @SerializedName("error")
    val error: String? = null,
    @SerializedName("sessionId")
    val sessionId: String? = null,
    @SerializedName("sessionName")
    val sessionName: String? = null
)

/**
 * 流式响应结果
 */
private data class StreamingResult(
    val content: String,
    val reasoningContent: String?,
    val toolCalls: List<ToolCall>
)

/**
 * 工具调用确认请求
 */
data class ToolConfirmationRequest(
    @SerializedName("toolCall")
    val toolCall: ToolCall,
    @SerializedName("toolName")
    val toolName: String,
    @SerializedName("argsSummary")
    val argsSummary: String,
    @SerializedName("riskLevel")
    val riskLevel: RiskLevel
)

/**
 * 工具权限请求
 */
data class ToolPermissionRequest(
    @SerializedName("toolCall")
    val toolCall: ToolCall,
    @SerializedName("toolName")
    val toolName: String,
    @SerializedName("permission")
    val permission: String,
    @SerializedName("rationale")
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
    private val toolExecutor: ToolExecutor,
    private val sessionId: String? = null,
    private val fragment: androidx.fragment.app.Fragment? = null
) : ViewModel() {

    companion object {
        private const val TAG = "ChatViewModel"
        private const val MAX_CONTEXT_MESSAGES = 20
        private const val MAX_TOOL_CALL_DEPTH = 5
    }

    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    /**
     * 流式消息位置的 Flow，用于通知 Fragment 直接更新 ViewHolder
     */
    private val _streamingMessagePosition = MutableStateFlow(-1)
    val streamingMessagePosition: StateFlow<Int> = _streamingMessagePosition.asStateFlow()

    /**
     * 流式内容更新 Flow
     */
    private val _streamingContentUpdate = MutableStateFlow<Pair<Int, String>?>(null)
    val streamingContentUpdate: StateFlow<Pair<Int, String>?> = _streamingContentUpdate.asStateFlow()

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

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30L, java.util.concurrent.TimeUnit.SECONDS)
        .readTimeout(120L, java.util.concurrent.TimeUnit.SECONDS)
        .build()

    private val streamingClient = StreamingChatClient(httpClient)

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
                // 获取历史消息（已包含新添加的 userMessage）
                val allMessages = getRecentMessages()
                val tools = toolExecutor.getToolDefinitions()

                // 使用流式发送
                Log.i(TAG, "sendMessageStreaming messages count: ${allMessages.size}")
                Log.i(TAG, "sendMessageStreaming messages: ${allMessages.map { it.role to it.content.take(30) }}")
                var streamingResult = sendMessageStreaming(config, allMessages, tools)

                // 处理工具调用循环
                var toolCallDepth = 0
                var currentToolCalls = streamingResult.toolCalls
                while (currentToolCalls.isNotEmpty() && toolCallDepth < MAX_TOOL_CALL_DEPTH) {
                    toolCallDepth++
                    // 执行工具调用
                    val toolResults = executeToolCalls(currentToolCalls, fragment!!)
                    // 添加工具结果消息
                    val toolMessages = buildToolMessages(currentToolCalls, toolResults)
                    val messagesWithResults = allMessages + toolMessages
                    Log.i(TAG, "Second request messages count: ${messagesWithResults.size}")
                    Log.i(TAG, "Second request messages: ${messagesWithResults.map { it.role to it.content.take(30) }}")
                    // 继续流式请求
                    val nextResult = sendMessageStreaming(config, messagesWithResults, tools)
                    currentToolCalls = nextResult.toolCalls
                    streamingResult = nextResult
                }

                loadingJob.cancel()

                Log.d("ChatViewModel", "Final response: content='${streamingResult.content}', toolCalls=${streamingResult.toolCalls.size}")
                val toolDisplays = buildToolDisplays(streamingResult.toolCalls, emptyList())
                val assistantMessage = ChatMessage(
                    role = ROLE_ASSISTANT,
                    content = streamingResult.content,
                    toolCalls = toolDisplays,
                    reasoningContent = streamingResult.reasoningContent
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

    /**
     * 流式发送消息并返回结果
     */
    private suspend fun sendMessageStreaming(
        config: AIConfig,
        messages: List<ChatMessage>,
        tools: List<ToolDefinition>
    ): StreamingResult {
        val result = CompletableDeferred<StreamingResult>()

        streamingClient.stream(config, messages, tools, object : StreamingCallback {
            private val contentBuilder = StringBuilder()
            private val reasoningBuilder = StringBuilder()
            private val toolCalls = mutableListOf<ToolCall>()

            override fun onContentDelta(content: String) {
                // 更新 UI 显示增量内容（不更新 messages，只通过 streamingContentUpdate 更新 ViewHolder）
                updateLoadingMessageContent(content)
            }

            override fun onReasoningDelta(content: String) {
                // 更新思考内容（不更新 messages）
                updateLoadingMessageReasoning(content)
            }

            override fun onToolCallDelta(toolCallId: String, name: String, argumentsDelta: String) {
                // 工具调用增量
            }

            override fun onToolCallComplete(toolCallId: String, name: String, arguments: String) {
                toolCalls.add(ToolCall(id = toolCallId, name = name, arguments = arguments))
            }

            override fun onComplete(fullContent: String, reasoningContent: String?, toolCalls: List<ToolCall>) {
                result.complete(StreamingResult(
                    content = fullContent,
                    reasoningContent = reasoningContent,
                    toolCalls = toolCalls
                ))
            }

            override fun onError(error: Throwable) {
                result.completeExceptionally(error)
            }
        })

        return result.await()
    }

    /**
     * 执行工具调用
     */
    private suspend fun executeToolCalls(
        toolCalls: List<ToolCall>,
        fragment: androidx.fragment.app.Fragment
    ): List<ToolResult> {
        return toolCalls.map { toolCall ->
            val tool = toolExecutor.getTool(toolCall.name)
            if (tool == null) {
                ToolResult(
                    toolCallId = toolCall.id,
                    toolName = toolCall.name,
                    success = false,
                    result = "",
                    error = "未知工具: ${toolCall.name}"
                )
            } else if (!tool.hasPermissions(toolExecutor.context)) {
                // 请求权限
                val granted = requestToolPermission(tool, fragment)
                if (granted) {
                    toolExecutor.execute(toolCall)
                } else {
                    ToolResult(
                        toolCallId = toolCall.id,
                        toolName = toolCall.name,
                        success = false,
                        result = "",
                        error = "权限被拒绝"
                    )
                }
            } else {
                toolExecutor.execute(toolCall)
            }
        }
    }

    /**
     * 请求工具权限
     */
    private suspend fun requestToolPermission(tool: Tool, fragment: androidx.fragment.app.Fragment): Boolean {
        val deferred = CompletableDeferred<Boolean>()
        tool.requestPermissions(fragment.requireActivity()) { granted ->
            deferred.complete(granted)
        }
        return deferred.await()
    }

    /**
     * 检查并请求工具权限
     */
    private fun checkAndRequestPermissions(toolCalls: List<ToolCall>, activity: android.app.Activity): List<ToolCall> {
        return toolCalls.filter { toolCall ->
            val tool = toolExecutor.getTool(toolCall.name)
            tool != null && !tool.hasPermissions(toolExecutor.context)
        }
    }

    /**
     * 构建工具消息列表
     */
    private fun buildToolMessages(
        toolCalls: List<ToolCall>,
        results: List<ToolResult>
    ): List<ChatMessage> {
        return results.map { result ->
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
    }

    /**
     * 更新 loading 消息的内容
     */
    private fun updateLoadingMessageContent(content: String) {
        val messages = _uiState.value.messages.toMutableList()
        for (i in messages.indices.reversed()) {
            if (messages[i].role == ROLE_ASSISTANT && messages[i].isLoading) {
                messages[i] = messages[i].copy(content = content)
                _uiState.value = _uiState.value.copy(messages = messages)
                _streamingContentUpdate.value = Pair(i, content)
                break
            }
        }
    }

    /**
     * 更新 loading 消息的思考内容
     */
    private fun updateLoadingMessageReasoning(reasoning: String) {
        val messages = _uiState.value.messages.toMutableList()
        for (i in messages.indices.reversed()) {
            if (messages[i].role == ROLE_ASSISTANT && messages[i].isLoading) {
                messages[i] = messages[i].copy(reasoningContent = reasoning)
                _uiState.value = _uiState.value.copy(messages = messages)
                break
            }
        }
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
            val map = GsonUtil.fromJsonWithTypeToken(argsJson, object : TypeToken<Map<String, Any>>() {})
            map?.entries?.joinToString(", ") { "${it.key}: ${it.value}" } ?: argsJson.take(50)
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
            ChatSession(
                id = UUID.randomUUID().toString(),
                title = firstMessage.take(20),
                messages = messages,
                createdAt = System.currentTimeMillis(),
                updatedAt = System.currentTimeMillis()
            )
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
        private val toolExecutor: ToolExecutor,
        private val sessionId: String? = null,
        private val fragment: androidx.fragment.app.Fragment? = null
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            return ChatViewModel(configManager, chatRepository, toolExecutor, sessionId, fragment) as T
        }
    }
}