package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.tools.ToolDefinition
import com.example.dodroidai.ai.model.ChatMessage.Companion.ROLE_TOOL
import com.example.dodroidai.util.GsonUtil
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

/**
 * 创建流式 SSE 请求
 */
fun createStreamingRequest(
    config: AIConfig,
    messages: List<ChatMessage>,
    tools: List<ToolDefinition>?
): Request {
    val requestBody = createRequestBody(config, messages, tools)
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

private fun createRequestBody(
    config: AIConfig,
    messages: List<ChatMessage>,
    tools: List<ToolDefinition>?
): AnthropicRequestBody {
    return AnthropicRequestBody(
        model = config.model,
        messages = messages.map { it.toAnthropicMessage() },
        tools = tools?.map { it.toAnthropicTool() },
        stream = true
    )
}

private fun ChatMessage.toAnthropicMessage(): AnthropicMessage {
    return if (role == ROLE_TOOL) {
        // tool 角色的消息需要使用 tool_result 格式，role 改为 user
        AnthropicMessage(
            role = "user",
            content = "[{\"type\":\"tool_result\",\"tool_use_id\":\"$toolCallId\",\"content\":\"$content\"}]",
            toolCallId = null
        )
    } else {
        AnthropicMessage(
            role = role,
            content = content,
            toolCallId = toolCallId
        )
    }
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
