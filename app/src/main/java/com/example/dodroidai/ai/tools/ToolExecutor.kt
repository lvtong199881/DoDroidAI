package com.example.dodroidai.ai.tools

import android.content.Context
import okhttp3.OkHttpClient
import java.io.Closeable
import java.util.concurrent.TimeUnit

/**
 * 工具执行门面：底层委托 [ToolRegistry]，保留给 ChatViewModel 使用的稳定 API。
 */
class ToolExecutor(
    val context: Context
) : Closeable {

    private val httpClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15L, TimeUnit.SECONDS)
        .readTimeout(20L, TimeUnit.SECONDS)
        .build()

    private val registry = ToolRegistry(context, httpClient)

    fun getToolDefinitions(): List<ToolDefinition> = registry.definitions()

    fun getToolRiskLevel(toolName: String): RiskLevel = registry.riskLevel(toolName)

    fun hasRequiredPermissions(toolName: String): Boolean = registry.hasPermissions(toolName)

    fun getRequiredPermissions(toolName: String): List<String> = registry.requiredPermissions(toolName)

    fun hasPermissions(toolName: String): Boolean = registry.hasPermissions(toolName)

    fun hasTool(toolName: String): Boolean = registry.hasTool(toolName)

    suspend fun execute(toolCall: ToolCall): ToolResult = registry.execute(toolCall)

    override fun close() {
        httpClient.dispatcher.executorService.shutdown()
        httpClient.connectionPool.evictAll()
    }
}
