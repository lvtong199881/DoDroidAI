package com.example.dodroidai.ai.tools

import android.app.Activity
import android.content.Context
import com.example.dodroidai.util.GsonUtil

/**
 * 添加笔记工具（当前为占位实现）
 */
class AddNoteTool : Tool {
    /** 工具名称 */
    override val name = "add_note"

    /** 无需权限 */
    override val requiredPermissions = emptyList<String>()

    /** 风险等级高 */
    override val riskLevel = RiskLevel.HIGH

    override fun hasPermissions(context: Context): Boolean = true

    override fun requestPermissions(activity: Activity, callback: (Boolean) -> Unit) {
        callback(true)
    }

    override fun execute(context: Context, arguments: String): ToolResult {
        val args = parseArgs(arguments) ?: return failure("参数解析失败")

        // TODO: 实现实际的笔记添加逻辑
        // 当前为占位实现，后续可接入笔记应用
        return ToolResult(
            toolCallId = "",
            toolName = name,
            success = true,
            result = "笔记已添加: ${args.title}"
        )
    }

    private fun failure(error: String): ToolResult {
        return ToolResult(
            toolCallId = "",
            toolName = name,
            success = false,
            result = "",
            error = error
        )
    }

    private data class Args(val title: String, val content: String)

    private fun parseArgs(json: String): Args? {
        return try {
            GsonUtil.fromJson(json, Args::class.java)
        } catch (e: Exception) {
            null
        }
    }
}