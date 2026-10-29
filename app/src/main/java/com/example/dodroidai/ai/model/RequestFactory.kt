package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.tools.ToolDefinition
import com.example.dodroidai.util.GsonUtil
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

/**
 * 创建流式 SSE 请求。
 *
 * 消息已经由 [ChatRequestBuilder] 转换为 [AnthropicMessage]，这里只负责组装请求。
 */
fun createStreamingRequest(
    config: AIConfig,
    messages: List<AnthropicMessage>,
    tools: List<ToolDefinition>?
): Request {
    val requestBody = AnthropicRequestBody(
        model = config.model,
        messages = messages,
        tools = tools?.map { it.toAnthropicTool() },
        stream = true
    )
    val requestJson = GsonUtil.toJson(requestBody)

    val headers = listOf(
        "Content-Type" to "application/json",
        "X-Api-Key" to config.apiKey,
        "Accept" to "text/event-stream"
    )

    return Request.Builder()
        .url("${config.baseUrl}/v1/messages")
        .apply { headers.forEach { (n, v) -> addHeader(n, v) } }
        .post((requestJson ?: "{}").toRequestBody("application/json".toMediaType()))
        .build()
}

private fun ToolDefinition.toAnthropicTool(): AnthropicTool {
    return AnthropicTool(
        name = name,
        description = description,
        inputSchema = AnthropicInputSchema(
            type = "object",
            properties = parameters.properties.mapValues { (_, prop) ->
                AnthropicToolProperty(type = prop.type, description = prop.description)
            },
            required = parameters.required
        )
    )
}
