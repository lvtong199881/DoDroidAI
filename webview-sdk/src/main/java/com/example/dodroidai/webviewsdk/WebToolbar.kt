package com.example.dodroidai.webviewsdk

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.TextView
import androidx.annotation.DrawableRes
import androidx.annotation.StringRes

/**
 * WebFragment 专用 Toolbar。
 *
 * 左侧:icon1(back) + icon2(close),中间标题,右侧 icon(TODO 预留)。
 * 视觉风格参照 app 内 Toolbar,资源全部使用 wv_ 前缀在 library 内自包含。
 */
class WebToolbar @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private var btnBack: ImageButton? = null
    private var btnClose: ImageButton? = null
    private var tvTitle: TextView? = null
    private var btnRight: ImageButton? = null
    private var divider: View? = null

    private var onBackClickListener: (() -> Unit)? = null
    private var onCloseClickListener: (() -> Unit)? = null
    private var onRightClickListener: (() -> Unit)? = null

    init {
        LayoutInflater.from(context).inflate(R.layout.wv_view_toolbar, this, true)
        btnBack = findViewById(R.id.wvBtnBack)
        btnClose = findViewById(R.id.wvBtnClose)
        tvTitle = findViewById(R.id.wvTvTitle)
        btnRight = findViewById(R.id.wvBtnRight)
        divider = findViewById(R.id.wvDivider)

        btnBack?.setOnClickListener {
            onBackClickListener?.invoke()
        }
        btnClose?.setOnClickListener {
            onCloseClickListener?.invoke()
        }
        btnRight?.setOnClickListener {
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
        val right = btnRight ?: return

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
        post { updateTitleMargins() }
    }

    fun setTitle(@StringRes titleRes: Int) {
        tvTitle?.setText(titleRes)
        post { updateTitleMargins() }
    }

    fun setBackEnabled(enabled: Boolean) {
        btnBack?.apply {
            isEnabled = enabled
            alpha = if (enabled) 1f else 0.4f
        }
    }

    fun setOnBackClickListener(listener: () -> Unit) {
        onBackClickListener = listener
    }

    fun setOnCloseClickListener(listener: () -> Unit) {
        onCloseClickListener = listener
    }

    fun setRightIcon(@DrawableRes resId: Int) {
        btnRight?.setImageResource(resId)
    }

    fun setRightVisible(visible: Boolean) {
        btnRight?.visibility = if (visible) VISIBLE else GONE
    }

    fun setOnRightClickListener(listener: () -> Unit) {
        onRightClickListener = listener
    }

    fun setDividerVisible(visible: Boolean) {
        divider?.visibility = if (visible) VISIBLE else GONE
    }
}
