package com.example.dodroidai.ui.setting

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.TextView
import com.example.dodroidai.R
import com.example.dodroidai.ai.model.AIProvider

/**
 * 带图标的下拉框适配器
 */
class ProviderIconAdapter(
    context: Context,
    private val providers: List<AIProvider>
) : ArrayAdapter<String>(context, android.R.layout.simple_dropdown_item_1line, providers.map { provider -> getProviderNameStatic(context, provider) }) {

    override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
        return createView(position, convertView, parent)
    }

    override fun getDropDownView(position: Int, convertView: View?, parent: ViewGroup): View {
        return createView(position, convertView, parent)
    }

    private fun createView(position: Int, convertView: View?, parent: ViewGroup): View {
        val view = convertView ?: LayoutInflater.from(context).inflate(
            android.R.layout.simple_dropdown_item_1line,
            parent,
            false
        )
        val textView = view.findViewById<TextView>(android.R.id.text1)
        val provider = providers[position]
        textView.text = getProviderNameStatic(context, provider)
        textView.setCompoundDrawablesWithIntrinsicBounds(
            getProviderIcon(provider),
            0, 0, 0
        )
        textView.compoundDrawablePadding = 16
        return view
    }

    companion object {
        fun getProviderNameStatic(ctx: Context, provider: AIProvider): String {
            return when (provider) {
                AIProvider.OPENAI -> ctx.getString(R.string.provider_openai)
                AIProvider.DEEPSEEK -> ctx.getString(R.string.provider_deepseek)
                AIProvider.MINIMAX -> ctx.getString(R.string.provider_minimax)
                AIProvider.CUSTOM -> ctx.getString(R.string.provider_custom)
            }
        }

        fun getProviderIcon(provider: AIProvider): Int {
            return when (provider) {
                AIProvider.OPENAI -> R.drawable.ic_provider_openai
                AIProvider.DEEPSEEK -> R.drawable.ic_provider_deepseek
                AIProvider.MINIMAX -> R.drawable.ic_provider_minimax
                AIProvider.CUSTOM -> 0
            }
        }
    }
}