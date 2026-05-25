package com.example.dodroidai.ai.tools

/**
 * 工具定义列表
 */
object ToolsDefinition {

    fun getTools(): List<ToolDefinition> = listOf(
        GET_CURRENT_TIME,
        SET_ALARM,
        ADD_CALENDAR_EVENT,
        SEND_SMS,
        ADD_NOTE,
        WEB_SEARCH
    )

    /**
     * 获取当前时间
     */
    private val GET_CURRENT_TIME = ToolDefinition(
        name = "get_current_time",
        description = "获取当前日期和时间",
        parameters = ToolParameters(),
        riskLevel = RiskLevel.LOW
    )

    /**
     * 设置闹钟
     */
    private val SET_ALARM = ToolDefinition(
        name = "set_alarm",
        description = "设置一个闹钟。此工具会自动计算正确的日期（如果设置的时间已过，会自动设为明天），不需要先调用get_current_time。",
        parameters = ToolParameters(
            properties = mapOf(
                "hour" to ToolProperty("integer", "小时（0-23）"),
                "minute" to ToolProperty("integer", "分钟（0-59）"),
                "label" to ToolProperty("string", "闹钟标签/备注")
            ),
            required = listOf("hour", "minute")
        ),
        riskLevel = RiskLevel.MEDIUM
    )

    /**
     * 添加日历事件
     */
    private val ADD_CALENDAR_EVENT = ToolDefinition(
        name = "add_calendar_event",
        description = "在日历中添加一个事件",
        parameters = ToolParameters(
            properties = mapOf(
                "title" to ToolProperty("string", "事件标题"),
                "description" to ToolProperty("string", "事件描述"),
                "start_time" to ToolProperty("string", "开始时间（ISO 8601 格式，如 2024-01-15T10:00:00）"),
                "end_time" to ToolProperty("string", "结束时间（ISO 8601 格式，如 2024-01-15T11:00:00）")
            ),
            required = listOf("title", "start_time")
        ),
        riskLevel = RiskLevel.MEDIUM
    )

    /**
     * 发送短信
     */
    private val SEND_SMS = ToolDefinition(
        name = "send_sms",
        description = "发送短信给指定联系人",
        parameters = ToolParameters(
            properties = mapOf(
                "phone_number" to ToolProperty("string", "收件人手机号"),
                "message" to ToolProperty("string", "短信内容")
            ),
            required = listOf("phone_number", "message")
        ),
        riskLevel = RiskLevel.HIGH
    )

    /**
     * 添加笔记
     */
    private val ADD_NOTE = ToolDefinition(
        name = "add_note",
        description = "添加一条笔记",
        parameters = ToolParameters(
            properties = mapOf(
                "title" to ToolProperty("string", "笔记标题"),
                "content" to ToolProperty("string", "笔记内容")
            ),
            required = listOf("title", "content")
        ),
        riskLevel = RiskLevel.HIGH
    )

    /**
     * 联网搜索
     */
    private val WEB_SEARCH = ToolDefinition(
        name = "web_search",
        description = "搜索互联网获取实时信息，如天气、新闻、股票等",
        parameters = ToolParameters(
            properties = mapOf(
                "query" to ToolProperty("string", "搜索关键词")
            ),
            required = listOf("query")
        ),
        riskLevel = RiskLevel.LOW
    )
}
