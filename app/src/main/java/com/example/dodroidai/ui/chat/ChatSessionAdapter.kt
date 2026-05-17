package com.example.dodroidai.ui.chat

import android.util.Log
import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.example.dodroidai.data.model.ChatSession

/**
 * 聊天会话列表适配器
 */
class ChatSessionAdapter(
    private val onSessionClick: (String) -> Unit
) : RecyclerView.Adapter<ChatSessionViewHolder>() {

    private val items = mutableListOf<ChatSession>()

    fun submitList(newItems: List<ChatSession>) {
        items.clear()
        items.addAll(newItems)
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ChatSessionViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(R.layout.item_chat_session, parent, false)
        return ChatSessionViewHolder(view, onSessionClick)
    }

    override fun onBindViewHolder(holder: ChatSessionViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size
}