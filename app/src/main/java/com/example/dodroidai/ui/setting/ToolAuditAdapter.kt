package com.example.dodroidai.ui.setting

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.example.dodroidai.data.local.ToolAuditEntity
import com.google.android.material.color.MaterialColors
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ToolAuditAdapter : ListAdapter<ToolAuditEntity, ToolAuditAdapter.ViewHolder>(Diff) {

    private val formatter = SimpleDateFormat("MM-dd HH:mm:ss", Locale.getDefault())

    inner class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        private val tvToolName: TextView = view.findViewById(R.id.tvToolName)
        private val tvStatus: TextView = view.findViewById(R.id.tvStatus)
        private val tvArgs: TextView = view.findViewById(R.id.tvArgs)
        private val tvTime: TextView = view.findViewById(R.id.tvTime)

        fun bind(entry: ToolAuditEntity) {
            tvToolName.text = entry.toolName
            tvStatus.text = if (entry.success) {
                itemView.context.getString(R.string.tool_audit_success)
            } else {
                itemView.context.getString(R.string.tool_audit_failed)
            }
            val colorAttr = if (entry.success) {
                R.attr.success
            } else {
                com.google.android.material.R.attr.colorError
            }
            tvStatus.setTextColor(MaterialColors.getColor(tvStatus, colorAttr))
            tvArgs.text = entry.argsSummary.ifBlank { "-" }
            tvTime.text = formatter.format(Date(entry.createdAt))
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder =
        ViewHolder(
            LayoutInflater.from(parent.context).inflate(R.layout.item_tool_audit, parent, false)
        )

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    object Diff : DiffUtil.ItemCallback<ToolAuditEntity>() {
        override fun areItemsTheSame(oldItem: ToolAuditEntity, newItem: ToolAuditEntity): Boolean =
            oldItem.id == newItem.id

        override fun areContentsTheSame(oldItem: ToolAuditEntity, newItem: ToolAuditEntity): Boolean =
            oldItem == newItem
    }
}
