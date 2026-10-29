package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.config.AIConfig
import com.google.gson.JsonParser
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RequestFactoryTest {

    private fun config() = AIConfig(
        provider = AIProvider.CUSTOM,
        apiKey = "test-key",
        baseUrl = "https://example.com",
        model = "test-model"
    )

    @Test
    fun `request contains url headers and text content`() {
        val request = createAnthropicRequest(
            config = config(),
            messages = listOf(
                AnthropicMessage(role = "user", content = com.google.gson.JsonPrimitive("hi"))
            ),
            tools = null
        )

        assertEquals("https://example.com/v1/messages", request.url.toString())
        assertEquals("test-key", request.header("X-Api-Key"))
        assertEquals("text/event-stream", request.header("Accept"))

        val body = request.body ?: error("request body is null")
        val buffer = Buffer()
        body.writeTo(buffer)
        val json = JsonParser.parseString(buffer.readUtf8()).asJsonObject

        assertEquals("test-model", json.get("model").asString)
        assertTrue(json.get("stream").asBoolean)
        val message = json.getAsJsonArray("messages")[0].asJsonObject
        assertEquals("user", message.get("role").asString)
        assertEquals("hi", message.get("content").asString)
    }

    @Test
    fun `request includes tools when provided`() {
        val tools = listOf(
            com.example.dodroidai.ai.tools.ToolDefinition(
                name = "get_current_time",
                description = "当前时间",
                parameters = com.example.dodroidai.ai.tools.ToolParameters()
            )
        )

        val request = createAnthropicRequest(
            config = config(),
            messages = listOf(
                AnthropicMessage(role = "user", content = com.google.gson.JsonPrimitive("现在几点"))
            ),
            tools = tools
        )

        val buffer = Buffer()
        request.body?.writeTo(buffer)
        val json = JsonParser.parseString(buffer.readUtf8()).asJsonObject
        val tool = json.getAsJsonArray("tools")[0].asJsonObject
        assertEquals("get_current_time", tool.get("name").asString)
        assertNotNull(tool.getAsJsonObject("input_schema"))
    }
}
