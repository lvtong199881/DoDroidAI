package com.example.dodroidai.ai.tools

/**
 * 添加笔记工具（当前为占位实现）
 */
@ToolProvider
object AddNoteTool {

    fun spec(): ToolSpec = ToolSpec(
        name = "add_note",
        description = "添加一条笔记",
        parameters = ToolParameters(
            properties = mapOf(
                "title" to ToolProperty("string", "笔记标题"),
                "content" to ToolProperty("string", "笔记内容")
            ),
            required = listOf("title", "content")
        ),
        riskLevel = RiskLevel.HIGH,
        execute = { _, args ->
            val title = args.requireString("title")
            args.requireString("content")
            // TODO: 实现真正的笔记写入；当前仅回显，避免模型误以为已持久化
            ToolOutput("笔记已添加: $title")
        }
    )
}
