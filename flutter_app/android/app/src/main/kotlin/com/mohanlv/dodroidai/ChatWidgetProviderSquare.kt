package com.mohanlv.dodroidai

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ChatWidgetProviderSquare : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_chat_square)
            views.setTextViewText(R.id.widget_title, "开始对话")
            views.setTextViewText(R.id.widget_body, "点按打开 DoDroidAI")
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
