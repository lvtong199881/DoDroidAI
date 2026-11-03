package com.example.dodroidai.ui.setting

import android.os.Bundle
import android.view.View
import android.widget.TextView
import androidx.core.view.isVisible
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.example.dodroidai.data.repository.NoteRepository
import com.example.dodroidai.ui.common.Toolbar
import kotlinx.coroutines.launch

class NoteListFragment : Fragment(R.layout.fragment_note_list) {

    private var toolbar: Toolbar? = null
    private var recyclerView: RecyclerView? = null
    private var tvEmpty: TextView? = null

    private lateinit var adapter: NoteAdapter
    private lateinit var repository: NoteRepository

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        toolbar = view.findViewById(R.id.toolbar)
        recyclerView = view.findViewById(R.id.recyclerView)
        tvEmpty = view.findViewById(R.id.tvEmpty)
        repository = NoteRepository(requireContext())

        adapter = NoteAdapter { note ->
            viewLifecycleOwner.lifecycleScope.launch {
                repository.delete(note)
            }
        }
        recyclerView?.layoutManager = LinearLayoutManager(requireContext())
        recyclerView?.adapter = adapter

        toolbar?.setTitle(R.string.notes_title)
        toolbar?.setOnBackClickListener {
            parentFragmentManager.popBackStack()
        }
        toolbar?.setRightVisible(false)

        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                repository.observeNotes().collect { notes ->
                    adapter.submitList(notes)
                    tvEmpty?.isVisible = notes.isEmpty()
                }
            }
        }
    }
}
