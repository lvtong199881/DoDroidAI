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
    private val onSessionClick: (String) -> Unit,
    private val onSessionLongClick: (ChatSession) -> Unit
) : RecyclerView.ViewHolder(view) {

    private val tvTitle: TextView = view.findViewById(R.id.tvTitle)

    fun bind(session: ChatSession) {
        tvTitle.text = session.title

        itemView.setOnClickListener {
            onSessionClick(session.id)
        }
        itemView.setOnLongClickListener {
            onSessionLongClick(session)
            true
        }
    }
}