package com.example.dodroidai.ui.chat

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageButton
import android.widget.TextView
import androidx.fragment.app.Fragment
import com.example.dodroidai.R
import com.example.dodroidai.ui.common.Toolbar

/**
 * 聊天页面 Fragment，显示对话内容
 */
class ChatFragment : Fragment() {

    private var toolbar: Toolbar? = null
    private var inputText: com.google.android.material.textfield.TextInputEditText? = null
    private var btnSend: ImageButton? = null
    private var btnVoice: ImageButton? = null

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        return inflater.inflate(R.layout.fragment_chat, container, false)
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        toolbar = view.findViewById(R.id.toolbar)
        inputText = view.findViewById(R.id.inputText)
        btnSend = view.findViewById(R.id.btnSend)
        btnVoice = view.findViewById(R.id.btnVoice)

        toolbar?.setTitle(R.string.new_chat)
        toolbar?.setOnBackClickListener {
            parentFragmentManager.popBackStack()
        }
        toolbar?.setRightVisible(false)
    }
}