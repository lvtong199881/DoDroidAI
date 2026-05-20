package com.example.dodroidai.ai.repository

import com.example.dodroidai.ai.model.AIModel
import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ai.model.ChatResponse
import com.example.dodroidai.ai.tools.ToolCall
import com.example.dodroidai.util.GsonUtil
import com.google.gson.annotations.SerializedName

/**
 * OpenAI 模型响应解析
 */
class OpenAIModel : AIModel {

    override fun parseResponse(body: String): ChatResponse {
        val response = GsonUtil.fromJson(body, OpenAIResponse::class.java)
            ?: return ChatResponse(
                content = "",
                provider = AIProvider.OPENAI,
                model = "",
                toolCalls = emptyList(),
                reasoningContent = null
            )

        val message = response.choices.firstOrNull()?.message
        val toolCalls = message?.toolCalls?.map { tc ->
            ToolCall(
                id = tc.id,
                name = tc.name,
                arguments = GsonUtil.toJson(tc.input) ?: "{}"
            )
        } ?: emptyList()

        return ChatResponse(
            content = message?.content ?: "",
            provider = AIProvider.OPENAI,
            model = response.model,
            toolCalls = toolCalls,
            reasoningContent = message?.reasoning
        )
    }
}

private data class OpenAIResponse(
    @SerializedName("id")
    val id: String,
    @SerializedName("model")
    val model: String,
    @SerializedName("choices")
    val choices: List<OpenAIChoice>
)

private data class OpenAIChoice(
    @SerializedName("message")
    val message: OpenAIMessage
)

private data class OpenAIMessage(
    @SerializedName("content")
    val content: String?,
    @SerializedName("tool_calls")
    val toolCalls: List<OpenAIToolCall>?,
    @SerializedName("reasoning")
    val reasoning: String? = null
)

private data class OpenAIToolCall(
    @SerializedName("id")
    val id: String,
    @SerializedName("name")
    val name: String,
    @SerializedName("input")
    val input: Map<String, Any>
)