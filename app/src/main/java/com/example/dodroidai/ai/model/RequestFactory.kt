package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.tools.ToolDefinition
import com.example.dodroidai.util.GsonUtil
import com.google.gson.JsonObject
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

/**
 * Anthropic Messages 请求。
 */
fun createAnthropicRequest(
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

    return Request.Builder()
        .url(ApiEndpoint.anthropicMessagesUrl(config.baseUrl))
        .addHeader("Content-Type", "application/json")
        .addHeader("X-Api-Key", config.apiKey)
        .addHeader("Accept", "text/event-stream")
        .post((requestJson ?: "{}").toRequestBody("application/json".toMediaType()))
        .build()
}

/**
 * OpenAI Chat Completions 请求。
 */
fun createOpenAiRequest(
    config: AIConfig,
    body: JsonObject,
    sessionId: String? = null
): Request {
    val requestJson = GsonUtil.toJson(body)
    return Request.Builder()
        .url(ApiEndpoint.openAiChatCompletionsUrl(config.baseUrl))
        .addHeader("Content-Type", "application/json")
        .addHeader("Authorization", "Bearer ${config.apiKey}")
        .addHeader("Accept", "text/event-stream")
        .apply {
            // OpenCode Go 要求稳定的会话 ID 用于路由与 prompt cache
            if (!sessionId.isNullOrBlank()) {
                addHeader("x-opencode-session", sessionId)
            }
        }
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
