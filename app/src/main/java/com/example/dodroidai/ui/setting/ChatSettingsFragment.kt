package com.example.dodroidai.ui.setting

import android.os.Bundle
import android.view.View
import androidx.fragment.app.Fragment
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.example.dodroidai.R
import com.example.dodroidai.ai.config.AppConfigManager
import com.example.dodroidai.ui.common.Toolbar
import com.google.android.material.materialswitch.MaterialSwitch
import kotlinx.coroutines.launch

class ChatSettingsFragment : Fragment(R.layout.fragment_chat_settings) {

    private var toolbar: Toolbar? = null
    private var switchAutoCollapse: MaterialSwitch? = null

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        toolbar = view.findViewById(R.id.toolbar)
        switchAutoCollapse = view.findViewById(R.id.switchAutoCollapse)

        toolbar?.setTitle(R.string.chat_settings_title)
        toolbar?.setOnBackClickListener { parentFragmentManager.popBackStack() }
        toolbar?.setRightVisible(false)

        viewLifecycleOwner.lifecycleScope.launch {
            viewLifecycleOwner.repeatOnLifecycle(Lifecycle.State.STARTED) {
                AppConfigManager.reasoningAutoCollapseFlow.collect { enabled ->
                    switchAutoCollapse?.isChecked = enabled
                }
            }
        }

        switchAutoCollapse?.setOnCheckedChangeListener { _, checked ->
            viewLifecycleOwner.lifecycleScope.launch {
                AppConfigManager.updateReasoningAutoCollapse(checked)
            }
        }
    }
}
