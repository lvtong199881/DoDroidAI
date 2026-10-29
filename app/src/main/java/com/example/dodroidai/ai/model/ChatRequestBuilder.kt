package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.attachments.EncodedAttachment
import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonPrimitive

/**
 * 把 [ChatMessage] 转换为 Anthropic Messages 请求体。
 *
 * 该对象是纯逻辑（不依赖 Android API），便于单元测试。
 */
object ChatRequestBuilder {

    /**
     * @param messages 参与本次请求的消息（通常已裁剪到最近 N 条）
     * @param encoded  以 `message.timestamp` 为 key 的附件编码结果
     */
    fun build(
        messages: List<ChatMessage>,
        encoded: Map<Long, List<EncodedAttachment>>
    ): List<AnthropicMessage> {
        return messages.mapNotNull { message ->
            when (message.role) {
                ChatMessage.ROLE_USER -> buildUserMessage(message, encoded[message.timestamp].orEmpty())
                ChatMessage.ROLE_TOOL -> buildToolMessage(message)
                ChatMessage.ROLE_ASSISTANT -> buildAssistantMessage(message)
                else -> null
            }
        }
    }

    private fun buildUserMessage(
        message: ChatMessage,
        attachments: List<EncodedAttachment>
    ): AnthropicMessage? {
        val text = message.content.trim()
        if (text.isEmpty() && attachments.isEmpty()) return null

        // 纯文本消息保持字符串形式，节省请求体积。
        if (attachments.isEmpty()) {
            return AnthropicMessage(role = "user", content = JsonPrimitive(message.content))
        }

        val blocks = JsonArray()
        if (text.isNotEmpty()) {
            blocks.add(textBlock(text))
        }
        attachments.forEach { attachment ->
            when (attachment) {
                is EncodedAttachment.Image -> {
                    blocks.add(textBlock("[图片：${attachment.label}]"))
                    blocks.add(imageBlock(attachment))
                }
                is EncodedAttachment.Text -> blocks.add(textBlock(documentTextBlock(attachment)))
                is EncodedAttachment.Placeholder -> blocks.add(textBlock(placeholderText(attachment)))
            }
        }
        return AnthropicMessage(role = "user", content = blocks)
    }

    private fun buildAssistantMessage(message: ChatMessage): AnthropicMessage? {
        if (message.content.isBlank()) return null
        return AnthropicMessage(role = "assistant", content = JsonPrimitive(message.content))
    }

    private fun buildToolMessage(message: ChatMessage): AnthropicMessage {
        val block = JsonObject().apply {
            addProperty("type", "tool_result")
            addProperty("tool_use_id", message.toolCallId.orEmpty())
            addProperty("content", message.content)
        }
        val content: JsonElement = JsonArray().apply { add(block) }
        return AnthropicMessage(role = "user", content = content)
    }

    private fun textBlock(text: String): JsonObject = JsonObject().apply {
        addProperty("type", "text")
        addProperty("text", text)
    }

    private fun imageBlock(image: EncodedAttachment.Image): JsonObject = JsonObject().apply {
        addProperty("type", "image")
        add("source", JsonObject().apply {
            addProperty("type", "base64")
            addProperty("media_type", image.mediaType)
            addProperty("data", image.base64)
        })
    }

    private fun documentTextBlock(text: EncodedAttachment.Text): String {
        val suffix = if (text.truncated) "\n（内容过长，已截断）" else ""
        return "以下是附件 \"${text.label}\" 的文本内容：\n${text.text}$suffix"
    }

    private fun placeholderText(placeholder: EncodedAttachment.Placeholder): String {
        return "[附件 \"${placeholder.label}\" 未随本次请求发送：${placeholder.reason.description}]"
    }
}
