package com.example.dodroidai.ai.tools

import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import okhttp3.OkHttpClient

/**
 * 工具注册表：从 KSP 生成的 [GeneratedTools] 读取所有 [ToolSpec]。
 *
 * 执行统一放在 IO 线程，带超时、取消与错误分类；`toolCallId` 由这里统一填充。
 */
class ToolRegistry(
    private val context: Context,
    private val httpClient: OkHttpClient
) {

    private val specs: Map<String, ToolSpec> by lazy {
        val all = GeneratedTools.all
        check(all.map { it.name }.toSet().size == all.size) {
            "工具名重复: " + all.groupBy { it.name }.filter { it.value.size > 1 }.keys
        }
        all.associateBy { it.name }
    }

    fun definitions(): List<ToolDefinition> = specs.values.map { it.toDefinition() }

    fun spec(name: String): ToolSpec? = specs[name]

    fun hasTool(name: String): Boolean = specs.containsKey(name)

    fun riskLevel(name: String): RiskLevel = specs[name]?.riskLevel ?: RiskLevel.HIGH

    fun requiredPermissions(name: String): List<String> =
        specs[name]?.requiredPermissions.orEmpty()

    fun hasPermissions(name: String): Boolean {
        val spec = specs[name] ?: return false
        return spec.requiredPermissions.all {
            ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    suspend fun execute(call: ToolCall): ToolResult = withContext(Dispatchers.IO) {
        val spec = specs[call.name]
            ?: return@withContext failure(call, ToolErrorCode.UNKNOWN_TOOL, "未知工具: ${call.name}")

        val args = try {
            ToolArgs.parse(call.arguments)
        } catch (e: ToolArgumentException) {
            return@withContext failure(call, ToolErrorCode.INVALID_ARGS, e.message ?: "参数错误")
        }

        try {
            val output = withTimeout(spec.timeoutMillis) {
                spec.execute(ToolContext(context, call, httpClient), args)
            }
            if (output.isError) {
                failure(call, output.errorCode ?: ToolErrorCode.EXEC_FAILED, output.text)
            } else {
                ToolResult(
                    toolCallId = call.id,
                    toolName = call.name,
                    success = true,
                    result = output.text
                )
            }
        } catch (e: TimeoutCancellationException) {
            failure(call, ToolErrorCode.TIMEOUT, "工具执行超时")
        } catch (e: CancellationException) {
            throw e
        } catch (e: ToolArgumentException) {
            failure(call, ToolErrorCode.INVALID_ARGS, e.message ?: "参数错误")
        } catch (e: Exception) {
            failure(call, ToolErrorCode.EXEC_FAILED, e.message ?: "执行失败")
        }
    }

    private fun failure(call: ToolCall, code: ToolErrorCode, message: String): ToolResult =
        ToolResult(
            toolCallId = call.id,
            toolName = call.name,
            success = false,
            result = "",
            error = "[$code] $message"
        )
}
