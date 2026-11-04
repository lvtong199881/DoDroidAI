package com.example.dodroidai.ui.setting

import android.os.Bundle
import android.view.View
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import com.example.dodroidai.R
import com.example.dodroidai.ai.voice.model.TtsModel
import com.example.dodroidai.ai.voice.model.TtsModelCatalog
import com.example.dodroidai.ai.voice.model.TtsModelDownloader
import com.example.dodroidai.ai.voice.model.TtsModelRepository
import com.example.dodroidai.ui.common.Toolbar
import com.google.android.material.button.MaterialButton
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

class TtsSettingsFragment : Fragment(R.layout.fragment_tts_settings) {

    private var toolbar: Toolbar? = null
    private var tvModelName: TextView? = null
    private var tvModelDesc: TextView? = null
    private var tvState: TextView? = null
    private var progressBar: ProgressBar? = null
    private var tvProgress: TextView? = null
    private var btnDownload: MaterialButton? = null
    private var btnUse: MaterialButton? = null
    private var btnDelete: MaterialButton? = null

    private lateinit var repository: TtsModelRepository
    private lateinit var downloader: TtsModelDownloader
    private var downloadJob: Job? = null
    private var downloadingId: String? = null
    private var downloadProgress = 0

    private val model: TtsModel = TtsModelCatalog.all.first()

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        toolbar = view.findViewById(R.id.toolbar)
        tvModelName = view.findViewById(R.id.tvModelName)
        tvModelDesc = view.findViewById(R.id.tvModelDesc)
        tvState = view.findViewById(R.id.tvState)
        progressBar = view.findViewById(R.id.progressBar)
        tvProgress = view.findViewById(R.id.tvProgress)
        btnDownload = view.findViewById(R.id.btnDownload)
        btnUse = view.findViewById(R.id.btnUse)
        btnDelete = view.findViewById(R.id.btnDelete)

        repository = TtsModelRepository(requireContext())
        downloader = TtsModelDownloader(requireContext())

        toolbar?.setTitle(R.string.tts_title)
        toolbar?.setOnBackClickListener { parentFragmentManager.popBackStack() }
        toolbar?.setRightVisible(false)

        btnDownload?.setOnClickListener { startDownload() }
        btnUse?.setOnClickListener {
            repository.setActive(model)
            render()
        }
        btnDelete?.setOnClickListener {
            downloadJob?.cancel()
            downloadingId = null
            repository.delete(model)
            render()
        }

        render()
    }

    private fun startDownload() {
        if (downloadJob?.isActive == true) return
        downloadingId = model.id
        downloadProgress = 0
        render()

        downloadJob = viewLifecycleOwner.lifecycleScope.launch {
            try {
                downloader.download(
                    model = model,
                    source = repository.source(),
                    onProgress = { done, total ->
                        viewLifecycleOwner.lifecycleScope.launch {
                            downloadProgress = if (total > 0) (done * 100 / total).toInt() else 0
                            render()
                        }
                    }
                )
                repository.setActive(model)
                Toast.makeText(requireContext(), R.string.stt_downloaded, Toast.LENGTH_SHORT).show()
            } catch (e: Exception) {
                Toast.makeText(requireContext(), R.string.stt_download_failed, Toast.LENGTH_SHORT).show()
            } finally {
                downloadingId = null
                render()
            }
        }
    }

    private fun render() {
        val downloaded = repository.isDownloaded(model)
        val active = repository.activeModel().id == model.id && downloaded
        val downloading = downloadingId == model.id

        tvModelName?.text = model.displayName
        tvModelDesc?.text = getString(
            R.string.tts_model_desc,
            model.languages,
            model.totalBytes / 1024 / 1024
        )
        tvState?.text = when {
            downloading -> getString(R.string.stt_downloading, downloadProgress)
            active -> getString(R.string.stt_active)
            downloaded -> getString(R.string.stt_downloaded)
            else -> ""
        }

        progressBar?.visibility = if (downloading) View.VISIBLE else View.GONE
        progressBar?.progress = downloadProgress
        tvProgress?.visibility = if (downloading) View.VISIBLE else View.GONE
        tvProgress?.text = "$downloadProgress%"

        btnDownload?.visibility = if (downloaded || downloading) View.GONE else View.VISIBLE
        btnUse?.visibility = if (downloaded && !active) View.VISIBLE else View.GONE
        btnDelete?.visibility = if (downloaded) View.VISIBLE else View.GONE
    }

    override fun onDestroyView() {
        super.onDestroyView()
        downloadJob?.cancel()
        downloadJob = null
    }
}
