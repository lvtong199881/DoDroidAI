package com.example.dodroidai.ui.setting

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.core.view.isVisible
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.example.dodroidai.ai.voice.model.SttModel
import com.google.android.material.button.MaterialButton
import com.google.android.material.progressindicator.LinearProgressIndicator

class SttModelAdapter(
    private val onDownload: (SttModel) -> Unit,
    private val onDelete: (SttModel) -> Unit,
    private val onUse: (SttModel) -> Unit
) : RecyclerView.Adapter<SttModelAdapter.ViewHolder>() {

    private val models = mutableListOf<SttModel>()
    private var downloadedIds: Set<String> = emptySet()
    private var activeId: String? = null
    private var downloadingId: String? = null
    private var progress = 0

    fun setState(
        models: List<SttModel>,
        downloadedIds: Set<String>,
        activeId: String?,
        downloadingId: String?,
        progress: Int
    ) {
        this.models.clear()
        this.models.addAll(models)
        this.downloadedIds = downloadedIds
        this.activeId = activeId
        this.downloadingId = downloadingId
        this.progress = progress
        notifyDataSetChanged()
    }

    inner class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        private val tvName: TextView = view.findViewById(R.id.tvName)
        private val tvStatus: TextView = view.findViewById(R.id.tvStatus)
        private val tvLanguages: TextView = view.findViewById(R.id.tvLanguages)
        private val tvSize: TextView = view.findViewById(R.id.tvSize)
        private val progressBar: LinearProgressIndicator = view.findViewById(R.id.progressBar)
        private val btnAction: MaterialButton = view.findViewById(R.id.btnAction)
        private val btnDelete: MaterialButton = view.findViewById(R.id.btnDelete)

        fun bind(model: SttModel) {
            tvName.text = model.displayName
            tvLanguages.text = model.languages
            tvSize.text = "%.0f MB".format(model.totalBytes / 1048576.0)

            val downloading = downloadingId == model.id
            val downloaded = model.id in downloadedIds
            val active = model.id == activeId

            progressBar.isVisible = downloading
            progressBar.progress = progress

            tvStatus.setText(
                when {
                    downloading -> R.string.stt_downloading
                    downloaded && active -> R.string.stt_active
                    downloaded -> R.string.stt_downloaded
                    else -> R.string.stt_not_downloaded
                }
            )

            btnDelete.isVisible = downloaded && !downloading

            when {
                downloading -> {
                    btnAction.isVisible = false
                }
                downloaded && active -> {
                    btnAction.isVisible = true
                    btnAction.isEnabled = false
                    btnAction.setText(R.string.stt_active)
                }
                downloaded -> {
                    btnAction.isVisible = true
                    btnAction.isEnabled = true
                    btnAction.setText(R.string.stt_use)
                    btnAction.setOnClickListener { onUse(model) }
                }
                else -> {
                    btnAction.isVisible = true
                    btnAction.isEnabled = true
                    btnAction.setText(R.string.stt_download)
                    btnAction.setOnClickListener { onDownload(model) }
                }
            }

            btnDelete.setOnClickListener { onDelete(model) }
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder =
        ViewHolder(
            LayoutInflater.from(parent.context).inflate(R.layout.item_stt_model, parent, false)
        )

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(models[position])
    }

    override fun getItemCount(): Int = models.size
}
