package com.example.dodroidai.ui.chat.input

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R

/**
 * 附件列表适配器
 */
class AttachmentAdapter(
    private val onDeleteClick: (AttachmentItem) -> Unit
) : ListAdapter<AttachmentItem, AttachmentAdapter.ViewHolder>(AttachmentDiffCallback()) {

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_attachment, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    inner class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val ivFileIcon: ImageView = itemView.findViewById(R.id.ivFileIcon)
        private val tvFileName: TextView = itemView.findViewById(R.id.tvFileName)
        private val tvFileSize: TextView = itemView.findViewById(R.id.tvFileSize)
        private val btnDelete: ImageView = itemView.findViewById(R.id.btnDelete)

        fun bind(item: AttachmentItem) {
            tvFileName.text = item.name
            tvFileSize.text = formatFileSize(item.size)

            ivFileIcon.setImageResource(
                if (item.isImage) R.drawable.ic_photo else R.drawable.ic_file
            )

            btnDelete.setOnClickListener {
                onDeleteClick(item)
            }
        }

        private fun formatFileSize(size: Long): String {
            return when {
                size < 1024 -> "${size}B"
                size < 1024 * 1024 -> "${size / 1024}KB"
                else -> "${size / (1024 * 1024)}MB"
            }
        }
    }

    private class AttachmentDiffCallback : DiffUtil.ItemCallback<AttachmentItem>() {
        override fun areItemsTheSame(oldItem: AttachmentItem, newItem: AttachmentItem): Boolean {
            return oldItem.uri == newItem.uri
        }

        override fun areContentsTheSame(oldItem: AttachmentItem, newItem: AttachmentItem): Boolean {
            return oldItem == newItem
        }
    }
}