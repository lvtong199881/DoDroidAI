package com.example.dodroidai.ui.chat

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.fragment.app.Fragment
import com.example.dodroidai.R
import com.example.dodroidai.ui.common.Toolbar
import com.example.dodroidai.ui.setting.SettingsFragment

/**
 * 对话列表页面 Fragment，显示聊天历史记录
 */
class ChatListFragment : Fragment() {

    private var toolbar: Toolbar? = null
    private var tvEmpty: TextView? = null

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        return inflater.inflate(R.layout.fragment_chat_list, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        toolbar = view.findViewById(R.id.toolbar)
        tvEmpty = view.findViewById(R.id.tvEmpty)

        toolbar?.setTitle(R.string.app_name)
        toolbar?.setBackIcon(R.drawable.ic_add)
        toolbar?.setOnBackClickListener {
            parentFragmentManager.beginTransaction()
                .replace(R.id.fragment_container, ChatFragment())
                .addToBackStack(null)
                .commit()
        }
        toolbar?.setRightIcon(R.drawable.ic_settings)
        toolbar?.setOnRightClickListener {
            parentFragmentManager.beginTransaction()
                .replace(R.id.fragment_container, SettingsFragment())
                .addToBackStack(null)
                .commit()
        }
    }
}