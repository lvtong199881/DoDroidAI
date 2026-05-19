package com.example.dodroidai.ui.chat.adapter

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.example.dodroidai.ai.model.ChatMessage
import com.example.dodroidai.ai.model.ChatMessage.Companion.ROLE_ASSISTANT
import com.example.dodroidai.ai.model.ChatMessage.Companion.ROLE_USER
import com.example.dodroidai.ai.tools.ToolCallDisplay
import io.noties.markwon.Markwon

/**
 * 聊天消息适配器
 */
class ChatMessageAdapter : ListAdapter<ChatMessage, RecyclerView.ViewHolder>(DiffCallback()) {

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
                AssistantMessageViewHolder(view)
            }
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        val message = getItem(position)
        val isLastAssistantMessage = isLastAssistantMessage(position)
        when (holder) {
            is UserMessageViewHolder -> holder.bind(message)
            is AssistantMessageViewHolder -> holder.bind(message, isLastAssistantMessage)
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

        fun bind(message: ChatMessage) {
            textMessage.text = message.content
        }
    }

    class AssistantMessageViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        private val textMessage: TextView = view.findViewById(R.id.textMessage)
        private val progressBar: ProgressBar = view.findViewById(R.id.progressBar)
        private val textLoading: TextView = view.findViewById(R.id.textLoading)
        private val actionBar: LinearLayout = view.findViewById(R.id.actionBar)
        private val btnCopy: ImageButton = view.findViewById(R.id.btnCopy)
        private val toolCallContainer: LinearLayout = view.findViewById(R.id.toolCallContainer)
        private val markwon = Markwon.create(view.context)

        fun bind(message: ChatMessage, showActions: Boolean) {
            if (message.isLoading) {
                textMessage.visibility = View.GONE
                progressBar.visibility = View.VISIBLE
                textLoading.visibility = View.VISIBLE
                actionBar.visibility = View.GONE

                if (message.loadingState == "tool_call") {
                    textLoading.text = "正在调用工具..."
                } else {
                    textLoading.text = "AI思考中...${message.loadingSeconds}秒"
                }
            } else {
                textMessage.visibility = View.VISIBLE
                progressBar.visibility = View.GONE
                textLoading.visibility = View.GONE
                actionBar.visibility = if (showActions) View.VISIBLE else View.GONE

                markwon.setMarkdown(textMessage, message.content)
                textMessage.visibility = if (message.content.isBlank()) View.GONE else View.VISIBLE

                // 显示工具调用结果
                if (message.toolCalls.isNotEmpty()) {
                    toolCallContainer.visibility = View.VISIBLE
                    toolCallContainer.removeAllViews()

                    val inflater = LayoutInflater.from(itemView.context)
                    for (toolCall in message.toolCalls) {
                        val toolView = inflater.inflate(R.layout.item_tool_call, toolCallContainer, false)
                        val textToolName = toolView.findViewById<TextView>(R.id.textToolName)
                        val textToolArgs = toolView.findViewById<TextView>(R.id.textToolArgs)
                        val textToolStatus = toolView.findViewById<TextView>(R.id.textToolStatus)

                        textToolName.text = toolCall.name
                        textToolArgs.text = toolCall.argsSummary

                        val statusText = when {
                            toolCall.isRunning -> "🔄"
                            toolCall.isSuccess == true -> "✅"
                            toolCall.isSuccess == false -> "❌"
                            else -> ""
                        }
                        textToolStatus.text = statusText

                        toolCallContainer.addView(toolView)
                    }
                } else {
                    toolCallContainer.visibility = View.GONE
                }

                if (showActions) {
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
    }
}