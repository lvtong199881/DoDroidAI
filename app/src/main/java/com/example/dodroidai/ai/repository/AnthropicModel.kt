package com.example.dodroidai.ai.repository

import com.example.dodroidai.ai.model.AIModel
import com.example.dodroidai.ai.model.AIProvider
import com.example.dodroidai.ai.model.ChatResponse
import com.example.dodroidai.ai.model.ContentType
import com.example.dodroidai.ai.tools.ToolCall
import com.example.dodroidai.util.GsonUtil

/**
 * Anthropic 兼容 API 模型响应解析
 */
class AnthropicModel : AIModel {

    override fun parseResponse(body: String): ChatResponse {
        val response = GsonUtil.fromJson(body, com.example.dodroidai.ai.model.AnthropicResponse::class.java)
            ?: return ChatResponse(
                content = "",
                provider = AIProvider.DEEPSEEK,
                model = "",
                toolCalls = emptyList(),
                reasoningContent = null
            )

        var content = ""
        var reasoningContent: String? = null
        val toolCalls = mutableListOf<ToolCall>()

        for (item in response.content) {
            when (item.type) {
                ContentType.TEXT.value -> content = item.text ?: ""
                ContentType.TOOL_USE.value -> {
                    val argumentsJson = GsonUtil.toJson(item.input ?: emptyMap<String, Any>()) ?: "{}"
                    toolCalls.add(
                        ToolCall(
                            id = item.toolUseId ?: "",
                            name = item.name ?: "",
                            arguments = argumentsJson
                        )
                    )
                }
                ContentType.THINKING.value -> reasoningContent = item.thinking
            }
        }

        return ChatResponse(
            content = content,
            provider = AIProvider.DEEPSEEK,
            model = response.model,
            toolCalls = toolCalls,
            reasoningContent = reasoningContent
        )
    }
}