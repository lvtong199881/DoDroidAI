import 'package:home_widget/home_widget.dart';

/// 桌面小组件数据同步
class ChatWidgets {
  static const String androidProvider = 'ChatWidgetProvider';

  static Future<void> update({
    required String title,
    required String body,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('widget_title', title);
      await HomeWidget.saveWidgetData<String>('widget_body', body);
      await HomeWidget.updateWidget(androidName: androidProvider);
    } catch (_) {
      // 小组件未添加时忽略
    }
  }
}
