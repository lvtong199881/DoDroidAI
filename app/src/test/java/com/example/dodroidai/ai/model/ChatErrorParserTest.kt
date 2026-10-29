package com.example.dodroidai.ai.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException

class ChatErrorParserTest {

    @Test
    fun `socket timeout maps to timeout`() {
        val result = ChatErrorParser.parse(SocketTimeoutException())
        assertEquals(ChatErrorKind.TIMEOUT, result.kind)
        assertTrue(result.retryable)
    }

    @Test
    fun `unknown host maps to network`() {
        val result = ChatErrorParser.parse(UnknownHostException("api.example.com"))
        assertEquals(ChatErrorKind.NETWORK, result.kind)
        assertTrue(result.retryable)
    }

    @Test
    fun `connect exception maps to network`() {
        val result = ChatErrorParser.parse(ConnectException("Connection refused"))
        assertEquals(ChatErrorKind.NETWORK, result.kind)
    }

    @Test
    fun `http 401 maps to auth and is not retryable`() {
        val result = ChatErrorParser.parse(RuntimeException("OpenAI SSE failed (HTTP 401): bad key"))
        assertEquals(ChatErrorKind.AUTH, result.kind)
        assertFalse(result.retryable)
    }

    @Test
    fun `http 429 maps to rate limit`() {
        val result = ChatErrorParser.parse(RuntimeException("HTTP 429: too many requests"))
        assertEquals(ChatErrorKind.RATE_LIMIT, result.kind)
    }

    @Test
    fun `http 500 maps to server error`() {
        val result = ChatErrorParser.parse(RuntimeException("OpenAI SSE failed (HTTP 500): upstream"))
        assertEquals(ChatErrorKind.SERVER, result.kind)
    }

    @Test
    fun `wrapped timeout is detected through cause chain`() {
        val error = RuntimeException("SSE failed", SocketTimeoutException("read timed out"))
        assertEquals(ChatErrorKind.TIMEOUT, ChatErrorParser.parse(error).kind)
    }

    @Test
    fun `unknown error keeps message`() {
        val result = ChatErrorParser.parse(IllegalStateException("boom"))
        assertEquals(ChatErrorKind.UNKNOWN, result.kind)
        assertTrue(result.message.contains("boom"))
    }
}
