package com.example.dodroidai.ui.setting

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.example.dodroidai.data.local.MemoryFactEntity
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MemoryAdapter(
    private val onDelete: (MemoryFactEntity) -> Unit
) : ListAdapter<MemoryFactEntity, MemoryAdapter.ViewHolder>(Diff) {

    private val formatter = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault())

    inner class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        private val tvKey: TextView = view.findViewById(R.id.tvKey)
        private val tvValue: TextView = view.findViewById(R.id.tvValue)
        private val tvTime: TextView = view.findViewById(R.id.tvTime)

        init {
            itemView.setOnLongClickListener {
                val position = adapterPosition
                if (position != RecyclerView.NO_POSITION) {
                    onDelete(getItem(position))
                    true
                } else {
                    false
                }
            }
        }

        fun bind(fact: MemoryFactEntity) {
            tvKey.text = fact.key
            tvValue.text = fact.value
            tvTime.text = formatter.format(Date(fact.updatedAt))
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder =
        ViewHolder(
            LayoutInflater.from(parent.context).inflate(R.layout.item_memory, parent, false)
        )

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    object Diff : DiffUtil.ItemCallback<MemoryFactEntity>() {
        override fun areItemsTheSame(oldItem: MemoryFactEntity, newItem: MemoryFactEntity): Boolean =
            oldItem.id == newItem.id

        override fun areContentsTheSame(oldItem: MemoryFactEntity, newItem: MemoryFactEntity): Boolean =
            oldItem == newItem
    }
}
