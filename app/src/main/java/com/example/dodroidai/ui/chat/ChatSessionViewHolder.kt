package com.example.dodroidai.ui.chat

import android.view.View
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.example.dodroidai.data.model.ChatSession

/**
 * 聊天会话 ViewHolder
 */
class ChatSessionViewHolder(
    view: View,
    private val onSessionClick: (String) -> Unit
) : RecyclerView.ViewHolder(view) {

    private val tvTitle: TextView = view.findViewById(R.id.tvTitle)
    private val tvTime: TextView = view.findViewById(R.id.tvTime)

    fun bind(session: ChatSession) {
        tvTitle.text = session.title
        tvTime.text = formatTime(session.updatedAt)

        itemView.setOnClickListener {
            onSessionClick(session.id)
        }
    }

    private fun formatTime(timestamp: Long): String {
        val now = System.currentTimeMillis()
        val diff = now - timestamp
        return when {
            diff < 60 * 1000 -> "刚刚"
            diff < 60 * 60 * 1000 -> "${diff / (60 * 1000)} 分钟前"
            diff < 24 * 60 * 60 * 1000 -> "${diff / (60 * 60 * 1000)} 小时前"
            else -> "${diff / (24 * 60 * 60 * 1000)} 天前"
        }
    }
}