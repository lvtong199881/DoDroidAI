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
      final t = _stripMarkdown(latest.name);
      final st = _stripMarkdown(lastContent);
      await _write(t, st);
    } catch (e) {
      debugPrint('HomeWidgetSync failed: $e');
    }
  }

  /// 去掉 Markdown 标记，小组件里只显示纯文本
  static String _stripMarkdown(String input) {
    var text = input;
    // 代码块与行内代码
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
    text = text.replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m.group(1) ?? '');
    // 粗体 / 斜体 / 删除线
    text = text.replaceAll('**', '');
    text = text.replaceAll('__', '');
    text = text.replaceAll('~~', '');
    text = text.replaceAll('*', '');
    // 标题井号、列表符号、引用符号
    text = text.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^[-+]\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^>\s*', multiLine: true), '');
    // 链接 [text](url) -> text
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]*)\]\([^)]*\)'),
      (m) => m.group(1) ?? '',
    );
    // 压缩空白
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  static Future<void> _write(String title, String subtitle) async {
    await HomeWidget.saveWidgetData<String>('widget_title', title);
    await HomeWidget.saveWidgetData<String>('widget_subtitle', subtitle);
    for (final name in _androidNames) {
      await HomeWidget.updateWidget(androidName: name);
    }
  }
}
