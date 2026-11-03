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
import com.example.dodroidai.data.local.RequestTraceEntity
import com.google.android.material.color.MaterialColors
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class RequestTraceAdapter : ListAdapter<RequestTraceEntity, RequestTraceAdapter.ViewHolder>(Diff) {

    private val formatter = SimpleDateFormat("MM-dd HH:mm:ss", Locale.getDefault())

    inner class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        private val tvSummary: TextView = view.findViewById(R.id.tvSummary)
        private val tvStatus: TextView = view.findViewById(R.id.tvStatus)
        private val tvMeta: TextView = view.findViewById(R.id.tvMeta)
        private val tvError: TextView = view.findViewById(R.id.tvError)

        fun bind(trace: RequestTraceEntity) {
            tvSummary.text = "${trace.provider} · ${trace.model}"
            tvStatus.text = itemView.context.getString(
                if (trace.success) R.string.diagnostics_success else R.string.diagnostics_failed
            )
            tvStatus.setTextColor(
                MaterialColors.getColor(
                    tvStatus,
                    if (trace.success) R.attr.success else com.google.android.material.R.attr.colorError
                )
            )
            tvMeta.text = buildString {
                append(formatter.format(Date(trace.startedAt)))
                append("  ·  ")
                append("${trace.durationMs} ms")
                append("  ·  ")
                append("${trace.apiFormat}")
                if (trace.toolCallCount > 0) {
                    append("  ·  tools: ${trace.toolCallCount}")
                }
            }
            tvError.isVisible = !trace.error.isNullOrBlank()
            tvError.text = trace.error
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder =
        ViewHolder(
            LayoutInflater.from(parent.context).inflate(R.layout.item_request_trace, parent, false)
        )

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(getItem(position))
    }

    object Diff : DiffUtil.ItemCallback<RequestTraceEntity>() {
        override fun areItemsTheSame(oldItem: RequestTraceEntity, newItem: RequestTraceEntity): Boolean =
            oldItem.id == newItem.id

        override fun areContentsTheSame(oldItem: RequestTraceEntity, newItem: RequestTraceEntity): Boolean =
            oldItem == newItem
    }
}
