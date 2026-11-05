package com.example.dodroidai.dodroidai

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.os.BatteryManager
import android.provider.AlarmClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 系统能力工具：dodroidai/tools
 */
class ToolPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val CHANNEL = "dodroidai/tools"
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "get_battery" -> getBattery(result)
            "set_alarm" -> setAlarm(call, result)
            else -> result.notImplemented()
        }
    }

    private fun getBattery(result: MethodChannel.Result) {
        try {
            val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
            val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            result.success(level)
        } catch (e: Exception) {
            result.error("battery", e.message, null)
        }
    }

    private fun setAlarm(call: MethodCall, result: MethodChannel.Result) {
        try {
            val hour = call.argument<Int>("hour") ?: 8
            val minute = call.argument<Int>("minute") ?: 0
            val label = call.argument<String>("label") ?: "DoDroidAI 闹钟"
            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                putExtra(AlarmClock.EXTRA_MESSAGE, label)
                putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            result.success("已设置闹钟 ${"%02d".format(hour)}:${"%02d".format(minute)}")
        } catch (e: Exception) {
            result.error("alarm", e.message, null)
        }
    }
}
