package com.example.dodroidai.ai.tools

import org.junit.Assert.assertEquals
import org.junit.Test

class ToolSpecTest {

    @Test
    fun `get_current_time has empty schema`() {
        val definition = GetCurrentTimeTool.spec().toDefinition()
        assertEquals("get_current_time", definition.name)
        assertEquals(RiskLevel.LOW, definition.riskLevel)
        assertEquals(emptyList<String>(), definition.parameters.required)
    }

    @Test
    fun `set_alarm exposes hour and minute bounds`() {
        val definition = SetAlarmTool.spec().toDefinition()
        assertEquals(listOf("hour", "minute"), definition.parameters.required)
        assertEquals(0, definition.parameters.properties.getValue("hour").minimum)
        assertEquals(23, definition.parameters.properties.getValue("hour").maximum)
        assertEquals(59, definition.parameters.properties.getValue("minute").maximum)
    }

    @Test
    fun `send_sms declares one permission and high risk`() {
        val spec = SendSmsTool.spec()
        assertEquals(RiskLevel.HIGH, spec.riskLevel)
        assertEquals(1, spec.requiredPermissions.size)
    }
}
