package com.example.dodroidai.ui.chat.input

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.drawable.GradientDrawable
import android.util.AttributeSet
import android.view.View
import kotlin.math.max

/**
 * 波形可视化 View
 * 使用 Canvas 绘制动态波形条
 */
class WaveformView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
    }

    private val amplitudes = mutableListOf<Float>()
    private var maxBars = 40
    private var barWidth = 8f
    private var barSpacing = 4f

    init {
        val bgDrawable = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(Color.parseColor("#33000000"))
            cornerRadius = 16f
        }
        background = bgDrawable
        paint.color = Color.parseColor("#4CAF50")
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val availableWidth = width.toFloat()
        val centerY = height / 2f
        val maxHeight = height * 0.8f

        val totalBarWidth = barWidth + barSpacing
        val startX = (availableWidth - (maxBars * totalBarWidth - barSpacing)) / 2f

        amplitudes.forEachIndexed { index, amplitude ->
            val x = startX + index * totalBarWidth
            val barHeight = max(4f, amplitude * maxHeight)
            val top = centerY - barHeight / 2f
            val bottom = centerY + barHeight / 2f

            canvas.drawRoundRect(x, top, x + barWidth, bottom, barWidth / 2f, barWidth / 2f, paint)
        }
    }

    fun addAmplitude(rmsdB: Float) {
        val normalized = ((rmsdB + 160f) / 160f).coerceIn(0f, 1f)
        amplitudes.add(normalized)

        if (amplitudes.size > maxBars) {
            amplitudes.removeAt(0)
        }

        invalidate()
    }

    fun clear() {
        amplitudes.clear()
        invalidate()
    }
}