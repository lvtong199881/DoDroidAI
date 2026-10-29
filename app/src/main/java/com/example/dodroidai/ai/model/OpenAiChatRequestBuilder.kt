package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.attachments.EncodedAttachment
import com.example.dodroidai.ai.tools.ToolDefinition
import com.google.gson.JsonArray
import com.google.gson.JsonNull
import com.google.gson.JsonObject

/**
 * 把 [ChatMessage] 转换为 OpenAI Chat Completions 请求体。
 *
 * 纯逻辑实现，不依赖 Android API，便于单元测试。
 */
object OpenAiChatRequestBuilder {

    fun buildBody(
        model: String,
        messages: List<ChatMessage>,
        encoded: Map<Long, List<EncodedAttachment>>,
        tools: List<ToolDefinition>?
    ): JsonObject {
        val body = JsonObject()
        body.addProperty("model", model)
        body.add("messages", JsonArray().apply {
            messages.forEach { message ->
                buildMessage(message, encoded[message.timestamp].orEmpty())?.let { add(it) }
            }
        })
        if (!tools.isNullOrEmpty()) {
            body.add("tools", JsonArray().apply {
                tools.forEach { add(it.toOpenAiTool()) }
            })
        }
        body.addProperty("stream", true)
        return body
    }

    private fun buildMessage(
        message: ChatMessage,
        attachments: List<EncodedAttachment>
    ): JsonObject? = when (message.role) {
        ChatMessage.ROLE_USER -> buildUserMessage(message, attachments)
        ChatMessage.ROLE_ASSISTANT -> buildAssistantMessage(message)
        ChatMessage.ROLE_TOOL -> buildToolMessage(message)
        else -> null
    }

    private fun buildUserMessage(
        message: ChatMessage,
        attachments: List<EncodedAttachment>
    ): JsonObject? {
        val text = message.content.trim()
        if (text.isEmpty() && attachments.isEmpty()) return null

        val json = JsonObject().apply { addProperty("role", "user") }
        if (attachments.isEmpty()) {
            json.addProperty("content", message.content)
            return json
        }

        json.add("content", JsonArray().apply {
            if (text.isNotEmpty()) add(textPart(text))
            attachments.forEach { attachment ->
                when (attachment) {
                    is EncodedAttachment.Image -> {
                        add(textPart("[图片：${attachment.label}]"))
                        add(imagePart(attachment))
                    }
                    is EncodedAttachment.Text -> add(textPart(documentTextBlock(attachment)))
                    is EncodedAttachment.Placeholder -> add(textPart(placeholderText(attachment)))
                }
            }
        })
        return json
    }

    private fun buildAssistantMessage(message: ChatMessage): JsonObject? {
        val toolCalls = message.toolCallPayloads.orEmpty()
        if (message.content.isBlank() && toolCalls.isEmpty()) return null

        val json = JsonObject().apply { addProperty("role", "assistant") }
        if (message.content.isBlank()) {
            json.add("content", JsonNull.INSTANCE)
        } else {
            json.addProperty("content", message.content)
        }

        if (toolCalls.isNotEmpty()) {
            json.add("tool_calls", JsonArray().apply {
                toolCalls.forEach { toolCall ->
                    add(JsonObject().apply {
                        addProperty("id", toolCall.id)
                        addProperty("type", "function")
                        add("function", JsonObject().apply {
                            addProperty("name", toolCall.name)
                            addProperty("arguments", toolCall.arguments)
                        })
                    })
                }
            })
        }
        return json
    }

    private fun buildToolMessage(message: ChatMessage): JsonObject? {
        val toolCallId = message.toolCallId
        if (toolCallId.isNullOrBlank()) return null
        return JsonObject().apply {
            addProperty("role", "tool")
            addProperty("tool_call_id", toolCallId)
            addProperty("content", message.content)
        }
    }

    private fun textPart(text: String): JsonObject = JsonObject().apply {
        addProperty("type", "text")
        addProperty("text", text)
    }

    private fun imagePart(image: EncodedAttachment.Image): JsonObject = JsonObject().apply {
        addProperty("type", "image_url")
        add("image_url", JsonObject().apply {
            addProperty("url", "data:${image.mediaType};base64,${image.base64}")
        })
    }

    private fun documentTextBlock(text: EncodedAttachment.Text): String {
        val suffix = if (text.truncated) "\n（内容过长，已截断）" else ""
        return "以下是附件 \"${text.label}\" 的文本内容：\n${text.text}$suffix"
    }

    private fun placeholderText(placeholder: EncodedAttachment.Placeholder): String {
        return "[附件 \"${placeholder.label}\" 未随本次请求发送：${placeholder.reason.description}]"
    }

    private fun ToolDefinition.toOpenAiTool(): JsonObject = JsonObject().apply {
        addProperty("type", "function")
        add("function", JsonObject().apply {
            addProperty("name", name)
            addProperty("description", description)
            add("parameters", JsonObject().apply {
                addProperty("type", "object")
                add("properties", JsonObject().apply {
                    parameters.properties.forEach { (key, property) ->
                        add(key, JsonObject().apply {
                            addProperty("type", property.type)
                            addProperty("description", property.description)
                        })
                    }
                })
                add("required", JsonArray().apply {
                    parameters.required.forEach { add(it) }
                })
            })
        })
    }
}
