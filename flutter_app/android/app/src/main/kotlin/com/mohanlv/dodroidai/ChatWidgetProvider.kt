package com.mohanlv.dodroidai

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 聊天桌面小组件（1x2）：展示最近会话标题与最新消息，点击打开应用
 */
class ChatWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val title = widgetData.getString("widget_title", null)?.takeIf { it.isNotBlank() }
            ?: "开始对话"
        val subtitle = widgetData.getString("widget_subtitle", null).orEmpty()

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_chat)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(
                R.id.widget_subtitle,
                subtitle.ifBlank { "点按开始新对话" }
            )
            views.setOnClickPendingIntent(R.id.widget_root, openApp(context))
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun openApp(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
