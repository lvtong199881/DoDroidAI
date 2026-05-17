package com.example.dodroidai.ui.chat.adapter

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ProgressBar
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.example.dodroidai.ai.model.ChatMessage
import io.noties.markwon.Markwon

/**
 * 聊天消息适配器
 */
class ChatMessageAdapter : ListAdapter<ChatMessage, RecyclerView.ViewHolder>(DiffCallback()) {

    override fun getItemViewType(position: Int): Int {
        return when (getItem(position).role) {
            ChatMessage.ROLE_USER -> VIEW_TYPE_USER
            ChatMessage.ROLE_ASSISTANT -> VIEW_TYPE_ASSISTANT
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
        when (holder) {
            is UserMessageViewHolder -> holder.bind(message)
            is AssistantMessageViewHolder -> holder.bind(message)
        }
    }

    class UserMessageViewHolder(view: android.view.View) : RecyclerView.ViewHolder(view) {
        private val textMessage: TextView = view.findViewById(R.id.textMessage)

        fun bind(message: ChatMessage) {
            textMessage.text = message.content
        }
    }

    class AssistantMessageViewHolder(view: android.view.View) : RecyclerView.ViewHolder(view) {
        private val textMessage: TextView = view.findViewById(R.id.textMessage)
        private val progressBar: ProgressBar = view.findViewById(R.id.progressBar)
        private val markwon = Markwon.create(view.context)

        fun bind(message: ChatMessage) {
            if (message.isLoading) {
                textMessage.visibility = View.GONE
                progressBar.visibility = View.VISIBLE
            } else {
                textMessage.visibility = View.VISIBLE
                progressBar.visibility = View.GONE
                markwon.setMarkdown(textMessage, message.content)
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