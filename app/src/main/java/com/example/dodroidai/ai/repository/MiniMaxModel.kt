package com.example.dodroidai.ai.repository

import com.example.dodroidai.ai.model.AIModel
import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ai.model.ChatResponse
import com.example.dodroidai.ai.tools.ToolCall
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName

/**
 * MiniMax 模型响应解析
 */
class MiniMaxModel : AIModel {
    private val gson = Gson()

    override fun parseResponse(body: String): ChatResponse {
        val response = gson.fromJson(body, MiniMaxResponse::class.java)

        var content = ""
        val toolCalls = mutableListOf<ToolCall>()

        for (item in response.content) {
            when (item.type) {
                "text" -> content = item.text ?: ""
                "tool_use" -> {
                    val argumentsJson = gson.toJson(item.input)
                    toolCalls.add(
                        ToolCall(
                            id = item.toolUseId ?: "",
                            name = item.name ?: "",
                            arguments = argumentsJson
                        )
                    )
                }
            }
        }

        return ChatResponse(
            content = content,
            provider = AIProvider.MINIMAX,
            model = response.model,
            toolCalls = toolCalls
        )
    }
}

private data class MiniMaxResponse(
    @SerializedName("id")
    val id: String,
    @SerializedName("type")
    val type: String,
    @SerializedName("role")
    val role: String,
    @SerializedName("content")
    val content: List<MiniMaxContent>,
    @SerializedName("model")
    val model: String,
    @SerializedName("stop_reason")
    val stopReason: String?
)

private data class MiniMaxContent(
    @SerializedName("type")
    val type: String,
    @SerializedName("text")
    val text: String? = null,
    @SerializedName("tool_use_id")
    val toolUseId: String? = null,
    @SerializedName("name")
    val name: String? = null,
    @SerializedName("input")
    val input: Map<String, Any>? = null
)