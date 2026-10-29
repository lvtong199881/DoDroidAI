package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.attachments.EncodedAttachment
import com.example.dodroidai.ai.tools.ToolCall
import com.example.dodroidai.ai.tools.ToolDefinition
import com.example.dodroidai.ai.tools.ToolParameters
import com.example.dodroidai.ai.tools.ToolProperty
import com.google.gson.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OpenAiChatRequestBuilderTest {

    private fun chatMessage(
        role: String,
        content: String,
        timestamp: Long = 1L,
        attachments: List<ChatAttachment>? = null,
        toolCallId: String? = null,
        toolCallPayloads: List<ToolCall>? = null
    ) = ChatMessage(
        role = role,
        content = content,
        timestamp = timestamp,
        attachments = attachments,
        toolCallId = toolCallId,
        toolCallPayloads = toolCallPayloads
    )

    private fun body(
        messages: List<ChatMessage>,
        encoded: Map<Long, List<EncodedAttachment>> = emptyMap(),
        tools: List<ToolDefinition>? = null
    ): JsonObject = OpenAiChatRequestBuilder.buildBody(
        model = "gpt-4o",
        messages = messages,
        encoded = encoded,
        tools = tools
    )

    @Test
    fun `text message uses string content`() {
        val json = body(listOf(chatMessage(ChatMessage.ROLE_USER, "hello")))
        assertEquals("gpt-4o", json.get("model").asString)
        assertTrue(json.get("stream").asBoolean)
        val message = json.getAsJsonArray("messages")[0].asJsonObject
        assertEquals("user", message.get("role").asString)
        assertEquals("hello", message.get("content").asString)
    }

    @Test
    fun `image uses image url data url`() {
        val encoded = mapOf(
            1L to listOf(
                EncodedAttachment.Image("photo.jpg", "image/jpeg", "ZmFrZQ==", 4)
            )
        )
        val json = body(listOf(chatMessage(ChatMessage.ROLE_USER, "看图", 1L)), encoded)
        val content = json.getAsJsonArray("messages")[0]
            .asJsonObject
            .getAsJsonArray("content")

        val imagePart = content.first {
            it.asJsonObject.get("type").asString == "image_url"
        }.asJsonObject
        val url = imagePart.getAsJsonObject("image_url").get("url").asString
        assertEquals("data:image/jpeg;base64,ZmFrZQ==", url)
    }

    @Test
    fun `tools use function schema`() {
        val tools = listOf(
            ToolDefinition(
                name = "set_alarm",
                description = "设置闹钟",
                parameters = ToolParameters(
                    properties = mapOf(
                        "hour" to ToolProperty("integer", "小时")
                    ),
                    required = listOf("hour")
                )
            )
        )
        val json = body(listOf(chatMessage(ChatMessage.ROLE_USER, "定闹钟")), tools = tools)
        val tool = json.getAsJsonArray("tools")[0].asJsonObject
        assertEquals("function", tool.get("type").asString)
        val function = tool.getAsJsonObject("function")
        assertEquals("set_alarm", function.get("name").asString)
        val parameters = function.getAsJsonObject("parameters")
        assertEquals("object", parameters.get("type").asString)
        assertEquals(
            "integer",
            parameters.getAsJsonObject("properties").getAsJsonObject("hour").get("type").asString
        )
        assertEquals("hour", parameters.getAsJsonArray("required")[0].asString)
    }

    @Test
    fun `tool result uses tool call id`() {
        val json = body(
            listOf(
                chatMessage(
                    role = ChatMessage.ROLE_TOOL,
                    content = "ok",
                    toolCallId = "call_1"
                )
            )
        )
        val message = json.getAsJsonArray("messages")[0].asJsonObject
        assertEquals("tool", message.get("role").asString)
        assertEquals("call_1", message.get("tool_call_id").asString)
        assertEquals("ok", message.get("content").asString)
    }

    @Test
    fun `assistant tool calls carry tool_calls and null content`() {
        val json = body(
            listOf(
                chatMessage(
                    role = ChatMessage.ROLE_ASSISTANT,
                    content = "",
                    toolCallPayloads = listOf(
                        ToolCall("call_1", "get_current_time", "{}")
                    )
                )
            )
        )
        val message = json.getAsJsonArray("messages")[0].asJsonObject
        assertEquals("assistant", message.get("role").asString)
        assertTrue(message.get("content").isJsonNull)

        val toolCall = message.getAsJsonArray("tool_calls")[0].asJsonObject
        assertEquals("call_1", toolCall.get("id").asString)
        assertEquals("function", toolCall.get("type").asString)
        assertEquals(
            "get_current_time",
            toolCall.getAsJsonObject("function").get("name").asString
        )
    }

    @Test
    fun `assistant without tool calls uses string content`() {
        val json = body(
            listOf(chatMessage(ChatMessage.ROLE_ASSISTANT, "你好"))
        )
        val message = json.getAsJsonArray("messages")[0].asJsonObject
        assertEquals("你好", message.get("content").asString)
        assertNotNull(message.get("role"))
    }
}
