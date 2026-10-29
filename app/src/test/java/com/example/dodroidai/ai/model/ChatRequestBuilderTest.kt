package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.attachments.EncodedAttachment
import com.example.dodroidai.ai.attachments.PlaceholderReason
import com.google.gson.Gson
import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ChatRequestBuilderTest {

    private val gson = Gson()

    private fun chatMessage(
        role: String,
        content: String,
        timestamp: Long = 1L,
        attachments: List<ChatAttachment>? = null,
        toolCallId: String? = null
    ) = ChatMessage(
        role = role,
        content = content,
        timestamp = timestamp,
        attachments = attachments,
        toolCallId = toolCallId
    )

    @Test
    fun `plain text is sent as a string content`() {
        val result = ChatRequestBuilder.buildAnthropic(
            listOf(chatMessage(ChatMessage.ROLE_USER, "hello")),
            emptyMap()
        )

        assertEquals(1, result.size)
        assertTrue(result[0].content.isJsonPrimitive)
        assertEquals("hello", result[0].content.asString)
    }

    @Test
    fun `image attachment produces text label and image block`() {
        val encoded = mapOf(
            1L to listOf(
                EncodedAttachment.Image("photo.jpg", "image/jpeg", "ZmFrZQ==", 4)
            )
        )
        val result = ChatRequestBuilder.buildAnthropic(
            listOf(chatMessage(ChatMessage.ROLE_USER, "看图", 1L)),
            encoded
        )

        val blocks = result[0].content.asJsonArray
        assertEquals(3, blocks.size())
        assertEquals("text", blocks[0].asJsonObject.get("type").asString)
        assertEquals("看图", blocks[0].asJsonObject.get("text").asString)
        assertEquals("[图片：photo.jpg]", blocks[1].asJsonObject.get("text").asString)

        val image = blocks[2].asJsonObject
        assertEquals("image", image.get("type").asString)
        val source = image.getAsJsonObject("source")
        assertEquals("base64", source.get("type").asString)
        assertEquals("image/jpeg", source.get("media_type").asString)
        assertEquals("ZmFrZQ==", source.get("data").asString)
    }

    @Test
    fun `pdf text becomes a prefixed text block`() {
        val encoded = mapOf(
            1L to listOf(
                EncodedAttachment.Text("report.pdf", "第一行\n第二行", truncated = false, rawBytes = 20)
            )
        )
        val result = ChatRequestBuilder.buildAnthropic(
            listOf(chatMessage(ChatMessage.ROLE_USER, "", 1L)),
            encoded
        )

        val blocks = result[0].content.asJsonArray
        assertEquals(1, blocks.size())
        val text = blocks[0].asJsonObject.get("text").asString
        assertTrue(text.contains("report.pdf"))
        assertTrue(text.contains("第一行"))
    }

    @Test
    fun `placeholder becomes a readable text note`() {
        val encoded = mapOf(
            1L to listOf(
                EncodedAttachment.Placeholder("scan.pdf", PlaceholderReason.NO_TEXT)
            )
        )
        val result = ChatRequestBuilder.buildAnthropic(
            listOf(chatMessage(ChatMessage.ROLE_USER, "总结这个文件", 1L)),
            encoded
        )

        val blocks = result[0].content.asJsonArray
        assertEquals(2, blocks.size())
        val note = blocks[1].asJsonObject.get("text").asString
        assertTrue(note.contains("scan.pdf"))
        assertTrue(note.contains("no extractable text"))
    }

    @Test
    fun `tool result is structured and safely escaped`() {
        val content = "第一行 \"quoted\"\n第二行 \\ backslash"
        val result = ChatRequestBuilder.buildAnthropic(
            listOf(
                chatMessage(
                    role = ChatMessage.ROLE_TOOL,
                    content = content,
                    toolCallId = "call_123"
                )
            ),
            emptyMap()
        )

        assertEquals(1, result.size)
        assertEquals("user", result[0].role)

        // 序列化后再解析，确保内容被正确转义
        val json = gson.toJson(result[0].content)
        val block = JsonParser.parseString(json).asJsonArray[0].asJsonObject
        assertEquals("tool_result", block.get("type").asString)
        assertEquals("call_123", block.get("tool_use_id").asString)
        assertEquals(content, block.get("content").asString)
    }

    @Test
    fun `empty user message without attachments is dropped`() {
        val result = ChatRequestBuilder.buildAnthropic(
            listOf(
                chatMessage(ChatMessage.ROLE_USER, "   ", 1L),
                chatMessage(ChatMessage.ROLE_USER, "hello", 2L)
            ),
            emptyMap()
        )

        assertEquals(1, result.size)
        assertEquals("hello", result[0].content.asString)
    }
}
