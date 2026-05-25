package com.example.dodroidai.ui.common

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import com.example.dodroidai.R

/**
 * 选项列表弹窗工具类
 */
object OptionDialog {

    fun show(
        context: Context,
        options: List<Pair<String, () -> Unit>>
    ) {
        val optionsLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        options.forEachIndexed { index, (text, action) ->
            if (index > 0) {
                val divider = View(context).apply {
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        1
                    )
                    setBackgroundColor(context.getColor(R.color.divider_horizontal))
                }
                optionsLayout.addView(divider)
            }
            val optionView = LayoutInflater.from(context)
                .inflate(R.layout.item_dialog_option, optionsLayout, false)
            optionView.findViewById<TextView>(R.id.tvOptionText).text = text
            optionView.setOnClickListener {
                action()
            }
            optionsLayout.addView(optionView)
        }

        CustomDialog.Builder(context)
            .setCustomView(optionsLayout)
            .setCancelable(true)
            .build()
            .show()
    }
}