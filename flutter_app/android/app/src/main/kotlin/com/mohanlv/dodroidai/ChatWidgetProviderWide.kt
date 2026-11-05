package com.mohanlv.dodroidai

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ChatWidgetProviderWide : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_chat_wide)
            views.setTextViewText(R.id.widget_body, "搜索对话")
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
