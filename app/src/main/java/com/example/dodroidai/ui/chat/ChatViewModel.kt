package com.example.dodroidai.ui.chat

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.dodroidai.ai.attachments.AttachmentEncoder
import com.example.dodroidai.ai.attachments.AttachmentLimits
import com.example.dodroidai.ai.attachments.EncodedAttachment
import com.example.dodroidai.ai.attachments.PlaceholderReason
import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.config.AppConfigManager
import com.example.dodroidai.ai.model.ApiFormat
import com.example.dodroidai.ai.model.ApiRequestFactory
import com.example.dodroidai.ai.model.ChatAttachment
import com.example.dodroidai.ai.model.ChatErrorParser
import com.example.dodroidai.ai.model.ChatMessage
import com.example.dodroidai.ai.model.ChatMessage.Companion.LOADING_THINKING
import com.example.dodroidai.ai.model.ChatMessage.Companion.ROLE_ASSISTANT
import com.example.dodroidai.ai.model.ChatMessage.Companion.ROLE_USER
import com.example.dodroidai.ai.model.ChatMessage.Companion.ROLE_TOOL
import com.example.dodroidai.ai.model.StreamingCallback
import com.example.dodroidai.ai.streaming.StreamingChatClient
import com.example.dodroidai.ai.tools.RiskLevel
import com.example.dodroidai.ai.tools.ToolCall
import com.example.dodroidai.ai.tools.ToolCallDisplay
import com.example.dodroidai.ai.tools.ToolDefinition
import com.example.dodroidai.ai.tools.ToolExecutor
import com.example.dodroidai.ai.tools.ToolResult
import com.example.dodroidai.ui.common.CustomDialog
import com.example.dodroidai.data.local.PermissionPolicyStore
import com.example.dodroidai.data.model.ChatSession
import com.example.dodroidai.data.repository.ChatRepository
import com.example.dodroidai.data.repository.MemoryRepository
import com.example.dodroidai.data.repository.RequestTraceRepository
import com.example.dodroidai.data.repository.ToolAuditRepository
import com.google.gson.annotations.SerializedName
import com.google.gson.reflect.TypeToken
import com.example.dodroidai.util.GsonUtil
import okhttp3.OkHttpClient
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.currentCoroutineContext
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
    @SerializedName("messages")
    val messages: List<ChatMessage> = emptyList(),
    @SerializedName("isLoading")
    val isLoading: Boolean = false,
    @SerializedName("error")
    val error: String? = null,
    @SerializedName("sessionId")
    val sessionId: String? = null,
    @SerializedName("sessionName")
    val sessionName: String? = null,
    val hasMoreMessages: Boolean = false,
    val isLoadingMoreMessages: Boolean = false,
    val loadedFromOrderIndex: Int = 0
)

/**
 * 流式响应结果
 */
private data class StreamingResult(
    val content: String,
    val reasoningContent: String?,
    val toolCalls: List<ToolCall>,
    val reasoningElapsedSeconds: Int = 0,
    val toolDisplays: List<ToolCallDisplay> = emptyList()
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
    @SerializedName("permissions")
    val permissions: List<String>,
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
    private val chatRepository: ChatRepository,
    private val toolExecutor: ToolExecutor,
    private val appContext: Context,
    private val sessionId: String? = null,
    private val fragment: androidx.fragment.app.Fragment? = null
) : ViewModel() {

    companion object {
        private const val TAG = "ChatViewModel"
        private const val MAX_CONTEXT_MESSAGES = 20
        private const val PAGE_SIZE = 60
        private const val MAX_TOOL_CALL_DEPTH = 5
        private const val PERMISSION_TIMEOUT_MS = 60_000L
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
     * AI 回复完成 Flow（用于 TTS 朗读）
     */
    private val _responseComplete = MutableSharedFlow<String>()
    val responseComplete: SharedFlow<String> = _responseComplete.asSharedFlow()

    /**
     * 附件处理警告（Toast 展示）
     */
    private val _attachmentWarning = MutableSharedFlow<String>()
    val attachmentWarning: SharedFlow<String> = _attachmentWarning.asSharedFlow()

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

    /**
     * 被拒绝权限的工具调用ID
     */

    /**
     * 是否正在等待权限授予
     */
    private var pendingPermissionDeferred: CompletableDeferred<Boolean>? = null

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(15L, java.util.concurrent.TimeUnit.SECONDS)
        .writeTimeout(30L, java.util.concurrent.TimeUnit.SECONDS)
        .readTimeout(120L, java.util.concurrent.TimeUnit.SECONDS)
        .build()

    private val streamingClient = StreamingChatClient(httpClient)

    /** 思考过程开始时间（用于显示“已深度思考（用时 X 秒）”） */
    private var reasoningStartedAt = 0L

    /** 当前发送协程，用于停止生成 */
    private var sendJob: Job? = null

    /** 最近一次失败请求，用于重试 */
    private var lastFailedRequest: FailedRequest? = null

    private data class FailedRequest(
        val content: String,
        val attachments: List<ChatAttachment>,
        val webSearchEnabled: Boolean
    )

    /** OpenCode Go 要求稳定会话 ID（x-opencode-session）；其他 OpenAI 兼容网关会忽略。 */
    private val openCodeSessionId = "ses_" + UUID.randomUUID().toString().replace("-", "")

    private val attachmentEncoder = AttachmentEncoder(appContext)
    private val memoryRepository = MemoryRepository(appContext)

    init {
        if (sessionId != null) {
            loadSession(sessionId)
        }
    }

    private fun loadSession(sessionId: String) {
        viewModelScope.launch {
            val meta = chatRepository.findSessionMeta(sessionId)
            val total = chatRepository.messageCount(sessionId)
            val from = (total - PAGE_SIZE).coerceAtLeast(0)
            val recent = chatRepository.recentMessages(sessionId, PAGE_SIZE)
            _uiState.value = _uiState.value.copy(
                messages = recent,
                sessionId = sessionId,
                sessionName = meta?.title,
                hasMoreMessages = from > 0,
                loadedFromOrderIndex = from
            )
        }
    }

    /**
     * 上滑加载更早的消息
     */
    fun loadOlderMessages() {
        val state = _uiState.value
        val sid = state.sessionId ?: return
        if (state.isLoadingMoreMessages || !state.hasMoreMessages) return
        _uiState.value = state.copy(isLoadingMoreMessages = true)
        viewModelScope.launch {
            val before = _uiState.value.loadedFromOrderIndex
            val older = chatRepository.messagesBefore(sid, before, PAGE_SIZE)
            val newFrom = (before - older.size).coerceAtLeast(0)
            _uiState.value = _uiState.value.copy(
                messages = older + _uiState.value.messages,
                hasMoreMessages = newFrom > 0 && older.isNotEmpty(),
                isLoadingMoreMessages = false,
                loadedFromOrderIndex = newFrom
            )
        }
    }

    fun sendMessage(
        content: String,
        attachments: List<ChatAttachment> = emptyList(),
        webSearchEnabled: Boolean = false
    ) {
        if (content.isBlank() && attachments.isEmpty()) return

        sendJob?.cancel()
        sendJob = viewModelScope.launch {
            lastFailedRequest = null
            reasoningStartedAt = 0L

            val userMessage = ChatMessage(
                role = ROLE_USER,
                content = content.trim(),
                attachments = if (attachments.isEmpty()) null else attachments
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

            val traceStartedAt = System.currentTimeMillis()
            var traceConfig: AIConfig? = null
            try {
                val config = getCurrentConfig()
                traceConfig = config
                // 获取历史消息（已包含新添加的 userMessage）
                val allMessages = getRecentMessages()
                // 根据设置决定是否启用 web_search 工具
                val tools = if (webSearchEnabled) {
                    toolExecutor.getToolDefinitions()
                } else {
                    toolExecutor.getToolDefinitions().filter { it.name != "web_search" }
                }

                // 附件处理阶段：编码图片/PDF/TXT
                val encoded: Map<Long, List<EncodedAttachment>> = if (attachments.isNotEmpty()) {
                    updateLoadingState(ChatMessage.LOADING_ATTACHMENTS)
                    val (result, warnings) = encodeAttachments(allMessages, config)
                    if (warnings.isNotEmpty()) {
                        _attachmentWarning.emit(warnings.take(3).joinToString("\n"))
                    }
                    result
                } else {
                    emptyMap()
                }

                // 附件处理完成，恢复为思考状态
                updateLoadingState(LOADING_THINKING)

                val currentAttachments = allMessages.lastOrNull { it.role == ROLE_USER }
                    ?.let { encoded[it.timestamp] }
                    .orEmpty()
                if (content.isBlank() &&
                    currentAttachments.isNotEmpty() &&
                    currentAttachments.all { it is EncodedAttachment.Placeholder }
                ) {
                    throw IllegalStateException("附件处理失败，没有可发送的内容")
                }
                if (allMessages.isEmpty()) {
                    throw IllegalStateException("没有可发送的内容")
                }

                val requestMessages = withMemoryContext(allMessages, content)
                Log.i(TAG, "sendMessageStreaming messages count: ${requestMessages.size}")
                val streamingResult = runToolLoop(config, requestMessages, encoded, tools)

                loadingJob.cancel()

                Log.d(TAG, "Final response: length=${streamingResult.content.length}, toolCalls=${streamingResult.toolCalls.size}")
                val toolDisplays = streamingResult.toolDisplays
                val assistantMessage = ChatMessage(
                    role = ROLE_ASSISTANT,
                    content = streamingResult.content,
                    toolCalls = toolDisplays,
                    reasoningContent = streamingResult.reasoningContent,
                    reasoningElapsedSeconds = streamingResult.reasoningElapsedSeconds
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
                recordTrace(traceConfig, traceStartedAt, true, null, streamingResult.toolCalls.size)
                _responseComplete.emit(assistantMessage.content)
            } catch (e: CancellationException) {
                // 用户主动停止或新请求覆盖；stopGeneration 已处理 UI
                loadingJob.cancel()
                return@launch
            } catch (e: Exception) {
                loadingJob.cancel()
                recordTrace(traceConfig, traceStartedAt, false, e.javaClass.simpleName, 0)
                Log.e(TAG, "sendMessage 失败: ${e.javaClass.simpleName}")

                val chatError = ChatErrorParser.parse(e)
                lastFailedRequest = FailedRequest(content, attachments, webSearchEnabled)
                val detail = e.message?.take(200)
                val errorText = buildString {
                    append(chatError.message)
                    if (!detail.isNullOrBlank()) {
                        append("\n\n").append(detail)
                    }
                }
                val hint = if (attachments.any { it.isImage } && errorText.contains("400")) {
                    "\n\n提示：当前服务商可能不支持图片输入，可在 AI 配置中关闭图片支持后重试。"
                } else ""

                val currentMessages = _uiState.value.messages.toMutableList()
                val lastIndex = currentMessages.lastIndex
                if (lastIndex >= 0 && currentMessages[lastIndex].isLoading) {
                    currentMessages[lastIndex] = ChatMessage(
                        role = ROLE_ASSISTANT,
                        content = errorText + hint,
                        isLoading = false,
                        isError = true
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
     * 停止当前生成：取消请求与协程，保留已生成内容。
     */
    fun stopGeneration() {
        if (!_uiState.value.isLoading) return

        streamingClient.cancel()
        sendJob?.cancel()
        sendJob = null
        lastFailedRequest = null

        val messages = _uiState.value.messages.toMutableList()
        val lastIndex = messages.lastIndex
        if (lastIndex >= 0 && messages[lastIndex].isLoading) {
            val current = messages[lastIndex]
            messages[lastIndex] = current.copy(
                content = current.content.ifBlank { "已停止生成" },
                isLoading = false,
                loadingState = null
            )
        }
        _uiState.value = _uiState.value.copy(messages = messages, isLoading = false)
        viewModelScope.launch { saveCurrentSession() }
    }

    /**
     * 重试最近一次失败的请求：移除失败消息与原用户消息后重新发送。
     */
    /**
     * 删除最后一条 assistant 回复及其对应的 user 消息，然后重新发送。
     * 仅当最后一条消息是 assistant 且当前不在生成中时有效。
     */
    fun retryLastAssistant() {
        if (_uiState.value.isLoading) return
        val messages = _uiState.value.messages.toMutableList()
        val assistantIndex = messages.indexOfLast { it.role == ROLE_ASSISTANT && !it.isLoading }
        if (assistantIndex < 0) return
        val userIndex = (assistantIndex - 1 downTo 0).firstOrNull {
            messages[it].role == ROLE_USER
        } ?: return

        val user = messages[userIndex]
        messages.subList(userIndex, messages.size).clear()
        _uiState.value = _uiState.value.copy(messages = messages, error = null)
        viewModelScope.launch { saveCurrentSession() }
        sendMessage(user.content, user.attachments.orEmpty(), webSearchEnabled = false)
    }

    fun retryLastMessage() {
        if (_uiState.value.isLoading) return
        val request = lastFailedRequest ?: return

        val messages = _uiState.value.messages.toMutableList()
        val errorIndex = messages.indexOfLast {
            it.role == ROLE_ASSISTANT && it.isError == true
        }
        if (errorIndex >= 0) messages.removeAt(errorIndex)
        val userIndex = messages.indexOfLast { it.role == ROLE_USER }
        if (userIndex >= 0) messages.removeAt(userIndex)

        _uiState.value = _uiState.value.copy(messages = messages, error = null)
        sendMessage(request.content, request.attachments, request.webSearchEnabled)
    }

    /**
     * 执行流式请求与工具调用循环，返回最终结果。
     */
    private suspend fun runToolLoop(
        config: AIConfig,
        messages: List<ChatMessage>,
        encoded: Map<Long, List<EncodedAttachment>>,
        tools: List<ToolDefinition>
    ): StreamingResult {
        var currentMessages = messages
        var streamingResult = sendMessageStreaming(config, currentMessages, encoded, tools)
        var toolCallDepth = 0
        var currentToolCalls = streamingResult.toolCalls
        val allDisplays = mutableListOf<ToolCallDisplay>()

        while (currentToolCalls.isNotEmpty() && toolCallDepth < MAX_TOOL_CALL_DEPTH) {
            currentCoroutineContext().ensureActive()
            toolCallDepth++
            val currentFragment = fragment
            if (currentFragment == null) {
                Log.w(TAG, "Fragment 不可用,跳过工具调用")
                break
            }
            val toolResults = executeToolCalls(currentToolCalls, currentFragment)
            allDisplays.addAll(buildToolDisplays(currentToolCalls, toolResults))
            val toolMessages = buildToolMessages(currentToolCalls, toolResults)

            // OpenAI 要求 tool 消息之前有对应的 assistant tool_calls 消息；
            // Anthropic 分支保持原有行为，只追加 tool_result。
            val assistantToolMessage = if (config.apiFormat == ApiFormat.OPENAI_CHAT_COMPLETIONS) {
                ChatMessage(
                    role = ROLE_ASSISTANT,
                    content = streamingResult.content,
                    toolCallPayloads = streamingResult.toolCalls
                )
            } else {
                null
            }
            currentMessages = currentMessages + listOfNotNull(assistantToolMessage) + toolMessages

            Log.i(TAG, "Second request messages count: ${currentMessages.size}")
            val nextResult = sendMessageStreaming(config, currentMessages, encoded, tools)
            currentToolCalls = nextResult.toolCalls
            streamingResult = nextResult
        }
        return streamingResult.copy(toolDisplays = allDisplays)
    }

    /**
     * 编码参与本次请求的附件。
     *
     * 只有最近若干条 user 消息会携带附件；更早的附件、超出预算的附件会降级为占位文本。
     */
    private suspend fun encodeAttachments(
        messages: List<ChatMessage>,
        config: AIConfig
    ): Pair<Map<Long, List<EncodedAttachment>>, List<String>> = withContext(Dispatchers.IO) {
        val encoded = mutableMapOf<Long, List<EncodedAttachment>>()
        val warnings = mutableListOf<String>()
        val currentUserTimestamp = messages.lastOrNull { it.role == ROLE_USER }?.timestamp
        val recentUserTimestamps = messages.asReversed()
            .filter { it.role == ROLE_USER }
            .take(AttachmentLimits.ATTACHMENT_HISTORY_USER_MESSAGES)
            .map { it.timestamp }
            .toSet()
        val visionEnabled = config.supportsVision ?: true
        var remainingBytes = AttachmentLimits.MAX_REQUEST_ATTACHMENT_BYTES.toLong()

        // 从最新消息开始处理，保证当前消息优先占用预算
        for (message in messages.asReversed()) {
            val attachments = message.attachments.orEmpty()
            if (attachments.isEmpty()) continue

            val results = attachments.map { attachment ->
                when {
                    attachment.isImage && !visionEnabled ->
                        EncodedAttachment.Placeholder(attachment.name, PlaceholderReason.VISION_DISABLED)
                    message.timestamp !in recentUserTimestamps ->
                        EncodedAttachment.Placeholder(attachment.name, PlaceholderReason.HISTORY_LIMIT)
                    else -> {
                        val result = attachmentEncoder.encode(attachment)
                        if (result.rawBytes > 0 && result.rawBytes > remainingBytes) {
                            EncodedAttachment.Placeholder(attachment.name, PlaceholderReason.BUDGET_EXCEEDED)
                        } else {
                            remainingBytes -= result.rawBytes
                            result
                        }
                    }
                }
            }
            encoded[message.timestamp] = results

            if (message.timestamp == currentUserTimestamp) {
                results.filterIsInstance<EncodedAttachment.Placeholder>()
                    .forEach { warnings.add(attachmentWarningText(it)) }
            }
        }
        encoded to warnings
    }

    private fun updateLoadingState(state: String) {
        val messages = _uiState.value.messages.toMutableList()
        val lastIndex = messages.lastIndex
        if (lastIndex >= 0 && messages[lastIndex].isLoading) {
            messages[lastIndex] = messages[lastIndex].copy(loadingState = state)
            _uiState.value = _uiState.value.copy(messages = messages)
        }
    }

    private fun attachmentWarningText(placeholder: EncodedAttachment.Placeholder): String {
        return when (placeholder.reason) {
            PlaceholderReason.VISION_DISABLED -> "「${placeholder.label}」未发送：当前配置已关闭图片输入"
            PlaceholderReason.BUDGET_EXCEEDED -> "「${placeholder.label}」未发送：本次请求附件总量超限"
            PlaceholderReason.HISTORY_LIMIT -> "「${placeholder.label}」未发送：仅最近几条消息的附件会随请求发送"
            PlaceholderReason.NO_TEXT -> "「${placeholder.label}」未提取到文本，可能是扫描件"
            PlaceholderReason.TOO_LARGE -> "「${placeholder.label}」文件过大"
            PlaceholderReason.UNSUPPORTED_FORMAT -> "「${placeholder.label}」格式不支持"
            PlaceholderReason.UNREADABLE -> "「${placeholder.label}」读取失败"
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
        when (result) {
            is ToolPermissionResult.Granted -> pendingPermissionDeferred?.complete(true)
            is ToolPermissionResult.Denied -> pendingPermissionDeferred?.complete(false)
        }
    }

    /**
     * 流式发送消息并返回结果
     */
    private suspend fun sendMessageStreaming(
        config: AIConfig,
        messages: List<ChatMessage>,
        encoded: Map<Long, List<EncodedAttachment>>,
        tools: List<ToolDefinition>
    ): StreamingResult {
        val result = CompletableDeferred<StreamingResult>()
        val prepared = ApiRequestFactory.build(
            config = config,
            messages = messages,
            encoded = encoded,
            tools = tools,
            sessionId = openCodeSessionId
        )

        streamingClient.stream(prepared, object : StreamingCallback {
            private val contentBuilder = StringBuilder()
            private val reasoningBuilder = StringBuilder()
            private val toolCalls = mutableListOf<ToolCall>()

            override fun onContentDelta(content: String) {
                // 更新 UI 显示增量内容（不更新 messages，只通过 streamingContentUpdate 更新 ViewHolder）
                updateLoadingMessageContent(content)
            }

            override fun onReasoningDelta(content: String) {
                if (reasoningStartedAt == 0L) {
                    reasoningStartedAt = System.currentTimeMillis()
                }
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
                val elapsed = if (reasoningStartedAt > 0) {
                    ((System.currentTimeMillis() - reasoningStartedAt) / 1000).toInt()
                } else {
                    0
                }
                result.complete(StreamingResult(
                    content = fullContent,
                    reasoningContent = reasoningContent,
                    toolCalls = toolCalls,
                    reasoningElapsedSeconds = elapsed
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
        val results = toolCalls.map { toolCall ->
            when {
                !toolExecutor.hasTool(toolCall.name) -> ToolResult(
                    toolCallId = toolCall.id,
                    toolName = toolCall.name,
                    success = false,
                    result = "",
                    error = "未知工具: ${toolCall.name}"
                )

                toolExecutor.getToolRiskLevel(toolCall.name) == RiskLevel.HIGH &&
                    !requestToolConfirmation(toolCall, fragment) -> ToolResult(
                    toolCallId = toolCall.id,
                    toolName = toolCall.name,
                    success = false,
                    result = "",
                    error = "用户取消"
                )

                !toolExecutor.hasPermissions(toolCall.name) &&
                    !requestToolPermission(toolCall) -> ToolResult(
                    toolCallId = toolCall.id,
                    toolName = toolCall.name,
                    success = false,
                    result = "",
                    error = "权限被拒绝"
                )

                else -> toolExecutor.execute(toolCall)
            }
        }

        val auditRepository = ToolAuditRepository(appContext)
        results.forEachIndexed { index, result ->
            val call = toolCalls.getOrNull(index) ?: return@forEachIndexed
            try {
                auditRepository.record(call, result)
            } catch (e: Exception) {
                Log.w(TAG, "写入工具审计失败: ${e.javaClass.simpleName}")
            }
        }
        return results
    }

    /**
     * 请求工具权限
     */
    private suspend fun requestToolPermission(toolCall: ToolCall): Boolean {
        val permissions = toolExecutor.getRequiredPermissions(toolCall.name)
        if (permissions.isEmpty()) return true

        // 用户拒绝过且系统权限仍缺失：不再反复弹窗，直接失败
        if (permissions.all { PermissionPolicyStore.isDenied(appContext, toolCall.name, it) }) {
            Log.i(TAG, "权限此前被拒绝: ${toolCall.name}")
            return false
        }

        val deferred = CompletableDeferred<Boolean>()
        pendingPermissionDeferred = deferred
        _toolPermission.emit(
            ToolPermissionRequest(
                toolCall = toolCall,
                toolName = toolCall.name,
                permissions = permissions,
                rationale = "该工具需要以下权限：${permissions.joinToString()}"
            )
        )
        val granted = try {
            withTimeout(PERMISSION_TIMEOUT_MS) { deferred.await() }
        } catch (e: TimeoutCancellationException) {
            Log.w(TAG, "权限请求超时")
            false
        } finally {
            pendingPermissionDeferred = null
        }
        permissions.forEach { permission ->
            if (granted) {
                PermissionPolicyStore.clearDenied(appContext, toolCall.name, permission)
            } else {
                PermissionPolicyStore.markDenied(appContext, toolCall.name, permission)
            }
        }
        return granted
    }

    /**
     * 请求高风险工具确认
     */
    private suspend fun requestToolConfirmation(toolCall: ToolCall, fragment: androidx.fragment.app.Fragment): Boolean {
        val deferred = CompletableDeferred<Boolean>()
        fragment.activity?.runOnUiThread {
            val dialog = CustomDialog.Builder(fragment.requireContext())
                .setTitle("确认执行")
                .setDescription("即将执行【${toolCall.name}】工具，此操作风险较高，是否继续？")
                .setButtons(
                    CustomDialog.ButtonInfo("确认", onClick = {
                        Log.i(TAG, "Confirm button clicked")
                        if (!deferred.isCompleted) {
                            deferred.complete(true)
                        }
                    }),
                    CustomDialog.ButtonInfo("取消", onClick = {
                        Log.i(TAG, "Cancel button clicked")
                        if (!deferred.isCompleted) {
                            deferred.complete(false)
                        }
                    })
                )
                .setCancelable(true)
                .build()
            dialog.window?.setType(android.view.WindowManager.LayoutParams.TYPE_APPLICATION_PANEL)
            dialog.show()
            Log.i(TAG, "Dialog shown")
        }
        Log.i(TAG, "Waiting for confirmation...")
        return deferred.await()
    }

    /**
     * 构建工具消息列表
     */
    private fun buildToolMessages(
        toolCalls: List<ToolCall>,
        results: List<ToolResult>
    ): List<ChatMessage> {
        return results.mapIndexed { index, result ->
            val toolCall = toolCalls.getOrNull(index)
            ChatMessage(
                role = ROLE_TOOL,
                content = if (result.success) result.result else "Error: ${result.error}",
                toolCallId = result.toolCallId,
                toolCalls = listOf(
                    ToolCallDisplay(
                        name = result.toolName,
                        argsSummary = toolCall?.id ?: result.toolCallId,
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

    private suspend fun recordTrace(
        config: AIConfig?,
        startedAt: Long,
        success: Boolean,
        error: String?,
        toolCallCount: Int
    ) {
        withContext(Dispatchers.IO) {
            RequestTraceRepository(appContext).record(
                config = config,
                sessionId = sessionId,
                startedAt = startedAt,
                durationMs = System.currentTimeMillis() - startedAt,
                success = success,
                error = error,
                toolCallCount = toolCallCount,
                messageCount = _uiState.value.messages.size
            )
        }
    }

    /**
     * 把长期记忆作为 system 消息注入请求（只影响请求，不写入 UI 消息列表）。
     */
    private suspend fun withMemoryContext(
        messages: List<ChatMessage>,
        query: String
    ): List<ChatMessage> {
        val facts = try {
            memoryRepository.findRelevant(query)
        } catch (e: Exception) {
            emptyList()
        }
        if (facts.isEmpty()) return messages
        val text = facts.joinToString("\n") { "- ${it.key}: ${it.value}" }.take(1500)
        val memoryMessage = ChatMessage(
            role = ChatMessage.ROLE_SYSTEM,
            content = "已知用户信息（长期记忆）：\n$text"
        )
        return listOf(memoryMessage) + messages
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
                resultSummary = result?.result,
                argsFull = call.arguments.take(2000)
            )
        }
    }

    private fun summarizeArgs(argsJson: String): String {
        return try {
            val map = GsonUtil.fromJsonWithTypeToken(
                argsJson,
                @Suppress("UNCHECKED_CAST")
                TypeToken.getParameterized(
                    Map::class.java, String::class.java, Any::class.java
                ) as TypeToken<Map<String, Any>>
            )
            map?.entries?.joinToString(", ") { "${it.key}: ${it.value}" } ?: argsJson.take(50)
        } catch (e: Exception) {
            Log.w(TAG, "summarizeArgs 解析失败", e)
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
            chatRepository.findSessionMeta(currentState.sessionId)
        } else null

        val session = if (existingSession != null) {
            existingSession.copy(
                messages = messages,
                title = if (existingSession.title.isBlank()) sessionTitle(messages) else existingSession.title,
                updatedAt = System.currentTimeMillis()
            )
        } else {
            ChatSession(
                id = UUID.randomUUID().toString(),
                title = sessionTitle(messages),
                messages = messages,
                createdAt = System.currentTimeMillis(),
                updatedAt = System.currentTimeMillis()
            )
        }
        chatRepository.replaceSessionFrom(session, messages, currentState.loadedFromOrderIndex)
        _uiState.value = _uiState.value.copy(
            sessionId = session.id,
            sessionName = session.title
        )
    }

    private suspend fun getCurrentConfig(): AIConfig {
        return AppConfigManager.configFlow.first()
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    private fun sessionTitle(messages: List<ChatMessage>): String {
        val first = messages.firstOrNull() ?: return "新对话"
        val text = first.content.trim()
        if (text.isNotEmpty()) return text.take(20)
        return first.attachments?.firstOrNull()?.name?.take(20) ?: "新对话"
    }

    class Factory(
        private val chatRepository: ChatRepository,
        private val toolExecutor: ToolExecutor,
        private val appContext: Context,
        private val sessionId: String? = null,
        private val fragment: androidx.fragment.app.Fragment? = null
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            return ChatViewModel(chatRepository, toolExecutor, appContext, sessionId, fragment) as T
        }
    }
}