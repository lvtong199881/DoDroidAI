package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.tools.ToolDefinition
import com.google.gson.Gson
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

/**
 * 根据 AIConfig 的 apiFormat 创建对应的 Request
 */
fun createRequest(
    config: AIConfig,
    messages: List<ChatMessage>,
    tools: List<ToolDefinition>?
): Request {
    val gson = Gson()
    val requestBody = createRequestBody(config, messages, tools)
    val requestJson = gson.toJson(requestBody)

    val url = when (config.apiFormat) {
        ApiFormat.ANTHROPIC_MESSAGES -> "${config.baseUrl}/v1/messages"
    }

    val headers = when (config.apiFormat) {
        ApiFormat.ANTHROPIC_MESSAGES -> listOf(
            "Content-Type" to "application/json",
            "X-Api-Key" to config.apiKey
        )
    }

    return Request.Builder()
        .url(url)
        .apply {
            headers.forEach { (name, value) ->
                addHeader(name, value)
            }
        }
        .post(requestJson.toRequestBody("application/json".toMediaType()))
        .build()
}

fun createRequestBody(
    config: AIConfig,
    messages: List<ChatMessage>,
    tools: List<ToolDefinition>?
): Any {
    return when (config.apiFormat) {
        ApiFormat.ANTHROPIC_MESSAGES -> createAnthropicRequest(config, messages, tools)
    }
}

private fun createAnthropicRequest(
    config: AIConfig,
    messages: List<ChatMessage>,
    tools: List<ToolDefinition>?
): AnthropicRequestBody {
    return AnthropicRequestBody(
        model = config.model,
        messages = messages.map { it.toAnthropicMessage() },
        tools = tools?.map { it.toAnthropicTool() }
    )
}

private fun ChatMessage.toAnthropicMessage(): AnthropicMessage {
    return AnthropicMessage(
        role = role,
        content = content,
        toolCallId = toolCallId
    )
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