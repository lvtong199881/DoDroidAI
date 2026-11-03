package com.example.dodroidai.ai.tools

import com.example.dodroidai.data.repository.MemoryRepository

/**
 * 记住用户信息（偏好、事实），后续对话会按需带入上下文
 */
@ToolProvider
object RememberFactTool {

    fun spec(): ToolSpec = ToolSpec(
        name = "remember_fact",
        description = "记住一条用户信息或偏好（例如称呼、城市、习惯），后续对话会自动参考；同一 key 会覆盖",
        parameters = ToolParameters(
            properties = mapOf(
                "key" to ToolProperty("string", "信息的键，例如 称呼、城市、偏好语言"),
                "value" to ToolProperty("string", "信息的値")
            ),
            required = listOf("key", "value")
        ),
        riskLevel = RiskLevel.LOW,
        execute = { ctx, args ->
            val key = args.requireString("key")
            val value = args.requireString("value")
            try {
                MemoryRepository(ctx.appContext).remember(key, value)
                ToolOutput("已记住：$key = $value")
            } catch (e: Exception) {
                ToolOutput("保存记忆失败: ${e.javaClass.simpleName}", isError = true)
            }
        }
    )
}
