package com.example.dodroidai.ui.setting

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.PopupMenu
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ui.common.Toolbar
import com.google.android.material.floatingactionbutton.FloatingActionButton
import kotlinx.coroutines.launch

/**
 * AI 配置列表页面 Fragment
 */
class AIConfigListFragment : Fragment() {

    private var viewModel: AIConfigListViewModel? = null
    private var recyclerView: RecyclerView? = null
    private var toolbar: Toolbar? = null
    private var addButton: FloatingActionButton? = null
    private var emptyText: TextView? = null
    private var adapter: AIConfigAdapter? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        viewModel = AIConfigListViewModel()
    }

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        return inflater.inflate(R.layout.fragment_ai_config_list, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        initViews(view)
        setupToolbar()
        setupRecyclerView()
        setupFab()
        observeData()
    }

    private fun initViews(view: View) {
        toolbar = view.findViewById(R.id.toolbar)
        recyclerView = view.findViewById(R.id.configRecyclerView)
        addButton = view.findViewById(R.id.addButton)
        emptyText = view.findViewById(R.id.emptyText)
    }

    private fun setupToolbar() {
        toolbar?.setTitle(R.string.ai_config_list_title)
        toolbar?.setOnBackClickListener {
            parentFragmentManager.popBackStack()
        }
        toolbar?.setRightVisible(false)
    }

    private fun setupRecyclerView() {
        adapter = AIConfigAdapter(
            onItemClick = { config ->
                navigateToEdit(config.id)
            },
            onItemLongClick = { config, view ->
                showConfigMenu(config, view)
            }
        )
        recyclerView?.layoutManager = LinearLayoutManager(context)
        recyclerView?.adapter = adapter
    }

    private fun setupFab() {
        addButton?.setOnClickListener {
            navigateToEdit(null)
        }
    }

    private fun observeData() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel?.configs?.collect { configs ->
                    adapter?.submitList(configs)
                    updateEmptyState(configs.isEmpty())
                }
            }
        }
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel?.activeConfigId?.collect { activeId ->
                    adapter?.setActiveConfigId(activeId)
                }
            }
        }
    }

    private fun updateEmptyState(isEmpty: Boolean) {
        emptyText?.visibility = if (isEmpty) View.VISIBLE else View.GONE
        recyclerView?.visibility = if (isEmpty) View.GONE else View.VISIBLE
    }

    private fun navigateToEdit(configId: String?) {
        val fragment = AIConfigFragment().apply {
            arguments = Bundle().apply {
                putString(AIConfigFragment.ARG_CONFIG_ID, configId)
            }
        }
        parentFragmentManager.beginTransaction()
            .setCustomAnimations(
                R.anim.slide_in_right,
                R.anim.slide_out_left,
                R.anim.slide_in_left,
                R.anim.slide_out_right
            )
            .add(R.id.fragment_container, fragment)
            .addToBackStack(null)
            .commit()
    }

    private fun showConfigMenu(config: AIConfig, anchorView: View) {
        val popup = PopupMenu(requireContext(), anchorView)
        popup.menuInflater.inflate(R.menu.menu_ai_config_item, popup.menu)

        // 更新"设为激活"按钮文字
        val isActive = config.id == viewModel?.activeConfigId?.value
        popup.menu.findItem(R.id.action_set_active)?.isVisible = !isActive

        popup.setOnMenuItemClickListener { item ->
            when (item.itemId) {
                R.id.action_set_active -> {
                    viewModel?.setActiveConfig(config.id)
                    true
                }
                R.id.action_clone -> {
                    viewModel?.cloneConfig(config.id)
                    true
                }
                R.id.action_delete -> {
                    showDeleteConfirmDialog(config)
                    true
                }
                else -> false
            }
        }
        popup.show()
    }

    private fun showDeleteConfirmDialog(config: AIConfig) {
        AlertDialog.Builder(requireContext())
            .setTitle(R.string.delete)
            .setMessage(getString(R.string.ai_config_delete_confirm))
            .setPositiveButton(R.string.delete) { _, _ ->
                viewModel?.deleteConfig(config.id)
            }
            .setNegativeButton(R.string.cancel, null)
            .show()
    }

    // ===== RecyclerView Adapter =====

    private class AIConfigAdapter(
        private val onItemClick: (AIConfig) -> Unit,
        private val onItemLongClick: (AIConfig, View) -> Unit
    ) : RecyclerView.Adapter<AIConfigAdapter.ViewHolder>() {

        private var configs: List<AIConfig> = emptyList()
        private var activeConfigId: String? = null

        fun submitList(newConfigs: List<AIConfig>) {
            configs = newConfigs
            notifyDataSetChanged()
        }

        fun setActiveConfigId(id: String?) {
            val oldActiveId = activeConfigId
            activeConfigId = id
            // 刷新旧激活项和新激活项
            configs.indexOfFirst { it.id == oldActiveId }.takeIf { it >= 0 }?.let { notifyItemChanged(it) }
            configs.indexOfFirst { it.id == id }.takeIf { it >= 0 }?.let { notifyItemChanged(it) }
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.item_ai_config, parent, false)
            return ViewHolder(view)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            val config = configs[position]
            val isActive = config.id == activeConfigId
            holder.bind(config, isActive)
            holder.itemView.setOnClickListener { onItemClick(config) }
            holder.itemView.setOnLongClickListener {
                onItemLongClick(config, it)
                true
            }
        }

        override fun getItemCount(): Int = configs.size

        class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
            private val providerName: TextView = itemView.findViewById(R.id.providerName)
            private val modelName: TextView = itemView.findViewById(R.id.modelName)
            private val baseUrl: TextView = itemView.findViewById(R.id.baseUrl)
            private val activeIndicator: View = itemView.findViewById(R.id.activeIndicator)
            private val activeIcon: android.widget.ImageView = itemView.findViewById(R.id.activeIcon)

            fun bind(config: AIConfig, isActive: Boolean) {
                providerName.text = config.providerName.ifEmpty { config.provider.name }
                modelName.text = config.mainModel.ifEmpty { config.model }
                baseUrl.text = config.baseUrl
                activeIndicator.visibility = if (isActive) View.VISIBLE else View.GONE
                activeIcon.visibility = if (isActive) View.VISIBLE else View.GONE
            }
        }
    }
}