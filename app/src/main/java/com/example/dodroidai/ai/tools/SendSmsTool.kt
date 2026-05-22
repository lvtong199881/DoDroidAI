package com.example.dodroidai.ai.tools

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.telephony.SmsManager
import android.util.Log
import androidx.core.content.ContextCompat
import com.example.dodroidai.util.GsonUtil

/**
 * 发送短信工具
 */
class SendSmsTool(private val context: Context) : Tool {
    /** 工具名称 */
    override val name = "send_sms"

    /** 需要短信权限 */
    override val requiredPermissions = listOf(Manifest.permission.SEND_SMS)

    /** 风险等级高 */
    override val riskLevel = RiskLevel.HIGH

    override fun hasPermissions(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
    }

    override fun requestPermissions(activity: Activity, callback: (Boolean) -> Unit) {
        activity.requestPermissions(requiredPermissions.toTypedArray(), REQUEST_CODE)
    }

    override fun execute(context: Context, arguments: String): ToolResult {
        if (!hasPermissions(context)) {
            return failure("短信权限被拒绝，无法发送短信")
        }

        val args = parseArgs(arguments) ?: return failure("参数解析失败")

        return try {
            val smsManager = context.getSystemService(SmsManager::class.java)
            val parts = smsManager.divideMessage(args.message)
            smsManager.sendMultipartTextMessage(args.phoneNumber, null, parts, null, null)
            ToolResult(
                toolCallId = "",
                toolName = name,
                success = true,
                result = "短信已发送给 ${args.phoneNumber}"
            )
        } catch (e: SecurityException) {
            failure("短信权限被拒绝")
        } catch (e: Exception) {
            failure("发送短信失败: ${e.message}")
        }
    }

    private fun failure(error: String): ToolResult {
        return ToolResult(
            toolCallId = "",
            toolName = name,
            success = false,
            result = "",
            error = error
        )
    }

    private data class Args(val phone_number: String, val message: String) {
        val phoneNumber: String get() = phone_number
    }

    private fun parseArgs(json: String): Args? {
        return try {
            GsonUtil.fromJson(json, Args::class.java)
        } catch (e: Exception) {
            null
        }
    }

    companion object {
        private const val REQUEST_CODE = 101
    }
}