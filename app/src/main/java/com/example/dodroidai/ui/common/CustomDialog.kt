package com.example.dodroidai.ui.common

import android.app.Dialog
import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import com.example.dodroidai.R

/**
 * 自定义对话框，使用 Builder 模式
 *
 * 布局结构（从上到下）：
 * - 标题（居中，加粗）
 * - 描述文案（居中）
 * - 自定义View（可选）
 * - 按钮区域（水平排列）
 */
class CustomDialog(
    context: Context,
    private val title: String?,
    private val description: String?,
    private val customView: View?,
    private val buttons: List<ButtonInfo>,
    private val cancelable: Boolean,
    private val width: Int = WindowManager.LayoutParams.MATCH_PARENT,
    private val height: Int = WindowManager.LayoutParams.WRAP_CONTENT,
    private val gravity: Int = android.view.Gravity.CENTER
) : Dialog(context, R.style.CustomDialogTheme) {

    init {
        val inflater = LayoutInflater.from(context)
        val view = inflater.inflate(R.layout.dialog_custom, null)

        val titleView = view.findViewById<TextView>(R.id.tvTitle)
        val descView = view.findViewById<TextView>(R.id.tvDesc)
        val customContainer = view.findViewById<LinearLayout>(R.id.customContentContainer)
        val buttonContainer = view.findViewById<LinearLayout>(R.id.buttonContainer)

        // 设置标题
        if (title.isNullOrEmpty()) {
            titleView.visibility = View.GONE
        } else {
            titleView.text = title
        }

        // 设置描述
        if (description.isNullOrEmpty()) {
            descView.visibility = View.GONE
        } else {
            descView.text = description
        }

        // 设置自定义View
        if (customView != null) {
            customContainer.visibility = View.VISIBLE
            customContainer.addView(customView)
        } else {
            customContainer.visibility = View.GONE
        }

        // 设置按钮
        setupButtons(buttonContainer)

        setContentView(view)
        setCancelable(cancelable)
    }

    override fun show() {
        super.show()
        window?.apply {
            val layoutParams = WindowManager.LayoutParams()
            layoutParams.copyFrom(getAttributes())
            layoutParams.width = width
            layoutParams.height = height
            layoutParams.dimAmount = 0.5f
            layoutParams.gravity = gravity
            setAttributes(layoutParams)
        }
    }

    private fun setupButtons(buttonContainer: LinearLayout) {
        buttonContainer.removeAllViews()

        buttons.forEachIndexed { index, buttonInfo ->
            val button = createButton(buttonInfo, index, buttonContainer)
            buttonContainer.addView(button)

            // 添加按钮之间的分隔线
            if (index < buttons.size - 1) {
                val divider = View(context).apply {
                    layoutParams = LinearLayout.LayoutParams(1, LinearLayout.LayoutParams.MATCH_PARENT)
                    setBackgroundResource(R.drawable.divider_vertical)
                }
                buttonContainer.addView(divider)
            }
        }
    }

    private fun createButton(buttonInfo: ButtonInfo, index: Int, buttonContainer: LinearLayout): View {
        return LayoutInflater.from(context).inflate(R.layout.item_dialog_button, buttonContainer, false).apply {
            val textView = findViewById<TextView>(R.id.btnText)
            textView.text = buttonInfo.text

            // 第一个按钮使用主色调（确认按钮）
            if (index == 0 && buttons.size > 1) {
                textView.setTextColor(context.getColor(R.color.dialog_button_primary))
            } else {
                textView.setTextColor(context.getColor(R.color.dialog_button_secondary))
            }

            setOnClickListener {
                buttonInfo.onClick?.invoke()
                if (buttonInfo.dismissOnClick) {
                    dismiss()
                }
            }
        }
    }

    /**
     * 按钮信息
     */
    data class ButtonInfo(
        val text: String,
        val onClick: (() -> Unit)? = null,
        val dismissOnClick: Boolean = true
    )

    /**
     * Builder 模式
     */
    class Builder(val context: Context) {
        private var title: String? = null
        private var description: String? = null
        private var customView: View? = null
        private var buttons: List<ButtonInfo> = emptyList()
        private var cancelable: Boolean = true
        private var width: Int = WindowManager.LayoutParams.MATCH_PARENT
        private var height: Int = WindowManager.LayoutParams.WRAP_CONTENT
        private var gravity: Int = android.view.Gravity.CENTER

        fun setTitle(title: String): Builder {
            this.title = title
            return this
        }

        fun setTitle(titleRes: Int): Builder {
            this.title = context.getString(titleRes)
            return this
        }

        fun setDescription(description: String): Builder {
            this.description = description
            return this
        }

        fun setDescription(descriptionRes: Int): Builder {
            this.description = context.getString(descriptionRes)
            return this
        }

        fun setCustomView(view: View): Builder {
            this.customView = view
            return this
        }

        fun setButtons(vararg buttonInfos: ButtonInfo): Builder {
            this.buttons = buttonInfos.toList()
            return this
        }

        fun setCancelable(cancelable: Boolean): Builder {
            this.cancelable = cancelable
            return this
        }

        fun setSize(width: Int, height: Int): Builder {
            this.width = width
            this.height = height
            return this
        }

        fun setGravity(gravity: Int): Builder {
            this.gravity = gravity
            return this
        }

        fun build(): CustomDialog {
            require(buttons.isNotEmpty()) { "At least one button is required" }
            return CustomDialog(context, title, description, customView, buttons, cancelable, width, height, gravity)
        }
    }
}