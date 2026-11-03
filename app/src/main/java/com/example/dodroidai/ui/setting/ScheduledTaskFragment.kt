package com.example.dodroidai.ui.setting

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.core.view.isVisible
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.example.dodroidai.data.repository.ScheduledTaskRepository
import com.example.dodroidai.ui.common.Toolbar
import kotlinx.coroutines.launch

class ScheduledTaskFragment : Fragment(R.layout.fragment_scheduled_tasks) {

    private var toolbar: Toolbar? = null
    private var recyclerView: RecyclerView? = null
    private var tvEmpty: TextView? = null

    private lateinit var adapter: ScheduledTaskAdapter
    private lateinit var repository: ScheduledTaskRepository

    private val notificationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        toolbar = view.findViewById(R.id.toolbar)
        recyclerView = view.findViewById(R.id.recyclerView)
        tvEmpty = view.findViewById(R.id.tvEmpty)
        repository = ScheduledTaskRepository(requireContext())

        adapter = ScheduledTaskAdapter { task ->
            viewLifecycleOwner.lifecycleScope.launch {
                repository.delete(task)
            }
        }
        recyclerView?.layoutManager = LinearLayoutManager(requireContext())
        recyclerView?.adapter = adapter

        toolbar?.setTitle(R.string.scheduled_tasks_title)
        toolbar?.setOnBackClickListener { parentFragmentManager.popBackStack() }
        toolbar?.setRightVisible(false)

        requestNotificationPermissionIfNeeded()

        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                repository.observeAll().collect { tasks ->
                    adapter.submitList(tasks)
                    tvEmpty?.isVisible = tasks.isEmpty()
                }
            }
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            requireContext(),
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }
}
