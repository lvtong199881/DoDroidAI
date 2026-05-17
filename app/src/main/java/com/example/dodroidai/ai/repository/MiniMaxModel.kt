package com.example.dodroidai.ai.repository

import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.model.AIModel
import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ai.model.ChatMessage
import com.example.dodroidai.ai.model.ChatResponse
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
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

    private val json = Json { ignoreUnknownKeys = true }

    override suspend fun chat(messages: List<ChatMessage>): ChatResponse {
        val config = AIConfig.default(provider)
        return executeChat(config, messages)
    }

    fun executeChat(config: AIConfig, messages: List<ChatMessage>): ChatResponse {
        val requestBody = MiniMaxRequest(
            model = config.model,
            messages = messages.map { MiniMaxMessage(role = it.role, content = it.content) }
        )

        val request = Request.Builder()
            .url("${config.baseUrl}/v1/messages")
            .addHeader("Content-Type", "application/json")
            .addHeader("X-Api-Key", config.apiKey)
            .post(json.encodeToString(MiniMaxRequest.serializer(), requestBody).toRequestBody("application/json".toMediaType()))
            .build()

        val response = client.newCall(request).execute()
        val body = response.body?.string() ?: throw RuntimeException("Empty response")

        val jsonResponse = json.decodeFromString<JsonObject>(body)
        var content = ""

        jsonResponse["content"]?.let { contentElement ->
            if (contentElement is kotlinx.serialization.json.JsonArray) {
                contentElement.forEach { item ->
                    if (item is JsonObject) {
                        val textValue = item["text"]
                        if (textValue is kotlinx.serialization.json.JsonPrimitive) {
                            content = textValue.content
                            return@forEach
                        }
                    }
                }
            }
        }

        if (content.isEmpty()) {
            content = jsonResponse.toString()
        }

        return ChatResponse(
            content = content,
            provider = provider,
            model = config.model
        )
    }

    override fun getDefaultConfig(): AIConfig = AIConfig.default(provider)
}

@Serializable
private data class MiniMaxRequest(
    val model: String,
    val messages: List<MiniMaxMessage>
)

@Serializable
private data class MiniMaxMessage(
    val role: String,
    val content: String
)