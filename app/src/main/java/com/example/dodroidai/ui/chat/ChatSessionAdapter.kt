package com.example.dodroidai.ui.chat

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.example.dodroidai.data.model.ChatSession

/**
 * 聊天会话列表项
 */
sealed class ChatListItem {
    data class SectionHeader(val title: String) : ChatListItem()
    data class SessionItem(val session: ChatSession) : ChatListItem()
}

/**
 * 聊天会话列表适配器（支持分组标题）
 */
class ChatSessionAdapter(
    private val onSessionClick: (String) -> Unit,
    private val onSessionLongClick: (ChatSession) -> Unit
) : RecyclerView.Adapter<RecyclerView.ViewHolder>() {

    private val items = mutableListOf<ChatListItem>()

    companion object {
        private const val VIEW_TYPE_HEADER = 0
        private const val VIEW_TYPE_SESSION = 1
    }

    fun submitList(newItems: List<ChatListItem>) {
        items.clear()
        items.addAll(newItems)
        notifyDataSetChanged()
    }

    override fun getItemViewType(position: Int): Int {
        return when (items[position]) {
            is ChatListItem.SectionHeader -> VIEW_TYPE_HEADER
            is ChatListItem.SessionItem -> VIEW_TYPE_SESSION
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): RecyclerView.ViewHolder {
        return when (viewType) {
            VIEW_TYPE_HEADER -> {
                val view = LayoutInflater.from(parent.context)
                    .inflate(R.layout.item_chat_section_header, parent, false)
                SectionHeaderViewHolder(view)
            }
            else -> {
                val view = LayoutInflater.from(parent.context)
                    .inflate(R.layout.item_chat_session, parent, false)
                ChatSessionViewHolder(view, onSessionClick, onSessionLongClick)
            }
        }
    }

    override fun onBindViewHolder(holder: RecyclerView.ViewHolder, position: Int) {
        when (val item = items[position]) {
            is ChatListItem.SectionHeader -> (holder as SectionHeaderViewHolder).bind(item.title)
            is ChatListItem.SessionItem -> (holder as ChatSessionViewHolder).bind(item.session)
        }
    }

    override fun getItemCount(): Int = items.size
}

/**
 * 分组标题 ViewHolder
 */
class SectionHeaderViewHolder(itemView: android.view.View) : RecyclerView.ViewHolder(itemView) {
    private val tvTitle: android.widget.TextView = itemView.findViewById(R.id.tvSectionTitle)

    fun bind(title: String) {
        tvTitle.text = title
    }
}