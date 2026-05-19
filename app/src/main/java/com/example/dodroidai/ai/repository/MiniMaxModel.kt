package com.example.dodroidai.ai.repository

import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.model.AIModel
import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ai.model.ChatMessage
import com.example.dodroidai.ai.model.ChatResponse
import com.example.dodroidai.ai.tools.ToolCall
import com.example.dodroidai.ai.tools.ToolDefinition
import kotlinx.serialization.SerialName
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

/**
 * MiniMax 模型实现，使用 Anthropic 兼容协议
 */
class MiniMaxModel : AIModel {
    override val provider: AIProvider = AIProvider.MINIMAX

    private val client = OkHttpClient.Builder()
        .connectTimeout(30L, TimeUnit.SECONDS)
        .readTimeout(120L, TimeUnit.SECONDS)
        .build()

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    override suspend fun chat(messages: List<ChatMessage>): ChatResponse {
        val config = AIConfig.default(provider)
        return executeChat(config, messages)
    }

    fun executeChat(config: AIConfig, messages: List<ChatMessage>, tools: List<ToolDefinition>? = null): ChatResponse {
        val url = "${config.baseUrl}/v1/messages"
        android.util.Log.d("MiniMaxModel", "Request URL: $url, model: ${config.model}")

        val requestBody = MiniMaxRequest(
            model = config.model,
            messages = messages.map {
                MiniMaxMessage(
                    role = it.role,
                    content = it.content,
                    toolCallId = it.toolCallId
                )
            },
            tools = tools?.map { it.toAnthropicTool() }
        )

        val requestJson = json.encodeToString(requestBody)
        android.util.Log.d("MiniMaxModel", "Request body: $requestJson")

        // 打印 tool 消息的详情
        val toolMessages = messages.filter { it.role == "tool" }
        if (toolMessages.isNotEmpty()) {
            android.util.Log.d("MiniMaxModel", "Tool messages count: ${toolMessages.size}")
            toolMessages.forEachIndexed { index, msg ->
                android.util.Log.d("MiniMaxModel", "Tool[$index]: role=${msg.role}, content=${msg.content}, toolCallId=${msg.toolCallId}, toolCallId in MiniMaxMessage will be=${msg.toolCallId}")
            }
        }

        val request = Request.Builder()
            .url(url)
            .addHeader("Content-Type", "application/json")
            .addHeader("X-Api-Key", config.apiKey)
            .post(requestJson.toRequestBody("application/json".toMediaType()))
            .build()

        val response = client.newCall(request).execute()
        val body = response.body?.string() ?: throw RuntimeException("Empty response")
        android.util.Log.d("MiniMaxModel", "Response body: $body")

        val jsonResponse = json.decodeFromString<JsonObject>(body)

        // 解析 content（可能是文本或工具调用）
        var content = ""
        val toolCalls = mutableListOf<ToolCall>()

        jsonResponse["content"]?.let { contentElement ->
            if (contentElement is JsonArray) {
                for (item in contentElement) {
                    if (item is JsonObject) {
                        when (item["type"]?.toString()) {
                            "\"text\"" -> {
                                val textValue = item["text"]
                                if (textValue is JsonPrimitive) {
                                    content = textValue.content
                                }
                            }
                            "\"tool_use\"" -> {
                                val toolCall = parseToolCall(item)
                                if (toolCall != null) {
                                    toolCalls.add(toolCall)
                                }
                            }
                        }
                    }
                }
            }
        }

        // 如果没有文本内容，显示原始响应（调试用）
        if (content.isEmpty() && toolCalls.isEmpty()) {
            content = jsonResponse.toString()
        }

        return ChatResponse(
            content = content,
            provider = provider,
            model = config.model,
            toolCalls = toolCalls
        )
    }

    private fun parseToolCall(item: JsonObject): ToolCall? {
        val id = item["id"]?.toString()?.removeSurrounding("\"") ?: return null
        val name = item["name"]?.toString()?.removeSurrounding("\"") ?: return null
        val input = item["input"] as? JsonObject ?: return null
        val arguments = json.encodeToString(JsonObject.serializer(), input)
        return ToolCall(id = id, name = name, arguments = arguments)
    }

    override fun getDefaultConfig(): AIConfig = AIConfig.default(provider)
}

private data class MiniMaxRequest(
    val model: String,
    val messages: List<MiniMaxMessage>,
    val tools: List<AnthropicTool>? = null
)

private data class MiniMaxMessage(
    val role: String,
    val content: String,
    @SerialName("tool_call_id")
    val toolCallId: String? = null
)

private data class AnthropicTool(
    val name: String,
    val description: String,
    val input_schema: AnthropicInputSchema
)

private data class AnthropicInputSchema(
    val type: String = "object",
    val properties: Map<String, AnthropicToolProperty> = emptyMap(),
    val required: List<String> = emptyList()
)

private data class AnthropicToolProperty(
    val type: String,
    val description: String
)

// 扩展函数：将 ToolDefinition 转换为 Anthropic 格式
private fun ToolDefinition.toAnthropicTool(): AnthropicTool {
    return AnthropicTool(
        name = this.name,
        description = this.description,
        input_schema = AnthropicInputSchema(
            type = "object",
            properties = this.parameters.properties.mapValues { (_, prop) ->
                AnthropicToolProperty(type = prop.type, description = prop.description)
            },
            required = this.parameters.required
        )
    )
}