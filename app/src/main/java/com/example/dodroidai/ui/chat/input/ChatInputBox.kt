package com.example.dodroidai.ui.chat.input

import android.content.Context
import android.text.Editable
import android.text.TextWatcher
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.TextView
import androidx.core.view.isVisible
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.example.dodroidai.R
import com.google.android.material.button.MaterialButton
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.textfield.TextInputLayout

/**
 * 输入框组件，包含输入框/语音模式和操作按钮
 */
class ChatInputBox @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private var inputLayout: TextInputLayout? = null
    private var inputText: TextInputEditText? = null
    private var voiceHint: TextView? = null
    private var btnThink: MaterialButton? = null
    private var btnAdd: ImageButton? = null
    private var btnModeSwitch: ImageButton? = null
    private var btnSend: ImageButton? = null
    private var rvAttachments: RecyclerView? = null

    private var isVoiceMode = false
    private var isDeepThinkEnabled = false
    private var isAddOptionsVisible = false
    private var isKeyboardVisible = false

    private val attachments = mutableListOf<AttachmentItem>()
    private val attachmentAdapter = AttachmentAdapter { item ->
        removeAttachment(item)
    }

    var onDeepThinkToggle: ((Boolean) -> Unit)? = null
    var onModeSwitch: (() -> Unit)? = null
    var onAddClick: (() -> Unit)? = null
    var onFocusChange: ((Boolean) -> Unit)? = null
    var onSendClick: ((String, List<AttachmentItem>) -> Unit)? = null
    var onAttachmentsChange: ((List<AttachmentItem>) -> Unit)? = null

    init {
        LayoutInflater.from(context).inflate(R.layout.view_chat_input_box, this, true)
        initViews()
        setupListeners()
    }

    private fun initViews() {
        inputLayout = findViewById(R.id.inputLayout)
        inputText = findViewById(R.id.inputText)
        voiceHint = findViewById(R.id.voiceHint)
        btnThink = findViewById(R.id.btnThink)
        btnAdd = findViewById(R.id.btnAdd)
        btnModeSwitch = findViewById(R.id.btnModeSwitch)
        btnSend = findViewById(R.id.btnSend)
        rvAttachments = findViewById(R.id.rvAttachments)

        rvAttachments?.layoutManager = LinearLayoutManager(context, LinearLayoutManager.HORIZONTAL, false)
        rvAttachments?.adapter = attachmentAdapter
    }

    private fun setupListeners() {
        btnThink?.setOnClickListener {
            isDeepThinkEnabled = !isDeepThinkEnabled
            btnThink?.isChecked = isDeepThinkEnabled
            onDeepThinkToggle?.invoke(isDeepThinkEnabled)
        }

        btnModeSwitch?.setOnClickListener {
            isVoiceMode = !isVoiceMode
            updateMode()
            onModeSwitch?.invoke()
        }

        btnAdd?.setOnClickListener {
            onAddClick?.invoke()
        }

        btnSend?.setOnClickListener {
            val text = inputText?.text?.toString() ?: ""
            if (text.isNotBlank() || attachments.isNotEmpty()) {
                onSendClick?.invoke(text, attachments.toList())
            }
        }

        inputText?.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                updateSendButtonVisibility()
            }
        })

        inputText?.setOnFocusChangeListener { _, hasFocus ->
            isKeyboardVisible = hasFocus
            onFocusChange?.invoke(hasFocus)
        }
    }

    private fun updateMode() {
        if (isVoiceMode) {
            inputLayout?.visibility = View.GONE
            voiceHint?.visibility = View.VISIBLE
            btnModeSwitch?.setImageResource(R.drawable.ic_keyboard)
        } else {
            inputLayout?.visibility = View.VISIBLE
            voiceHint?.visibility = View.GONE
            btnModeSwitch?.setImageResource(R.drawable.ic_mic)
        }
    }

    fun setAddOptionsVisible(visible: Boolean) {
        isAddOptionsVisible = visible
        btnAdd?.setImageResource(if (visible) R.drawable.ic_close else R.drawable.ic_add)
    }

    fun isAddOptionsVisible(): Boolean = isAddOptionsVisible

    fun isKeyboardVisible(): Boolean = isKeyboardVisible

    fun clearInput() {
        inputText?.text?.clear()
    }

    fun addAttachment(item: AttachmentItem) {
        attachments.add(item)
        updateAttachmentsUi()
    }

    private fun removeAttachment(item: AttachmentItem) {
        attachments.remove(item)
        updateAttachmentsUi()
    }

    private fun updateAttachmentsUi() {
        val hasAttachments = attachments.isNotEmpty()
        rvAttachments?.isVisible = hasAttachments
        attachmentAdapter.submitList(attachments.toList())
        onAttachmentsChange?.invoke(attachments.toList())
        updateSendButtonVisibility()
        rvAttachments?.post {
            rvAttachments?.scrollToPosition(attachments.size - 1)
        }
    }

    private fun updateSendButtonVisibility() {
        val hasText = inputText?.text?.isNotBlank() == true
        val hasAttachments = attachments.isNotEmpty()
        btnModeSwitch?.isVisible = !hasText && !hasAttachments
        btnSend?.isVisible = hasText || hasAttachments
    }
}