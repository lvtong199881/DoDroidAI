package com.example.dodroidai.ai.tools

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context

/**
 * 读取剪贴板文本（可能含敏感信息，走高风险确认）
 */
@ToolProvider
object ReadClipboardTool {

    fun spec(): ToolSpec = ToolSpec(
        name = "read_clipboard",
        description = "读取剪贴板中的文本，可能包含用户复制的敏感信息",
        parameters = ToolParameters(properties = emptyMap(), required = emptyList()),
        riskLevel = RiskLevel.HIGH,
        execute = { ctx, _ ->
            try {
                val manager = ctx.appContext.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                val clip = manager.primaryClip
                val text = if (clip == null || clip.itemCount == 0) {
                    null
                } else {
                    clip.getItemAt(0).coerceToText(ctx.appContext)?.toString()
                }
                if (text.isNullOrBlank()) {
                    ToolOutput("剪贴板为空")
                } else {
                    ToolOutput(text.take(2000))
                }
            } catch (e: Exception) {
                ToolOutput("读取剪贴板失败: ${e.javaClass.simpleName}", isError = true)
            }
        }
    )
}

/**
 * 写入剪贴板
 */
@ToolProvider
object WriteClipboardTool {

    fun spec(): ToolSpec = ToolSpec(
        name = "write_clipboard",
        description = "把文本复制到剪贴板",
        parameters = ToolParameters(
            properties = mapOf("text" to ToolProperty("string", "要复制的文本")),
            required = listOf("text")
        ),
        riskLevel = RiskLevel.MEDIUM,
        execute = { ctx, args ->
            val text = args.requireString("text")
            try {
                val manager = ctx.appContext.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                manager.setPrimaryClip(ClipData.newPlainText("DoDroidAI", text))
                ToolOutput("已复制到剪贴板")
            } catch (e: Exception) {
                ToolOutput("写入剪贴板失败: ${e.javaClass.simpleName}", isError = true)
            }
        }
    )
}
