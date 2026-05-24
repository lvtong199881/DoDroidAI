package com.example.dodroidai.ui.chat.input

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.util.AttributeSet
import android.view.View

/**
 * 心电图风格波形 View
 */
class WaveformView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val waveformPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 4f
        color = Color.parseColor("#4CAF50")
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }

    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 12f
        color = Color.parseColor("#204CAF50")
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }

    private val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1f
        color = Color.parseColor("#1AFFFFFF")
    }

    private val amplitudes = mutableListOf<Float>()
    private val path = Path()
    private val glowPath = Path()

    private var maxPoints = 150
    private var pointSpacing = 8f
    private var centerY = 0f
    private var amplitudeScale = 1f

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        centerY = h / 2f
        amplitudeScale = h * 0.35f
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        drawGrid(canvas)

        if (amplitudes.size < 2) return

        path.reset()
        glowPath.reset()

        val startX = (width - (amplitudes.size - 1) * pointSpacing) / 2f

        for (i in amplitudes.indices) {
            val x = startX + i * pointSpacing
            val y = centerY - amplitudes[i] * amplitudeScale

            if (i == 0) {
                path.moveTo(x, y)
                glowPath.moveTo(x, y)
            } else {
                path.lineTo(x, y)
                glowPath.lineTo(x, y)
            }
        }

        canvas.drawPath(glowPath, glowPaint)
        canvas.drawPath(path, waveformPaint)
    }

    private fun drawGrid(canvas: Canvas) {
        val horizontalLines = 5
        val verticalLines = 8

        val hStep = height.toFloat() / horizontalLines
        for (i in 1 until horizontalLines) {
            val y = i * hStep
            canvas.drawLine(0f, y, width.toFloat(), y, gridPaint)
        }

        val vStep = width.toFloat() / verticalLines
        for (i in 1 until verticalLines) {
            val x = i * vStep
            canvas.drawLine(x, 0f, x, height.toFloat(), gridPaint)
        }
    }

    fun addAmplitude(rmsdB: Float) {
        val normalized = ((rmsdB + 60f) / 60f).coerceIn(0f, 1f)
        amplitudes.add(normalized)

        while (amplitudes.size > maxPoints) {
            amplitudes.removeAt(0)
        }

        invalidate()
    }

    fun clear() {
        amplitudes.clear()
        invalidate()
    }
}