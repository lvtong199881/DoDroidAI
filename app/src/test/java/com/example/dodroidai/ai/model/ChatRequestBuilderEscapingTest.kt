package com.example.dodroidai.ai.model

import com.google.gson.Gson
import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class ChatRequestBuilderEscapingTest {

    @Test
    fun `tool result with special characters stays valid json`() {
        val payload = "line1\nline2 \"quoted\" \\ backslash 中文 😀"
        val messages = listOf(
            ChatMessage(
                role = ChatMessage.ROLE_TOOL,
                content = payload,
                toolCallId = "call_1"
            )
        )

        val result = ChatRequestBuilder.buildAnthropic(messages, emptyMap())
        val json = Gson().toJson(result)
        val parsed = JsonParser.parseString(json).asJsonArray

        val block = parsed[0]
            .asJsonObject
            .getAsJsonArray("content")[0]
            .asJsonObject

        assertEquals("tool_result", block.get("type").asString)
        assertEquals("call_1", block.get("tool_use_id").asString)
        assertEquals(payload, block.get("content").asString)
    }

    @Test
    fun `tool result is not double escaped`() {
        val payload = "a\"b"
        val result = ChatRequestBuilder.buildAnthropic(
            listOf(
                ChatMessage(
                    role = ChatMessage.ROLE_TOOL,
                    content = payload,
                    toolCallId = "call_2"
                )
            ),
            emptyMap()
        )
        val block = JsonParser.parseString(Gson().toJson(result))
            .asJsonArray[0]
            .asJsonObject
            .getAsJsonArray("content")[0]
            .asJsonObject

        assertNotEquals("a\\\"b", block.get("content").asString)
        assertEquals(payload, block.get("content").asString)
    }
}
