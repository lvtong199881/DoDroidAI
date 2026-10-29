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
import com.example.dodroidai.ui.common.CustomDialog
import com.example.dodroidai.data.model.ChatSession
import com.example.dodroidai.data.repository.ChatRepository
import com.google.gson.annotations.SerializedName
import com.google.gson.reflect.TypeToken
import com.example.dodroidai.util.GsonUtil
import okhttp3.OkHttpClient
import kotlinx.coroutines.CompletableDeferred
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
    private val chatRepository: ChatRepository,
    private val toolExecutor: ToolExecutor,
    private val appContext: Context,
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

    /** OpenCode Go 要求稳定会话 ID（x-opencode-session）；其他 OpenAI 兼容网关会忽略。 */
    private val openCodeSessionId = "ses_" + UUID.randomUUID().toString().replace("-", "")

    private val attachmentEncoder = AttachmentEncoder(appContext)

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

    fun sendMessage(
        content: String,
        attachments: List<ChatAttachment> = emptyList(),
        webSearchEnabled: Boolean = false
    ) {
        if (content.isBlank() && attachments.isEmpty()) return

        viewModelScope.launch {
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

            try {
                val config = getCurrentConfig()
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

                Log.i(TAG, "sendMessageStreaming messages count: ${allMessages.size}")
                val streamingResult = runToolLoop(config, allMessages, encoded, tools)

                loadingJob.cancel()

                Log.d(TAG, "Final response: content='${streamingResult.content}', toolCalls=${streamingResult.toolCalls.size}")
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
                _responseComplete.emit(assistantMessage.content)
            } catch (e: Exception) {
                loadingJob.cancel()
                Log.e(TAG, "sendMessage 失败", e)

                val errorText = e.message ?: "Unknown error"
                val hint = if (attachments.any { it.isImage } && errorText.contains("400")) {
                    "\n\n提示：当前服务商可能不支持图片输入，可在 AI 配置中关闭图片支持后重试。"
                } else ""

                val currentMessages = _uiState.value.messages.toMutableList()
                val lastIndex = currentMessages.lastIndex
                if (lastIndex >= 0 && currentMessages[lastIndex].isLoading) {
                    currentMessages[lastIndex] = ChatMessage(
                        role = ROLE_ASSISTANT,
                        content = errorText + hint,
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

        while (currentToolCalls.isNotEmpty() && toolCallDepth < MAX_TOOL_CALL_DEPTH) {
            toolCallDepth++
            val currentFragment = fragment
            if (currentFragment == null) {
                Log.w(TAG, "Fragment 不可用,跳过工具调用")
                break
            }
            val toolResults = executeToolCalls(currentToolCalls, currentFragment)
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
        return streamingResult
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
            } else if (tool.riskLevel == RiskLevel.HIGH) {
                // 高风险工具需要用户确认
                val confirmed = requestToolConfirmation(tool, fragment)
                if (!confirmed) {
                    return@map ToolResult(
                        toolCallId = toolCall.id,
                        toolName = toolCall.name,
                        success = false,
                        result = "",
                        error = "用户取消"
                    )
                }
                // 继续执行权限检查和执行
                if (!tool.hasPermissions(toolExecutor.context)) {
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
     * 请求高风险工具确认
     */
    private suspend fun requestToolConfirmation(tool: Tool, fragment: androidx.fragment.app.Fragment): Boolean {
        val deferred = CompletableDeferred<Boolean>()
        fragment.activity?.runOnUiThread {
            val dialog = CustomDialog.Builder(fragment.requireContext())
                .setTitle("确认执行")
                .setDescription("即将执行【${tool.name}】工具，此操作风险较高，是否继续？")
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
        return results.mapIndexed { index, result ->
            val toolCall = toolCalls.getOrNull(index)
            ChatMessage(
                role = ROLE_TOOL,
                content = if (result.success) result.result else "Error: ${result.error}",
                // OpenAI 要求 tool_call_id 与 assistant tool_calls 的 id 完全一致；
                // 部分工具的 ToolResult 不携带 id，这里以原始 toolCall 为准。
                toolCallId = toolCall?.id ?: result.toolCallId,
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
            chatRepository.sessionsFlow.first().find { it.id == currentState.sessionId }
        } else null

        val session = if (existingSession != null) {
            existingSession.copy(
                messages = messages,
                title = if (existingSession.messages.isEmpty()) sessionTitle(messages) else existingSession.title,
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
        chatRepository.saveSession(session)
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