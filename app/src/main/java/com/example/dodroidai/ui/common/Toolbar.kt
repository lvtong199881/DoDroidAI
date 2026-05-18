package com.example.dodroidai.ui.common

import android.content.Context
import android.view.LayoutInflater
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.TextView
import androidx.annotation.StringRes
import com.example.dodroidai.R

/**
 * 通用 Toolbar，左侧返回按钮，右侧可选操作按钮，中间标题
 */
class Toolbar @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private var btnBack: ImageButton? = null
    private var tvTitle: TextView? = null
    private var tvRight: TextView? = null
    private var divider: View? = null

    private var onBackClickListener: (() -> Unit)? = null
    private var onRightClickListener: (() -> Unit)? = null

    init {
        LayoutInflater.from(context).inflate(R.layout.layout_toolbar, this, true)
        btnBack = findViewById(R.id.btnBack)
        tvTitle = findViewById(R.id.tvTitle)
        tvRight = findViewById(R.id.tvRight)
        divider = findViewById(R.id.divider)

        btnBack?.setOnClickListener {
            onBackClickListener?.invoke()
        }

        tvRight?.setOnClickListener {
            onRightClickListener?.invoke()
        }
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        updateTitleMargins()
    }

    private fun updateTitleMargins() {
        val title = tvTitle ?: return
        val back = btnBack ?: return
        val right = tvRight ?: return

        val toolbarWidth = width
        if (toolbarWidth == 0) return

        val backWidth = back.width + (back.layoutParams as FrameLayout.LayoutParams).leftMargin
        val rightWidth = if (right.visibility == View.GONE) {
            0
        } else {
            right.width + right.paddingEnd
        }

        val availableWidth = toolbarWidth - backWidth - rightWidth
        val centerX = toolbarWidth / 2

        val titleWidth = title.paint.measureText(title.text.toString()).toInt()
        val titleLeft = centerX - titleWidth / 2

        val marginStart = titleLeft
        val marginEnd = toolbarWidth - titleLeft - titleWidth

        val params = title.layoutParams as? FrameLayout.LayoutParams
        if (params != null) {
            params.marginStart = marginStart
            params.marginEnd = marginEnd
            title.layoutParams = params
        }
    }

    fun setTitle(title: String) {
        tvTitle?.text = title
    }

    fun setTitle(@StringRes titleRes: Int) {
        tvTitle?.setText(titleRes)
    }

    fun setRightText(text: String) {
        tvRight?.text = text
        tvRight?.visibility = if (text.isNotEmpty()) VISIBLE else GONE
    }

    fun setRightText(@StringRes textRes: Int) {
        tvRight?.setText(textRes)
        tvRight?.visibility = if (textRes != 0) VISIBLE else GONE
    }

    fun setRightVisible(visible: Boolean) {
        tvRight?.visibility = if (visible) VISIBLE else GONE
    }

    fun setRightIcon(resId: Int) {
        tvRight?.setBackgroundResource(resId)
        tvRight?.text = ""
        tvRight?.visibility = VISIBLE
    }

    fun setBackIcon(resId: Int) {
        btnBack?.setImageResource(resId)
    }

    fun setOnBackClickListener(listener: () -> Unit) {
        onBackClickListener = listener
    }

    fun setOnRightClickListener(listener: () -> Unit) {
        onRightClickListener = listener
    }

    fun setDividerVisible(visible: Boolean) {
        divider?.visibility = if (visible) VISIBLE else GONE
    }
}