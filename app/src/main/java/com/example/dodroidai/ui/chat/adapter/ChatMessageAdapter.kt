package com.example.dodroidai.ui.chat.adapter

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.animation.ValueAnimator
import android.os.SystemClock
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.core.view.isVisible
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import coil3.load
import coil3.request.crossfade
import com.example.dodroidai.R
import com.example.dodroidai.ai.model.ChatAttachment
import com.example.dodroidai.ai.model.ChatMessage
import com.example.dodroidai.ai.model.ChatMessage.Companion.ROLE_ASSISTANT
import com.example.dodroidai.ai.model.ChatMessage.Companion.ROLE_USER
import com.google.android.material.color.MaterialColors
import io.noties.markwon.Markwon
import io.noties.markwon.ext.strikethrough.StrikethroughPlugin
import io.noties.markwon.ext.tables.TablePlugin

private const val RENDER_THROTTLE_MS = 200L

/**
 * 聊天消息适配器
 */
class ChatMessageAdapter(
    private val onReasoningToggle: (Int, Boolean) -> Unit,
    private val onRetryClick: ((ChatMessage) -> Unit)? = null,
    private val onSpeakClick: ((String) -> Unit)? = null
) : ListAdapter<ChatMessage, RecyclerView.ViewHolder>(DiffCallback()) {

    private val expandedStates = mutableMapOf<Long, Boolean>()

    /** 展开的工具调用详情（key = messageTimestamp_index） */
    private val expandedToolCalls = mutableSetOf<String>()

    /**
     * RecyclerView 引用，用于直接更新 ViewHolder
     */
    var recyclerView: RecyclerView? = null
        set(value) {
            field = value
        }

    override fun getItemViewType(position: Int): Int {
        return when (getItem(position).role) {
            ROLE_USER -> VIEW_TYPE_USER
            ROLE_ASSISTANT -> VIEW_TYPE_ASSISTANT
            else -> VIEW_TYPE_ASSISTANT
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        val inflater = LayoutInflater.from(parent.context)
        return when (viewType) {
            VIEW_TYPE_USER -> {
                val view = inflater.inflate(R.layout.item_message_user, parent, false)
                UserMessageViewHolder(view)
            }
            else -> {
                val view = inflater.inflate(R.layout.item_message_assistant, parent, false)
                AssistantMessageViewHolder(
                    view = view,
                    onReasoningToggle = { pos, expanded -> onReasoningToggle(pos, expanded) },
                    onRetryClick = onRetryClick
                )
            }
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        val message = getItem(position)
        // 只有「最后一条消息」且是 assistant 时才显示操作区（复制/重试）
        val showActions = position == itemCount - 1 && message.role == ROLE_ASSISTANT && !message.isLoading
        when (holder) {
            is UserMessageViewHolder -> holder.bind(message)
            is AssistantMessageViewHolder -> holder.bind(message, showActions)
        }
    }

    /**
     * 流式更新内容，直接更新 ViewHolder，不触发 submitList
     */
    fun updateStreamingContent(position: Int, content: String, reasoning: String?) {
        if (position < 0 || position >= itemCount) return

        val holder = recyclerView?.findViewHolderForAdapterPosition(position)
        if (holder is AssistantMessageViewHolder) {
            holder.updateStreamingContent(content, reasoning)
        }
    }

    private fun isLastAssistantMessage(position: Int): Boolean {
        for (i in itemCount - 1 downTo 0) {
            if (getItem(i).role == ROLE_ASSISTANT) {
                return i == position
            }
        }
        return false
    }

    class UserMessageViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        private val textMessage: TextView = view.findViewById(R.id.textMessage)
        private val attachmentContainer: LinearLayout = view.findViewById(R.id.attachmentContainer)

        fun bind(message: ChatMessage) {
            val attachments = message.attachments.orEmpty()

            if (message.content.isBlank()) {
                textMessage.visibility = View.GONE
            } else {
                textMessage.visibility = View.VISIBLE
                textMessage.text = message.content
            }

            attachmentContainer.removeAllViews()
            attachmentContainer.visibility =
                if (attachments.isEmpty()) View.GONE else View.VISIBLE

            val inflater = LayoutInflater.from(itemView.context)
            attachments.forEach { attachment ->
                val attachmentView = inflater.inflate(
                    R.layout.item_message_attachment,
                    attachmentContainer,
                    false
                )
                val icon = attachmentView.findViewById<ImageView>(R.id.ivAttachmentIcon)
                val name = attachmentView.findViewById<TextView>(R.id.tvAttachmentName)
                val size = attachmentView.findViewById<TextView>(R.id.tvAttachmentSize)

                name.text = attachment.name
                size.text = formatFileSize(attachment.size)

                if (attachment.isImage) {
                    icon.load(Uri.parse(attachment.uri)) { crossfade(true) }
                } else {
                    icon.setImageResource(R.drawable.ic_file)
                }

                attachmentView.setOnClickListener {
                    openAttachment(attachmentView.context, attachment)
                }
                attachmentContainer.addView(attachmentView)
            }
        }
    }

    class AssistantMessageViewHolder(
        view: View,
        private val onReasoningToggle: (Int, Boolean) -> Unit,
        private val onRetryClick: ((ChatMessage) -> Unit)? = null,
        private val onSpeakClick: ((String) -> Unit)? = null,
        private val expandedToolCalls: MutableSet<String> = mutableSetOf()
    ) : RecyclerView.ViewHolder(view) {
        private val contentContainer: LinearLayout = view.findViewById(R.id.contentContainer)
        private val progressBar: ProgressBar = view.findViewById(R.id.progressBar)
        private val textLoading: TextView = view.findViewById(R.id.textLoading)
        private val actionBar: LinearLayout = view.findViewById(R.id.actionBar)
        private val btnCopy: ImageButton = view.findViewById(R.id.btnCopy)
        private val btnRetry: ImageButton = view.findViewById(R.id.btnRetry)
        private val btnSpeak: ImageButton = view.findViewById(R.id.btnSpeak)
        private val toolCallContainer: LinearLayout = view.findViewById(R.id.toolCallContainer)
        private val reasoningCard: LinearLayout = view.findViewById(R.id.reasoningCard)
        private val reasoningHeader: LinearLayout = view.findViewById(R.id.reasoningHeader)
        private val reasoningArrow: ImageView = view.findViewById(R.id.reasoningArrow)
        private val tvReasoningTitle: TextView = view.findViewById(R.id.tvReasoningTitle)
        private val textReasoning: TextView = view.findViewById(R.id.textReasoning)
        private val markwon = Markwon.builder(view.context)
            .usePlugin(StrikethroughPlugin.create())
            .usePlugin(TablePlugin.create(view.context))
            .build()

        /**
         * 当前内容，用于比较是否变化
         */
        private var currentContent: String = ""
        private var currentReasoning: String? = null

        fun bind(message: ChatMessage, showActions: Boolean) {
            currentContent = message.content
            currentReasoning = message.reasoningContent

            if (message.isLoading) {
                // 流式输出时显示内容
                if (message.content.isNotEmpty()) {
                    contentContainer.visibility = View.VISIBLE
                    renderContent(message.content, showCursor = true)
                    progressBar.visibility = View.GONE
                    textLoading.visibility = View.GONE
                } else {
                    contentContainer.visibility = View.GONE
                    progressBar.visibility = View.VISIBLE
                    textLoading.visibility = View.VISIBLE
                }
                actionBar.visibility = View.GONE

                if (message.loadingState == "tool_call") {
                    textLoading.text = "正在调用工具..."
                } else if (message.loadingState == ChatMessage.LOADING_ATTACHMENTS) {
                    textLoading.text = itemView.context.getString(R.string.attachment_processing)
                } else {
                    textLoading.text = "AI思考中..."
                }

                // 显示思考过程（流式，默认收起）；思考卡片出现时不再显示「AI思考中」文案
                if (!message.reasoningContent.isNullOrEmpty()) {
                    reasoningCard.visibility = View.VISIBLE
                    tvReasoningTitle.text = itemView.context.getString(R.string.reasoning_thinking)
                    textReasoning.text = message.reasoningContent
                    textReasoning.visibility = View.GONE
                    reasoningArrow.rotation = 0f
                    textLoading.visibility = View.GONE
                    progressBar.visibility = View.GONE
                } else {
                    reasoningCard.visibility = View.GONE
                }
            } else {
                contentContainer.visibility = View.VISIBLE
                progressBar.visibility = View.GONE
                textLoading.visibility = View.GONE
                actionBar.visibility = if (showActions) View.VISIBLE else View.GONE
                btnSpeak.visibility = if (showActions && message.content.isNotBlank()) View.VISIBLE else View.GONE
                btnSpeak.setOnClickListener { onSpeakClick?.invoke(message.content) }

                renderContent(message.content)
                contentContainer.visibility = if (message.content.isBlank()) View.GONE else View.VISIBLE

                // 显示思考过程
                if (!message.reasoningContent.isNullOrEmpty()) {
                    reasoningCard.visibility = View.VISIBLE
                    tvReasoningTitle.text = if (message.reasoningElapsedSeconds > 0) {
                        itemView.context.getString(R.string.reasoning_done, message.reasoningElapsedSeconds)
                    } else {
                        itemView.context.getString(R.string.reasoning_done_short)
                    }
                    textReasoning.text = message.reasoningContent
                    val isExpanded = message.isReasoningExpanded
                    updateReasoningUI(isExpanded)

                    reasoningHeader.setOnClickListener {
                        val pos = adapterPosition
                        if (pos != RecyclerView.NO_POSITION) {
                            val newExpanded = !message.isReasoningExpanded
                            updateReasoningUI(newExpanded)
                            onReasoningToggle(pos, newExpanded)
                        }
                    }
                } else {
                    reasoningCard.visibility = View.GONE
                }

                // 显示工具调用（可展开详情）
                if (!message.toolCalls.isNullOrEmpty()) {
                    toolCallContainer.visibility = View.VISIBLE
                    toolCallContainer.removeAllViews()

                    val inflater = LayoutInflater.from(itemView.context)
                    message.toolCalls.forEachIndexed { index, toolCall ->
                        val toolView = inflater.inflate(R.layout.item_tool_call, toolCallContainer, false)
                        val header = toolView.findViewById<LinearLayout>(R.id.toolHeader)
                        val detail = toolView.findViewById<LinearLayout>(R.id.toolDetail)
                        val arrow = toolView.findViewById<ImageView>(R.id.toolArrow)
                        val textToolName = toolView.findViewById<TextView>(R.id.textToolName)
                        val textToolStatus = toolView.findViewById<TextView>(R.id.textToolStatus)
                        val textToolArgsFull = toolView.findViewById<TextView>(R.id.textToolArgsFull)
                        val textToolResultFull = toolView.findViewById<TextView>(R.id.textToolResultFull)

                        textToolName.text = toolCall.name
                        textToolStatus.text = when {
                            toolCall.isRunning -> itemView.context.getString(R.string.tool_running)
                            toolCall.isSuccess == true -> itemView.context.getString(R.string.tool_success)
                            toolCall.isSuccess == false -> itemView.context.getString(R.string.tool_failed)
                            else -> ""
                        }
                        textToolArgsFull.text =
                            (toolCall.argsFull ?: toolCall.argsSummary).ifBlank { "-" }
                        textToolResultFull.text = (toolCall.resultSummary ?: "").ifBlank {
                            itemView.context.getString(R.string.tool_no_result)
                        }

                        val key = "${message.timestamp}_$index"
                        var expanded = toolCall.isRunning || expandedToolCalls.contains(key)
                        detail.visibility = if (expanded) View.VISIBLE else View.GONE
                        arrow.rotation = if (expanded) 90f else 0f
                        header.setOnClickListener {
                            expanded = !expanded
                            detail.visibility = if (expanded) View.VISIBLE else View.GONE
                            arrow.animate()
                                .rotation(if (expanded) 90f else 0f)
                                .setDuration(160)
                                .start()
                            if (expanded) expandedToolCalls.add(key) else expandedToolCalls.remove(key)
                        }

                        toolCallContainer.addView(toolView)
                    }
                } else {
                    toolCallContainer.visibility = View.GONE
                }

                if (showActions) {
                    btnRetry.isVisible = true
                    btnRetry.setOnClickListener {
                        onRetryClick?.invoke(message)
                    }
                    btnCopy.setOnClickListener {
                        val context = itemView.context
                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        val clip = ClipData.newPlainText("AI Response", message.content)
                        clipboard.setPrimaryClip(clip)
                        Toast.makeText(context, R.string.copy_success, Toast.LENGTH_SHORT).show()
                    }
                }
            }
        }

        private fun updateReasoningUI(expanded: Boolean) {
            val parent = reasoningCard.parent as? android.view.ViewGroup
            if (parent != null) {
                androidx.transition.TransitionManager.beginDelayedTransition(parent)
            }
            reasoningArrow.animate()
                .rotation(if (expanded) 90f else 0f)
                .setDuration(160)
                .start()
            textReasoning.visibility = if (expanded) View.VISIBLE else View.GONE
        }

        private var lastRenderAt = 0L

        private fun renderThrottled(content: String, showCursor: Boolean = false) {
            val now = SystemClock.uptimeMillis()
            if (now - lastRenderAt < RENDER_THROTTLE_MS) return
            lastRenderAt = now
            renderContent(content, showCursor)
        }

        /**
         * 按 Markdown 切分渲染：正文用 Markwon，代码块用独立组件（横向滚动 + 复制）
         */
        private fun renderContent(content: String, showCursor: Boolean = false) {
            cursorAnimator?.cancel()
            contentContainer.removeAllViews()
            if (content.isBlank()) return
            val context = itemView.context
            MarkdownSegmenter.segment(content).forEach { segment ->
                // 逐段渲染
                when (segment.type) {
                    MarkdownSegment.Type.TEXT -> {
                        val tv = TextView(context).apply {
                            setTextAppearance(R.style.TextAppearance_DoDroid_BodyLarge)
                            setTextColor(
                                MaterialColors.getColor(
                                    this,
                                    com.google.android.material.R.attr.colorOnSurface
                                )
                            )
                            setLineSpacing(0f, 1.7f)
                        }
                        markwon.setMarkdown(tv, segment.content)
                        contentContainer.addView(tv)
                    }

                    MarkdownSegment.Type.CODE -> {
                        val codeView = LayoutInflater.from(context)
                            .inflate(R.layout.item_code_block, contentContainer, false)
                        codeView.findViewById<TextView>(R.id.tvCode).text = segment.content
                        codeView.findViewById<TextView>(R.id.tvLanguage).text =
                            segment.language.ifBlank { "text" }
                        codeView.findViewById<ImageButton>(R.id.btnCopyCode).setOnClickListener {
                            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            clipboard.setPrimaryClip(ClipData.newPlainText("code", segment.content))
                            Toast.makeText(context, R.string.copy_success, Toast.LENGTH_SHORT).show()
                        }
                        contentContainer.addView(codeView)
                    }
                }
            }
            if (showCursor) {
                appendCursor()
            }
        }

        private var cursorAnimator: ValueAnimator? = null
        private var cursorView: TextView? = null

        private fun appendCursor() {
            cursorAnimator?.cancel()
            val context = itemView.context
            val cursor = TextView(context).apply {
                text = "▍"
                setTextColor(
                    MaterialColors.getColor(
                        this,
                        com.google.android.material.R.attr.colorPrimary
                    )
                )
                textSize = 16f
            }
            contentContainer.addView(cursor)
            cursorView = cursor
            cursorAnimator = ValueAnimator.ofFloat(1f, 0.15f).apply {
                duration = 500
                repeatMode = ValueAnimator.REVERSE
                repeatCount = ValueAnimator.INFINITE
                addUpdateListener { animation ->
                    cursor.alpha = animation.animatedValue as Float
                }
                start()
            }
        }

        /**
         * 直接更新流式内容，不触发 bind
         */
        fun updateStreamingContent(content: String, reasoning: String?) {
            if (content != currentContent) {
                currentContent = content
                renderThrottled(content, true)
            }
            if (reasoning != currentReasoning) {
                currentReasoning = reasoning
                if (!reasoning.isNullOrEmpty()) {
                    reasoningCard.visibility = View.VISIBLE
                    tvReasoningTitle.text = itemView.context.getString(R.string.reasoning_thinking)
                    textReasoning.text = reasoning
                }
            }
        }

        /**
         * 更新思考过程展开状态
         */
        fun updateReasoningExpanded(expanded: Boolean) {
            updateReasoningUI(expanded)
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int, payloads: MutableList<Any>) {
        if (payloads.isEmpty()) {
            super.onBindViewHolder(holder, position, payloads)
        } else {
            // 处理 payload 更新
            for (payload in payloads) {
                when (payload) {
                    PAYLOAD_STREAMING -> {
                        if (holder is AssistantMessageViewHolder) {
                            val message = getItem(position)
                            holder.updateStreamingContent(message.content, message.reasoningContent)
                        }
                    }
                    PAYLOAD_REASONING_EXPANDED -> {
                        if (holder is AssistantMessageViewHolder) {
                            val message = getItem(position)
                            holder.updateReasoningExpanded(message.isReasoningExpanded)
                        }
                    }
                }
            }
        }
    }

    class DiffCallback : DiffUtil.ItemCallback<ChatMessage>() {
        override fun areItemsTheSame(oldItem: ChatMessage, newItem: ChatMessage): Boolean {
            return oldItem.timestamp == newItem.timestamp
        }

        override fun areContentsTheSame(oldItem: ChatMessage, newItem: ChatMessage): Boolean {
            return oldItem == newItem
        }
    }

    companion object {
        private const val VIEW_TYPE_USER = 0
        private const val VIEW_TYPE_ASSISTANT = 1
        const val PAYLOAD_STREAMING = "streaming"
        const val PAYLOAD_REASONING_EXPANDED = "reasoning_expanded"

        private fun formatFileSize(size: Long): String {
            return when {
                size < 1024 -> "${size}B"
                size < 1024 * 1024 -> "${size / 1024}KB"
                else -> String.format(java.util.Locale.US, "%.1fMB", size / (1024f * 1024f))
            }
        }

        private fun openAttachment(context: Context, attachment: ChatAttachment) {
            try {
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(Uri.parse(attachment.uri), attachment.mimeType)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                context.startActivity(intent)
            } catch (e: Exception) {
                Toast.makeText(context, R.string.attachment_open_failed, Toast.LENGTH_SHORT).show()
            }
        }
    }
}