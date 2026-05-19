package com.example.dodroidai.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast

/**
 * 闹钟触发接收器
 */
class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val label = intent.getStringExtra("label") ?: "闹钟"
        Log.d("AlarmReceiver", "Alarm triggered! Label: $label")
        Toast.makeText(context, "闹钟响了: $label", Toast.LENGTH_LONG).show()
    }
}