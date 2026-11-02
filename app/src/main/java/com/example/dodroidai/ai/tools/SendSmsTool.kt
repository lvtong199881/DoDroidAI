package com.example.dodroidai.ai.tools

import android.Manifest
import android.content.pm.PackageManager
import android.telephony.SmsManager
import androidx.core.content.ContextCompat

/**
 * 发送短信工具
 */
@ToolProvider
object SendSmsTool {

    fun spec(): ToolSpec = ToolSpec(
        name = "send_sms",
        description = "发送短信给指定联系人",
        parameters = ToolParameters(
            properties = mapOf(
                "phone_number" to ToolProperty("string", "收件人手机号"),
                "message" to ToolProperty("string", "短信内容")
            ),
            required = listOf("phone_number", "message")
        ),
        riskLevel = RiskLevel.HIGH,
        requiredPermissions = listOf(Manifest.permission.SEND_SMS),
        execute = { ctx, args ->
            val phoneNumber = args.requireString("phone_number")
            val message = args.requireString("message")

            val granted = ContextCompat.checkSelfPermission(
                ctx.appContext,
                Manifest.permission.SEND_SMS
            ) == PackageManager.PERMISSION_GRANTED

            if (!granted) {
                ToolOutput(
                    "短信权限被拒绝，无法发送短信",
                    isError = true,
                    errorCode = ToolErrorCode.PERMISSION_DENIED
                )
            } else {
                try {
                    val smsManager = ctx.appContext.getSystemService(SmsManager::class.java)
                    val parts = smsManager.divideMessage(message)
                    smsManager.sendMultipartTextMessage(phoneNumber, null, parts, null, null)
                    ToolOutput("短信已发送给 $phoneNumber")
                } catch (e: SecurityException) {
                    ToolOutput(
                        "短信权限被拒绝",
                        isError = true,
                        errorCode = ToolErrorCode.PERMISSION_DENIED
                    )
                } catch (e: Exception) {
                    ToolOutput("发送短信失败: ${e.message}", isError = true)
                }
            }
        }
    )
}
