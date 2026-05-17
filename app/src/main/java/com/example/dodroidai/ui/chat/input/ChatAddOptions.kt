package com.example.dodroidai.ui.chat.input

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import androidx.core.view.isVisible
import com.example.dodroidai.R

/**
 * 添加选项组件，包含拍照、相册、文件和OCR提示
 */
class ChatAddOptions @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : LinearLayout(context, attrs, defStyleAttr) {

    private var addOptionsContainer: LinearLayout? = null
    private var ocrHintContainer: LinearLayout? = null

    var onCameraClick: (() -> Unit)? = null
    var onPhotoAlbumClick: (() -> Unit)? = null
    var onFileClick: (() -> Unit)? = null

    init {
        orientation = VERTICAL
        LayoutInflater.from(context).inflate(R.layout.view_chat_add_options, this, true)
        initViews()
        setupListeners()
    }

    private fun initViews() {
        addOptionsContainer = findViewById(R.id.addOptionsContainer)
        ocrHintContainer = findViewById(R.id.ocrHintContainer)
    }

    private fun setupListeners() {
        val cameraItem = addOptionsContainer?.getChildAt(0)
        val photoItem = addOptionsContainer?.getChildAt(1)
        val fileItem = addOptionsContainer?.getChildAt(2)

        cameraItem?.setOnClickListener { onCameraClick?.invoke() }
        photoItem?.setOnClickListener { onPhotoAlbumClick?.invoke() }
        fileItem?.setOnClickListener { onFileClick?.invoke() }
    }

    fun setVisible(visible: Boolean) {
        addOptionsContainer?.isVisible = visible
        ocrHintContainer?.isVisible = visible
    }
}