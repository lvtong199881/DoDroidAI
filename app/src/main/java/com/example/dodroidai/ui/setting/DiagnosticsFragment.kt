package com.example.dodroidai.ui.setting

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.view.View
import android.widget.TextView
import android.widget.Toast
import androidx.core.view.isVisible
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.example.dodroidai.data.repository.RequestTraceRepository
import com.example.dodroidai.ui.common.Toolbar
import com.google.android.material.button.MaterialButton
import kotlinx.coroutines.launch

class DiagnosticsFragment : Fragment(R.layout.fragment_diagnostics) {

    private var toolbar: Toolbar? = null
    private var recyclerView: RecyclerView? = null
    private var tvEmpty: TextView? = null
    private var btnExport: MaterialButton? = null

    private val adapter = RequestTraceAdapter()
    private lateinit var repository: RequestTraceRepository

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        toolbar = view.findViewById(R.id.toolbar)
        recyclerView = view.findViewById(R.id.recyclerView)
        tvEmpty = view.findViewById(R.id.tvEmpty)
        btnExport = view.findViewById(R.id.btnExport)
        repository = RequestTraceRepository(requireContext())

        recyclerView?.layoutManager = LinearLayoutManager(requireContext())
        recyclerView?.adapter = adapter

        toolbar?.setTitle(R.string.diagnostics_title)
        toolbar?.setOnBackClickListener { parentFragmentManager.popBackStack() }
        toolbar?.setRightText(R.string.diagnostics_clear)
        toolbar?.setOnRightClickListener {
            viewLifecycleOwner.lifecycleScope.launch {
                repository.clear()
            }
        }

        btnExport?.setOnClickListener {
            viewLifecycleOwner.lifecycleScope.launch {
                val json = repository.exportJson()
                if (json.isBlank() || json == "[]") {
                    Toast.makeText(requireContext(), R.string.diagnostics_empty, Toast.LENGTH_SHORT).show()
                    return@launch
                }
                val clipboard = requireContext().getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(ClipData.newPlainText("request_traces", json))
                Toast.makeText(requireContext(), R.string.diagnostics_exported, Toast.LENGTH_SHORT).show()
            }
        }

        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                repository.observeRecent().collect { traces ->
                    adapter.submitList(traces)
                    tvEmpty?.isVisible = traces.isEmpty()
                }
            }
        }
    }
}
