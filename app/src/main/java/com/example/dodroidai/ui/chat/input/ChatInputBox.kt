package com.example.dodroidai.ui.chat.input

import android.content.Context
import android.text.Editable
import android.text.TextWatcher
import android.content.res.ColorStateList
import android.graphics.Color
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.TextView
import androidx.core.content.ContextCompat
import androidx.core.view.isVisible
import com.google.android.material.color.MaterialColors
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
    private var btnThink: com.google.android.material.chip.Chip? = null
    private var btnWebSearch: com.google.android.material.chip.Chip? = null
    private var btnAdd: ImageButton? = null
    private var btnModeSwitch: ImageButton? = null
    private var btnSend: ImageButton? = null
    private var rvAttachments: RecyclerView? = null

    private var isVoiceMode = false
    private var isDeepThinkEnabled = false
    private var isWebSearchEnabled = false
    private var isAddOptionsVisible = false
    private var isKeyboardVisible = false
    private var isLoading = false

    private val attachments = mutableListOf<AttachmentItem>()
    private val attachmentAdapter = AttachmentAdapter { item ->
        removeAttachment(item)
    }

    var onDeepThinkToggle: ((Boolean) -> Unit)? = null
    var onWebSearchToggle: ((Boolean) -> Unit)? = null
    var onModeSwitch: (() -> Unit)? = null
    var onAddClick: (() -> Unit)? = null
    var onFocusChange: ((Boolean) -> Unit)? = null
    var onSendClick: ((String, List<AttachmentItem>) -> Unit)? = null
    var onStopClick: (() -> Unit)? = null
    var onAttachmentsChange: ((List<AttachmentItem>) -> Unit)? = null

    /**
     * 语音输入监听器
     */
    interface OnVoiceInputListener {
        fun onVoiceStart()
        fun onVoiceEnd()
    }

    var onVoiceInputListener: OnVoiceInputListener? = null

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
        btnWebSearch = findViewById(R.id.btnWebSearch)
        btnThink?.let { chip ->
            updateChipStyle(chip)
            chip.setOnCheckedChangeListener { _, _ -> updateChipStyle(chip) }
        }
        btnWebSearch?.let { chip ->
            updateChipStyle(chip)
            chip.setOnCheckedChangeListener { _, _ -> updateChipStyle(chip) }
        }
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

        btnWebSearch?.setOnClickListener {
            isWebSearchEnabled = !isWebSearchEnabled
            btnWebSearch?.isChecked = isWebSearchEnabled
            onWebSearchToggle?.invoke(isWebSearchEnabled)
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
            if (isLoading) {
                onStopClick?.invoke()
                return@setOnClickListener
            }
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

        inputText?.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == android.view.inputmethod.EditorInfo.IME_ACTION_SEND) {
                val text = inputText?.text?.toString() ?: ""
                if (text.isNotBlank() || attachments.isNotEmpty()) {
                    onSendClick?.invoke(text, attachments.toList())
                }
                true
            } else {
                false
            }
        }

        // 语音输入：按下开始，抬起结束
        voiceHint?.setOnTouchListener { _, event ->
            android.util.Log.d("ChatInputBox", "touch event: ${event.action}")
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    onVoiceInputListener?.onVoiceStart()
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    onVoiceInputListener?.onVoiceEnd()
                    true
                }
                else -> false
            }
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

    /**
     * 根据生成状态切换发送/停止按钮。
     */
    fun setLoading(loading: Boolean) {
        if (isLoading == loading) return
        isLoading = loading
        btnSend?.animate()?.cancel()
        btnSend?.animate()
            ?.alpha(0f)
            ?.setDuration(80)
            ?.withEndAction {
                if (loading) {
                    btnSend?.setImageResource(R.drawable.ic_stop)
                    btnSend?.isVisible = true
                    btnModeSwitch?.isVisible = false
                } else {
                    btnSend?.setImageResource(R.drawable.ic_send)
                    updateSendButtonVisibility()
                }
                btnSend?.animate()?.alpha(1f)?.setDuration(140)?.start()
            }
            ?.start()
    }

    fun isKeyboardVisible(): Boolean = isKeyboardVisible

    fun clearInput() {
        inputText?.text?.clear()
        attachments.clear()
        updateAttachmentsUi()
    }

    fun attachmentCount(): Int = attachments.size

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
        if (isLoading) {
            btnSend?.isVisible = true
            btnModeSwitch?.isVisible = false
            return
        }
        val hasText = inputText?.text?.isNotBlank() == true
        val hasAttachments = attachments.isNotEmpty()
        btnModeSwitch?.isVisible = !hasText && !hasAttachments
        btnSend?.isVisible = hasText || hasAttachments
    }

    /**
     * 选中态：蓝色边框 + 淡蓝背景 + 蓝字，隐藏左侧图标；未选中恢复默认
     */
    private fun updateChipStyle(chip: com.google.android.material.chip.Chip) {
        val checked = chip.isChecked
        val blue = ContextCompat.getColor(chip.context, R.color.deepseek_blue)
        val blueBg = ContextCompat.getColor(chip.context, R.color.deepseek_blue_10)
        val normalText = MaterialColors.getColor(
            chip,
            com.google.android.material.R.attr.colorOnSurface
        )
        val outline = MaterialColors.getColor(
            chip,
            com.google.android.material.R.attr.colorOutlineVariant
        )
        chip.chipBackgroundColor = ColorStateList.valueOf(if (checked) blueBg else Color.TRANSPARENT)
        chip.chipStrokeColor = ColorStateList.valueOf(if (checked) blue else outline)
        chip.chipStrokeWidth = chip.resources.displayMetrics.density
        chip.setTextColor(if (checked) blue else normalText)
        chip.isChipIconVisible = !checked
        chip.isCheckedIconVisible = false
        chip.setChipIconTint(ColorStateList.valueOf(if (checked) blue else normalText))
    }

}
