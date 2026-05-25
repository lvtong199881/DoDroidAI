package com.example.dodroidai.ui.chat

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.TextView
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.DoDroidAIApplication
import com.example.dodroidai.R
import com.example.dodroidai.data.model.ChatSession
import com.example.dodroidai.ui.common.CustomDialog
import com.example.dodroidai.ui.common.OptionDialog
import com.example.dodroidai.ui.common.Toolbar
import com.example.dodroidai.ui.setting.SettingsFragment
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

/**
 * 对话列表页面 Fragment，显示聊天历史记录
 */
class ChatListFragment : Fragment() {

    private var toolbar: Toolbar? = null
    private var tvEmpty: TextView? = null
    private var recyclerView: RecyclerView? = null
    private var adapter: ChatSessionAdapter? = null

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        return inflater.inflate(R.layout.fragment_chat_list, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        initViews(view)
        observeSessions()
        setupBackStackListener()
    }

    private fun setupBackStackListener() {
        parentFragmentManager.addOnBackStackChangedListener {
            refreshSessions()
        }
    }

    private fun observeSessions() {
        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                DoDroidAIApplication.instance.chatRepository.sessionsFlow.collect { sessions ->
                    val sortedSessions = sessions.sortedByDescending { it.updatedAt }
                    adapter?.submitList(sortedSessions)
                    tvEmpty?.visibility = if (sortedSessions.isEmpty()) View.VISIBLE else View.GONE
                    recyclerView?.visibility = if (sortedSessions.isEmpty()) View.GONE else View.VISIBLE
                }
            }
        }
    }

    private fun refreshSessions() {
        viewLifecycleOwner.lifecycleScope.launch {
            val sessions = DoDroidAIApplication.instance.chatRepository.sessionsFlow.first()
            val sortedSessions = sessions.sortedByDescending { it.updatedAt }
            adapter?.submitList(sortedSessions)
            tvEmpty?.visibility = if (sortedSessions.isEmpty()) View.VISIBLE else View.GONE
            recyclerView?.visibility = if (sortedSessions.isEmpty()) View.GONE else View.VISIBLE
        }
    }

    private fun initViews(view: View) {
        toolbar = view.findViewById(R.id.toolbar)
        tvEmpty = view.findViewById(R.id.tvEmpty)
        recyclerView = view.findViewById(R.id.recyclerView)

        adapter = ChatSessionAdapter(
            onSessionClick = { sessionId -> navigateTo(ChatFragment.newInstance(sessionId)) },
            onSessionLongClick = { session -> showSessionOptions(session) }
        )
        recyclerView?.layoutManager = LinearLayoutManager(context)
        recyclerView?.adapter = adapter

        toolbar?.setTitle(R.string.app_name)
        toolbar?.setBackIcon(R.drawable.ic_add)
        toolbar?.setOnBackClickListener {
            navigateTo(ChatFragment.newInstance(null))
        }
        toolbar?.setRightIcon(R.drawable.ic_settings)
        toolbar?.setOnRightClickListener {
            navigateTo(SettingsFragment())
        }
    }

    private fun navigateTo(fragment: Fragment) {
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

    private fun showSessionOptions(session: ChatSession) {
        OptionDialog.show(
            context = requireContext(),
            options = listOf(
                getString(R.string.rename_session) to { showRenameDialog(session) },
                getString(R.string.delete_session) to { showDeleteConfirmDialog(session) }
            )
        )
    }

    private fun showRenameDialog(session: ChatSession) {
        val editText = EditText(requireContext()).apply {
            setText(session.title)
            setSelection(text.length)
            setPadding(48, 32, 48, 32)
        }
        CustomDialog.Builder(requireContext())
            .setTitle(R.string.rename_session)
            .setCustomView(editText)
            .setButtons(
                CustomDialog.ButtonInfo(text = getString(R.string.cancel)),
                CustomDialog.ButtonInfo(
                    text = getString(R.string.confirm),
                    onClick = {
                        val newTitle = editText.text.toString().trim()
                        if (newTitle.isNotEmpty()) {
                            renameSession(session.id, newTitle)
                        }
                    }
                )
            )
            .build()
            .show()
    }

    private fun showDeleteConfirmDialog(session: ChatSession) {
        CustomDialog.Builder(requireContext())
            .setTitle(R.string.delete_session)
            .setDescription(getString(R.string.delete_session_confirm, session.title))
            .setButtons(
                CustomDialog.ButtonInfo(text = getString(R.string.cancel)),
                CustomDialog.ButtonInfo(
                    text = getString(R.string.delete),
                    onClick = { deleteSession(session.id) }
                )
            )
            .build()
            .show()
    }

    private fun renameSession(sessionId: String, newTitle: String) {
        viewLifecycleOwner.lifecycleScope.launch {
            val sessions = DoDroidAIApplication.instance.chatRepository.sessionsFlow.first()
            val session = sessions.find { it.id == sessionId } ?: return@launch
            val updatedSession = session.copy(title = newTitle, updatedAt = System.currentTimeMillis())
            DoDroidAIApplication.instance.chatRepository.saveSession(updatedSession)
        }
    }

    private fun deleteSession(sessionId: String) {
        viewLifecycleOwner.lifecycleScope.launch {
            DoDroidAIApplication.instance.chatRepository.deleteSession(sessionId)
        }
    }
}