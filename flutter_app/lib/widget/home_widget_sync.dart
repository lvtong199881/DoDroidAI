import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../data/chat_database.dart';

/// 桌面小组件数据同步：把最近会话标题与最新消息写进 HomeWidget 存储
class HomeWidgetSync {
  HomeWidgetSync._();

  static const _androidNames = [
    'ChatWidgetProvider',
    'ChatWidgetProviderWide',
    'ChatWidgetProviderSquare',
  ];

  /// 用当前最新会话刷新小组件
  static Future<void> refresh() async {
    try {
      final sessions = await ChatDatabase.instance.sessions();
      if (sessions.isEmpty) {
        await _write('开始对话', '点按开始新对话');
        return;
      }
      final latest = sessions.first;
      final messages = await ChatDatabase.instance.messagesOf(latest.id);
      final lastContent = messages.isEmpty
          ? ''
          : (messages.last.role.name == 'user'
              ? '你：${messages.last.content}'
              : messages.last.content);
      await _write(
        latest.name,
        lastContent.replaceAll(RegExp(r'\s+'), ' ').trim(),
      );
    } catch (e) {
      debugPrint('HomeWidgetSync failed: $e');
    }
  }

  static Future<void> _write(String title, String subtitle) async {
    await HomeWidget.saveWidgetData<String>('widget_title', title);
    await HomeWidget.saveWidgetData<String>('widget_subtitle', subtitle);
    for (final name in _androidNames) {
      await HomeWidget.updateWidget(androidName: name);
    }
  }
}
