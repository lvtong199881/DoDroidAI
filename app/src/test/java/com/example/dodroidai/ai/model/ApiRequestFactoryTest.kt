package com.example.dodroidai.ai.model

import com.example.dodroidai.ai.config.AIConfig
import com.google.gson.JsonParser
import okhttp3.Request
import okio.Buffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ApiRequestFactoryTest {

    private fun config(format: ApiFormat, baseUrl: String): AIConfig = AIConfig(
        provider = AIProvider.CUSTOM,
        apiKey = "test-key",
        baseUrl = baseUrl,
        model = "test-model",
        apiFormat = format
    )

    private fun bodyJson(request: Request): String {
        val buffer = Buffer()
        request.body?.writeTo(buffer)
        return buffer.readUtf8()
    }

    @Test
    fun `anthropic request uses messages url and x api key`() {
        val prepared = ApiRequestFactory.build(
            config = config(ApiFormat.ANTHROPIC_MESSAGES, "https://example.com"),
            messages = listOf(ChatMessage(role = ChatMessage.ROLE_USER, content = "hi")),
            encoded = emptyMap(),
            tools = null
        )

        assertEquals("https://example.com/v1/messages", prepared.request.url.toString())
        assertEquals("test-key", prepared.request.header("X-Api-Key"))
        assertNull(prepared.request.header("Authorization"))
    }

    @Test
    fun `openai request uses chat completions url and bearer`() {
        val prepared = ApiRequestFactory.build(
            config = config(
                ApiFormat.OPENAI_CHAT_COMPLETIONS,
                "https://api.openai.com"
            ),
            messages = listOf(ChatMessage(role = ChatMessage.ROLE_USER, content = "hi")),
            encoded = emptyMap(),
            tools = null
        )

        assertEquals(
            "https://api.openai.com/v1/chat/completions",
            prepared.request.url.toString()
        )
        assertEquals("Bearer test-key", prepared.request.header("Authorization"))
        assertNull(prepared.request.header("X-Api-Key"))

        val json = JsonParser.parseString(bodyJson(prepared.request)).asJsonObject
        assertEquals("test-model", json.get("model").asString)
        assertEquals("hi", json.getAsJsonArray("messages")[0].asJsonObject.get("content").asString)
    }

    @Test
    fun `base url with v1 is normalized`() {
        val prepared = ApiRequestFactory.build(
            config = config(
                ApiFormat.OPENAI_CHAT_COMPLETIONS,
                "https://api.openai.com/v1"
            ),
            messages = listOf(ChatMessage(role = ChatMessage.ROLE_USER, content = "hi")),
            encoded = emptyMap(),
            tools = null
        )

        assertEquals(
            "https://api.openai.com/v1/chat/completions",
            prepared.request.url.toString()
        )
    }

    @Test
    fun `anthropic base url with v1 is normalized`() {
        val prepared = ApiRequestFactory.build(
            config = config(ApiFormat.ANTHROPIC_MESSAGES, "https://example.com/v1"),
            messages = listOf(ChatMessage(role = ChatMessage.ROLE_USER, content = "hi")),
            encoded = emptyMap(),
            tools = null
        )

        assertEquals("https://example.com/v1/messages", prepared.request.url.toString())
    }
}
