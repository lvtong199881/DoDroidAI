package com.example.dodroidai.ai.tools

import com.example.dodroidai.data.repository.NoteRepository

/**
 * 添加笔记工具（写入本地 Room 数据库）
 */
@ToolProvider
object AddNoteTool {

    fun spec(): ToolSpec = ToolSpec(
        name = "add_note",
        description = "添加一条笔记并保存在本地，用户可以在设置 → 笔记中查看",
        parameters = ToolParameters(
            properties = mapOf(
                "title" to ToolProperty("string", "笔记标题"),
                "content" to ToolProperty("string", "笔记内容")
            ),
            required = listOf("title", "content")
        ),
        riskLevel = RiskLevel.HIGH,
        execute = { ctx, args ->
            val title = args.requireString("title")
            val content = args.requireString("content")
            try {
                val id = NoteRepository(ctx.appContext).add(title, content)
                ToolOutput("笔记已保存（#${id}）: $title")
            } catch (e: Exception) {
                android.util.Log.e("AddNoteTool", "save failed: ${e.javaClass.simpleName}")
                ToolOutput("保存笔记失败: ${e.message}", isError = true)
            }
        }
    )
}
