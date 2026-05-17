package com.example.dodroidai.ui.common

import android.content.Context
import android.util.AttributeSet
import android.view.LayoutInflater
import android.widget.ImageView
import android.widget.TextView
import androidx.constraintlayout.widget.ConstraintLayout
import com.example.dodroidai.R

/**
 * 设置项卡片组件
 * 包含左侧标题、右侧当前值、右侧箭头图标
 */
class SettingsItemView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : ConstraintLayout(context, attrs, defStyleAttr) {

    private var tvTitle: TextView? = null
    private var tvValue: TextView? = null
    private var ivArrow: ImageView? = null

    private var onClickListener: (() -> Unit)? = null

    init {
        LayoutInflater.from(context).inflate(R.layout.view_settings_item, this, true)
        tvTitle = findViewById(R.id.tvTitle)
        tvValue = findViewById(R.id.tvValue)
        ivArrow = findViewById(R.id.ivArrow)

        setOnClickListener {
            onClickListener?.invoke()
        }
    }

    fun setTitle(title: String) {
        tvTitle?.text = title
    }

    fun setTitle(titleRes: Int) {
        tvTitle?.setText(titleRes)
    }

    fun setValue(value: String) {
        tvValue?.text = value
    }

    fun setValue(valueRes: Int) {
        tvValue?.setText(valueRes)
    }

    fun setOnItemClickListener(listener: () -> Unit) {
        onClickListener = listener
    }
}