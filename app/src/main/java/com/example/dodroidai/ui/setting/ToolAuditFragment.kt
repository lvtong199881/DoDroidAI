package com.example.dodroidai.ui.setting

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
import com.example.dodroidai.data.local.PermissionPolicyStore
import com.example.dodroidai.data.repository.ToolAuditRepository
import com.example.dodroidai.ui.common.Toolbar
import com.google.android.material.button.MaterialButton
import kotlinx.coroutines.launch

class ToolAuditFragment : Fragment(R.layout.fragment_tool_audit) {

    private var toolbar: Toolbar? = null
    private var recyclerView: RecyclerView? = null
    private var tvEmpty: TextView? = null
    private var btnResetPermissions: MaterialButton? = null

    private val adapter = ToolAuditAdapter()
    private lateinit var repository: ToolAuditRepository

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        toolbar = view.findViewById(R.id.toolbar)
        recyclerView = view.findViewById(R.id.recyclerView)
        tvEmpty = view.findViewById(R.id.tvEmpty)
        btnResetPermissions = view.findViewById(R.id.btnResetPermissions)
        repository = ToolAuditRepository(requireContext())

        recyclerView?.layoutManager = LinearLayoutManager(requireContext())
        recyclerView?.adapter = adapter

        toolbar?.setTitle(R.string.tool_audit_title)
        toolbar?.setOnBackClickListener { parentFragmentManager.popBackStack() }
        toolbar?.setRightText(R.string.tool_audit_clear)
        toolbar?.setOnRightClickListener {
            viewLifecycleOwner.lifecycleScope.launch {
                repository.clear()
                Toast.makeText(requireContext(), R.string.tool_audit_cleared, Toast.LENGTH_SHORT).show()
            }
        }

        btnResetPermissions?.setOnClickListener {
            PermissionPolicyStore.clear(requireContext())
            Toast.makeText(requireContext(), R.string.permission_reset_done, Toast.LENGTH_SHORT).show()
        }

        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                repository.observeRecent().collect { entries ->
                    adapter.submitList(entries)
                    tvEmpty?.isVisible = entries.isEmpty()
                }
            }
        }
    }
}
