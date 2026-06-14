package com.example.dodroidai.webviewsdk

import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.JavascriptInterface
import androidx.core.graphics.toColorInt
import org.json.JSONObject

/**
 * WebView → 原生 WebToolbar 的 JS Bridge。
 *
 * H5 通过 window.WVToolbar.xxx() 调用本对象方法,实现对原生 toolbar 的控制:
 * - setTitle(String):更新标题文字
 * - setTitleColor(String hex):更新标题颜色
 * - setCloseVisible(Boolean):控制 close 按钮显隐
 * - setBackgroundGradient(String json):设置 toolbar 整体渐变背景
 * - setAlpha(Int 0-100):手动设置 toolbar 整体 alpha(同时清掉滚动联动规则)
 * - setScrollAlphaRule(String json):启用 "scrollY → alpha" 滚动联动,
 *   json 格式 {"startY":Int dp,"endY":Int dp,"startAlpha":0-100,"endAlpha":0-100}
 * - disableScrollAlpha():禁用滚动联动(alpha 保持当前值)
 *
 * 线程模型:JS 接口默认在 WebView binder 线程被调用,
 * 所有 View / Controller 操作通过 Handler 切到主线程执行。
 *
 * Lifecycle:不持有 WebToolbar 强引用,通过 provider 函数按需获取,
 * 避免 Fragment view 销毁后调用导致崩溃。
 */
class WebToolbarBridge internal constructor(
    private val toolbarProvider: WebToolbar?,
    private val scrollAlphaController: ScrollAlphaController?
) {

    private val mainHandler = Handler(Looper.getMainLooper())

    @JavascriptInterface
    fun setTitle(title: String) {
        try {
            mainHandler.post {
                toolbarProvider?.setTitle(title)
            }
        } catch (e: Exception) {
            Log.e(TAG, "setTitle failed: $title", e)
        }
    }

    @JavascriptInterface
    fun setTitleColor(hex: String) {
        try {
            val color = hex.toColorInt()
            mainHandler.post {
                toolbarProvider?.setTitleTextColor(color)
            }
        } catch (e: Exception) {
            Log.e(TAG, "setTitleColor failed: $hex", e)
        }
    }

    @JavascriptInterface
    fun setCloseVisible(visible: Boolean) {
        try {
            mainHandler.post {
                toolbarProvider?.setCloseVisible(visible)
            }
        } catch (e: Exception) {
            Log.e(TAG, "setCloseVisible failed: $visible", e)
        }
    }

    @JavascriptInterface
    fun setBackgroundGradient(json: String) {
        try {
            val obj = JSONObject(json)
            mainHandler.post {
                val toolbar = toolbarProvider ?: return@post
                applyGradient(toolbar, obj)
            }
        } catch (e: Exception) {
            Log.e(TAG, "setBackgroundGradient failed: $json", e)
        }
    }

    /**
     * 手动设置 toolbar alpha,接收百分比 0-100。
     * 内部调 [ScrollAlphaController.setManualAlpha] —— 会自动清掉滚动联动规则,
     * 避免下一次滚动事件把手动值覆盖。
     */
    @JavascriptInterface
    fun setAlpha(alpha: Int) {
        try {
            mainHandler.post {
                scrollAlphaController?.setManualAlpha(alpha)
            }
        } catch (e: Exception) {
            Log.e(TAG, "setAlpha failed: $alpha", e)
        }
    }

    /**
     * 启用 "WebView scrollY → toolbar alpha" 滚动联动。
     *
     * JSON 字段:
     * - startY: Int,单位 dp(≈ CSS px,viewport=device-width 时一致)
     * - endY: Int,单位 dp
     * - startAlpha: Int,0-100
     * - endAlpha: Int,0-100
     *
     * 任一字段缺失或 JSON 解析失败,整体忽略并打 Warning 日志,不抛异常。
     * startY > endY 内部自动 swap(同步 swap alpha)。
     */
    @JavascriptInterface
    fun setScrollAlphaRule(json: String) {
        try {
            val obj = JSONObject(json)
            if (!obj.has(KEY_START_Y) || !obj.has(KEY_END_Y) ||
                !obj.has(KEY_START_ALPHA) || !obj.has(KEY_END_ALPHA)
            ) {
                Log.w(TAG, "setScrollAlphaRule missing fields, ignored: $json")
                return
            }
            val sy = obj.getInt(KEY_START_Y)
            val ey = obj.getInt(KEY_END_Y)
            val sa = obj.getInt(KEY_START_ALPHA)
            val ea = obj.getInt(KEY_END_ALPHA)
            mainHandler.post {
                scrollAlphaController?.setRule(
                    startScrollDp = sy,
                    endScrollDp = ey,
                    startAlpha = sa,
                    endAlpha = ea
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "setScrollAlphaRule parse failed: $json", e)
        }
    }

    /**
     * 禁用滚动联动。toolbar 当前 alpha 保持不变,
     * 后续 WebView 滚动不再改变 toolbar alpha。
     * 若想恢复完全不透明,再调 [setAlpha](100)。
     */
    @JavascriptInterface
    fun disableScrollAlpha() {
        try {
            mainHandler.post {
                scrollAlphaController?.clearRule()
            }
        } catch (e: Exception) {
            Log.e(TAG, "disableScrollAlpha failed", e)
        }
    }

    /**
     * 应用渐变。
     * - colors 缺失 / 空数组 → 恢复默认背景
     * - colors 只有 1 个 → 复制成 2 个相同色
     * - direction 缺失 / 越界 → 默认 0(TOP_BOTTOM)
     */
    private fun applyGradient(toolbar: WebToolbar, obj: JSONObject) {
        val colorsArray = obj.optJSONArray(KEY_COLORS)

        // colors 缺失或为空 → 恢复默认
        if (colorsArray == null || colorsArray.length() == 0) {
            toolbar.resetBackground()
            return
        }

        val colors = mutableListOf<Int>()
        for (i in 0 until colorsArray.length()) {
            colors.add(colorsArray.getString(i).toColorInt())
        }

        // 只有 1 个色 → 复制成 2 个相同色(GradientDrawable 至少要 2 色)
        if (colors.size == 1) {
            colors.add(colors[0])
        }

        val directionInt = obj.optInt(KEY_DIRECTION, DEFAULT_DIRECTION)
        val orientation = parseOrientation(directionInt)
        val drawable = GradientDrawable(orientation, colors.toIntArray())
        toolbar.applyBackground(drawable)
    }

    /**
     * 整数索引 → GradientDrawable.Orientation 全部枚举值。
     * 与原生 enum ordinal 一一对应,无需查表。
     */
    private fun parseOrientation(index: Int): GradientDrawable.Orientation {
        val values = GradientDrawable.Orientation.entries.toTypedArray()
        return if (index in values.indices) {
            values[index]
        } else {
            GradientDrawable.Orientation.TOP_BOTTOM
        }
    }

    companion object {
        private const val TAG = "WebToolbarBridge"
        private const val KEY_COLORS = "colors"
        private const val KEY_DIRECTION = "direction"
        private const val DEFAULT_DIRECTION = 0
        private const val KEY_START_Y = "startY"
        private const val KEY_END_Y = "endY"
        private const val KEY_START_ALPHA = "startAlpha"
        private const val KEY_END_ALPHA = "endAlpha"
    }
}