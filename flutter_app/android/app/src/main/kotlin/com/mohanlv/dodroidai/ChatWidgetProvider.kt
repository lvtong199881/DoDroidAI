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
            val views = RemoteViews(context.packageName, R.layout.widget_chat)
            views.setTextViewText(R.id.widget_title, "开始对话")
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
