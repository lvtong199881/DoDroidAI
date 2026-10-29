package com.example.dodroidai.ai.streaming

import com.example.dodroidai.ai.model.StreamingCallback
import com.example.dodroidai.ai.tools.ToolCall
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OpenAiSseParserTest {

    private class Recorder : StreamingCallback {
        val content = StringBuilder()
        val reasoning = StringBuilder()
        val calls = mutableListOf<ToolCall>()
        var completed = false
        var error: Throwable? = null

        override fun onContentDelta(content: String) {
            this.content.append(content)
        }

        override fun onReasoningDelta(content: String) {
            reasoning.append(content)
        }

        override fun onToolCallDelta(toolCallId: String, name: String, argumentsDelta: String) = Unit

        override fun onToolCallComplete(toolCallId: String, name: String, arguments: String) {
            calls.add(ToolCall(toolCallId, name, arguments))
        }

        override fun onComplete(
            fullContent: String,
            reasoningContent: String?,
            toolCalls: List<ToolCall>
        ) {
            completed = true
        }

        override fun onError(error: Throwable) {
            this.error = error
        }
    }

    @Test
    fun `content deltas complete on finish reason`() {
        val recorder = Recorder()
        val parser = OpenAiSseParser(recorder)

        parser.onData("""{"choices":[{"delta":{"content":"你"},"finish_reason":null}]}""")
        parser.onData("""{"choices":[{"delta":{"content":"好"},"finish_reason":"stop"}]}""")

        assertEquals("你好", recorder.content.toString())
        assertTrue(recorder.completed)
    }

    @Test
    fun `done marker completes the stream`() {
        val recorder = Recorder()
        val parser = OpenAiSseParser(recorder)

        parser.onData("""{"choices":[{"delta":{"content":"hello"}}]}""")
        parser.onData("[DONE]")

        assertEquals("hello", recorder.content.toString())
        assertTrue(recorder.completed)
    }

    @Test
    fun `reasoning content is captured`() {
        val recorder = Recorder()
        val parser = OpenAiSseParser(recorder)

        parser.onData("""{"choices":[{"delta":{"reasoning_content":"先分析"}}]}""")
        parser.onData("""{"choices":[{"delta":{"reasoning":"再推理"}}]}""")
        parser.onData("[DONE]")

        assertEquals("先分析再推理", recorder.reasoning.toString())
    }

    @Test
    fun `tool call fragments are merged by index`() {
        val recorder = Recorder()
        val parser = OpenAiSseParser(recorder)

        parser.onData(
            """{"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"get_current_time","arguments":""}}]}}]}"""
        )
        parser.onData(
            """{"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"{}"}}]}}]}"""
        )
        parser.onData("[DONE]")

        assertEquals(1, recorder.calls.size)
        assertEquals("call_1", recorder.calls[0].id)
        assertEquals("get_current_time", recorder.calls[0].name)
        assertEquals("{}", recorder.calls[0].arguments)
        assertTrue(recorder.completed)
    }

    @Test
    fun `error payload is surfaced`() {
        val recorder = Recorder()
        val parser = OpenAiSseParser(recorder)

        parser.onData("""{"error":{"message":"invalid api key"}}""")

        assertNotNull(recorder.error)
        assertTrue(recorder.error!!.message!!.contains("invalid api key"))
    }
}
