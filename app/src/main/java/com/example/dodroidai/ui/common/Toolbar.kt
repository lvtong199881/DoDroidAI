package com.example.dodroidai.ui.common

import android.content.Context
import android.view.LayoutInflater
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import androidx.annotation.StringRes
import com.example.dodroidai.R

/**
 * 通用 Toolbar，左侧返回按钮，右侧可选操作按钮，标题左对齐
 */
class Toolbar @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : FrameLayout(context, attrs, defStyleAttr) {

    private var btnBack: ImageButton? = null
    private var tvTitle: TextView? = null
    private var tvRight: TextView? = null
    private var rightContainer: LinearLayout? = null
    private var btnAutoRead: ImageButton? = null
    private var btnNewChat: ImageButton? = null
    private var divider: View? = null

    private var onBackClickListener: (() -> Unit)? = null
    private var onRightClickListener: (() -> Unit)? = null
    private var onAutoReadClickListener: (() -> Unit)? = null
    private var onNewChatClickListener: (() -> Unit)? = null

    init {
        LayoutInflater.from(context).inflate(R.layout.layout_toolbar, this, true)
        btnBack = findViewById(R.id.btnBack)
        tvTitle = findViewById(R.id.tvTitle)
        tvRight = findViewById(R.id.tvRight)
        rightContainer = findViewById(R.id.rightContainer)
        btnAutoRead = findViewById(R.id.btnAutoRead)
        btnNewChat = findViewById(R.id.btnNewChat)
        divider = findViewById(R.id.divider)

        btnBack?.setOnClickListener {
            onBackClickListener?.invoke()
        }

        tvRight?.setOnClickListener {
            onRightClickListener?.invoke()
        }

        btnAutoRead?.setOnClickListener {
            onAutoReadClickListener?.invoke()
        }

        btnNewChat?.setOnClickListener {
            onNewChatClickListener?.invoke()
        }
    }

    fun setTitle(title: String) {
        tvTitle?.text = title
    }

    fun setTitle(@StringRes titleRes: Int) {
        tvTitle?.setText(titleRes)
    }

    /** 标题字号（dp） */
    fun setTitleSize(sizeDp: Float) {
        tvTitle?.textSize = sizeDp
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

    // ===== 自动朗读 / 新对话 =====

    fun setAutoReadVisible(visible: Boolean) {
        btnAutoRead?.visibility = if (visible) VISIBLE else GONE
    }

    fun setAutoReadIcon(@androidx.annotation.DrawableRes resId: Int) {
        btnAutoRead?.setImageResource(resId)
    }

    fun setOnAutoReadClickListener(listener: () -> Unit) {
        onAutoReadClickListener = listener
    }

    /** 自动朗读开启时用主题色，关闭时用默认色 */
    fun setAutoReadActive(active: Boolean) {
        val button = btnAutoRead ?: return
        val color = com.google.android.material.color.MaterialColors.getColor(
            button,
            if (active) {
                com.google.android.material.R.attr.colorPrimary
            } else {
                com.google.android.material.R.attr.colorOnSurface
            }
        )
        button.imageTintList = android.content.res.ColorStateList.valueOf(color)
    }

    fun setNewChatVisible(visible: Boolean) {
        btnNewChat?.visibility = if (visible) VISIBLE else GONE
    }

    fun setNewChatIcon(@androidx.annotation.DrawableRes resId: Int) {
        btnNewChat?.setImageResource(resId)
    }

    fun setOnNewChatClickListener(listener: () -> Unit) {
        onNewChatClickListener = listener
    }

    fun setDividerVisible(visible: Boolean) {
        divider?.visibility = if (visible) VISIBLE else GONE
    }
}
