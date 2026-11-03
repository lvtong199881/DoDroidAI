package com.example.dodroidai.ui.setting

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.core.view.isVisible
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.example.dodroidai.data.local.ScheduledTaskEntity
import com.google.android.material.color.MaterialColors
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ScheduledTaskAdapter(
    private val onDelete: (ScheduledTaskEntity) -> Unit
) : ListAdapter<ScheduledTaskEntity, ScheduledTaskAdapter.ViewHolder>(Diff) {

    private val formatter = SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault())

    inner class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        private val tvPrompt: TextView = view.findViewById(R.id.tvPrompt)
        private val tvStatus: TextView = view.findViewById(R.id.tvStatus)
        private val tvTime: TextView = view.findViewById(R.id.tvTime)
        private val tvResult: TextView = view.findViewById(R.id.tvResult)

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

        fun bind(task: ScheduledTaskEntity) {
            tvPrompt.text = task.prompt
            tvTime.text = formatter.format(Date(task.runAt))
            val (labelRes, colorAttr) = when (task.status) {
                "done" -> R.string.scheduled_task_done to R.attr.success
                "failed" -> R.string.scheduled_task_failed to com.google.android.material.R.attr.colorError
                else -> R.string.scheduled_task_pending to com.google.android.material.R.attr.colorOnSurfaceVariant
            }
            tvStatus.setText(labelRes)
            tvStatus.setTextColor(MaterialColors.getColor(tvStatus, colorAttr))
            tvResult.isVisible = !task.result.isNullOrBlank()
            tvResult.text = task.result
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder =
        ViewHolder(
            LayoutInflater.from(parent.context)
                .inflate(R.layout.item_scheduled_task, parent, false)
        )

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    object Diff : DiffUtil.ItemCallback<ScheduledTaskEntity>() {
        override fun areItemsTheSame(oldItem: ScheduledTaskEntity, newItem: ScheduledTaskEntity): Boolean =
            oldItem.id == newItem.id

        override fun areContentsTheSame(oldItem: ScheduledTaskEntity, newItem: ScheduledTaskEntity): Boolean =
            oldItem == newItem
    }
}
