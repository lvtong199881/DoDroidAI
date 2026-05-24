package com.example.dodroidai.ui.chat.input

import android.content.Context
import android.util.Log
import android.view.WindowManager
import com.example.dodroidai.ui.common.CustomDialog

/**
 * 语音输入弹窗
 * 使用 CustomDialog，仅展示波形，高度为屏幕的 40%
 */
class VoiceInputDialog(private val context: Context) {

    private var dialog: CustomDialog? = null
    private var waveformView: WaveformView? = null

    fun show() {
        waveformView = WaveformView(context).apply {
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT
            )
        }

        val screenHeight = context.resources.displayMetrics.heightPixels
        val height = (screenHeight * 0.4f).toInt()

        dialog = CustomDialog.Builder(context)
            .setCustomView(waveformView!!)
            .setButtons(CustomDialog.ButtonInfo(text = "", onClick = null, dismissOnClick = false))
            .setCancelable(false)
            .setSize(WindowManager.LayoutParams.MATCH_PARENT, height)
            .setGravity(android.view.Gravity.BOTTOM)
            .build().apply {
                show()
            }
    }

    fun dismiss() {
        dialog?.dismiss()
        dialog = null
        waveformView = null
    }

    fun updateRms(rmsdB: Float) {
        Log.d("VoiceInputDialog","updateRms:$rmsdB")
        waveformView?.addAmplitude(rmsdB)
    }
}