package com.example.dodroidai.ui.setting

import android.os.Bundle
import android.view.View
import android.widget.RadioGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.example.dodroidai.ai.voice.model.SttModelCatalog
import com.example.dodroidai.ai.voice.model.SttModelDownloader
import com.example.dodroidai.ai.voice.model.SttModelRepository
import com.example.dodroidai.ai.voice.model.SttModelSource
import com.example.dodroidai.ui.common.Toolbar
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

class SttSettingsFragment : Fragment(R.layout.fragment_stt_settings) {

    private var toolbar: Toolbar? = null
    private var recyclerView: RecyclerView? = null
    private var sourceGroup: RadioGroup? = null

    private lateinit var repository: SttModelRepository
    private lateinit var downloader: SttModelDownloader
    private lateinit var adapter: SttModelAdapter

    private var downloadJob: Job? = null
    private var downloadingId: String? = null
    private var downloadProgress = 0

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        toolbar = view.findViewById(R.id.toolbar)
        recyclerView = view.findViewById(R.id.recyclerView)
        sourceGroup = view.findViewById(R.id.sourceGroup)
        repository = SttModelRepository(requireContext())
        downloader = SttModelDownloader(requireContext())

        adapter = SttModelAdapter(
            onDownload = { startDownload(it) },
            onDelete = { model ->
                downloadJob?.cancel()
                downloadingId = null
                repository.delete(model)
                render()
            },
            onUse = { model ->
                repository.setActive(model)
                render()
            }
        )
        recyclerView?.layoutManager = LinearLayoutManager(requireContext())
        recyclerView?.adapter = adapter

        toolbar?.setTitle(R.string.stt_title)
        toolbar?.setOnBackClickListener { parentFragmentManager.popBackStack() }
        toolbar?.setRightVisible(false)

        val source = repository.source()
        (if (source == SttModelSource.HF_MIRROR) R.id.rbMirror else R.id.rbHf)
            .let { sourceGroup?.check(it) }
        sourceGroup?.setOnCheckedChangeListener { _, checkedId ->
            repository.setSource(
                if (checkedId == R.id.rbHf) SttModelSource.HUGGINGFACE else SttModelSource.HF_MIRROR
            )
        }

        render()
    }

    private fun startDownload(model: com.example.dodroidai.ai.voice.model.SttModel) {
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
        val models = SttModelCatalog.all
        val downloaded = models.filter { repository.isDownloaded(it) }.map { it.id }.toSet()
        adapter.setState(
            models = models,
            downloadedIds = downloaded,
            activeId = repository.activeModel().id,
            downloadingId = downloadingId,
            progress = downloadProgress
        )
    }

    override fun onDestroyView() {
        super.onDestroyView()
        downloadJob?.cancel()
        downloadJob = null
    }
}
