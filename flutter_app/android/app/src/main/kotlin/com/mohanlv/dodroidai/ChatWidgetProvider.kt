package com.mohanlv.dodroidai

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 聊天桌面小组件（1x2）：显示会话标题与最新消息
 */
class ChatWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val title = widgetData.getString("widget_title", null) ?: "DoDroidAI"
            val body = widgetData.getString("widget_body", null) ?: "打开应用开始对话"
            val views = RemoteViews(context.packageName, R.layout.widget_chat)
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_body, body)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
