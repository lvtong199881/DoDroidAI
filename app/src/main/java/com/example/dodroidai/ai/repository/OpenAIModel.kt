package com.example.dodroidai.ai.repository

import com.example.dodroidai.ai.config.AIConfig
import com.example.dodroidai.ai.model.AIModel
import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ai.model.ChatMessage
import com.example.dodroidai.ai.model.ChatRequestBody
import com.example.dodroidai.ai.model.ChatResponse
import com.example.dodroidai.ai.model.ChatResponseBody
import com.example.dodroidai.ai.tools.ToolDefinition
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

/**
 * OpenAI 模型实现
 */
class OpenAIModel : AIModel {
    override val provider: AIProvider = AIProvider.OPENAI

    private val client = OkHttpClient.Builder()
        .connectTimeout(30L, TimeUnit.SECONDS)
        .readTimeout(120L, TimeUnit.SECONDS)
        .build()

    private val json = Json { ignoreUnknownKeys = true }

    override suspend fun chat(messages: List<ChatMessage>): ChatResponse {
        val config = AIConfig.default(provider)
        return executeChat(config, messages)
    }

    fun executeChat(config: AIConfig, messages: List<ChatMessage>, tools: List<ToolDefinition>? = null): ChatResponse {
        val requestBody = ChatRequestBody(
            model = config.model,
            messages = messages,
            tools = tools
        )

        val request = Request.Builder()
            .url("${config.baseUrl}/chat/completions")
            .addHeader("Content-Type", "application/json")
            .addHeader("Authorization", "Bearer ${config.apiKey}")
            .post(json.encodeToString(ChatRequestBody.serializer(), requestBody)
                .toRequestBody("application/json".toMediaType()))
            .build()

        val response = client.newCall(request).execute()
        val body = response.body?.string() ?: throw RuntimeException("Empty response")

        val chatResponse = json.decodeFromString<ChatResponseBody>(body)
        val message = chatResponse.choices.firstOrNull()?.message
        return ChatResponse(
            content = message?.content ?: "",
            provider = provider,
            model = chatResponse.model,
            toolCalls = message?.toolCalls ?: emptyList()
        )
    }

    override fun getDefaultConfig(): AIConfig = AIConfig.default(provider)
}