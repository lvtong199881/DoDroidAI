package com.example.dodroidai.ai.tools

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class ToolArgsTest {

    @Test
    fun `missing required string throws`() {
        assertThrows(ToolArgumentException::class.java) {
            ToolArgs.parse("{}").requireString("query")
        }
    }

    @Test
    fun `blank required string throws`() {
        assertThrows(ToolArgumentException::class.java) {
            ToolArgs.parse("""{"query":"   "}""").requireString("query")
        }
    }

    @Test
    fun `non object json throws`() {
        assertThrows(ToolArgumentException::class.java) {
            ToolArgs.parse("[1,2]")
        }
    }

    @Test
    fun `int range is enforced`() {
        assertThrows(ToolArgumentException::class.java) {
            ToolArgs.parse("""{"hour":24}""").requireInt("hour", 0..23)
        }
        assertEquals(23, ToolArgs.parse("""{"hour":23}""").requireInt("hour", 0..23))
    }

    @Test
    fun `string number is accepted for int`() {
        assertEquals(7, ToolArgs.parse("""{"minute":"7"}""").requireInt("minute", 0..59))
    }

    @Test
    fun `optional string returns null when absent`() {
        assertNull(ToolArgs.parse("{}").optionalString("label"))
    }

    @Test
    fun `iso time parses`() {
        val millis = ToolArgs.parse("""{"start_time":"2026-01-15T10:00:00"}""")
            .requireIsoTime("start_time")
        assertTrue(millis > 0)
    }
}
