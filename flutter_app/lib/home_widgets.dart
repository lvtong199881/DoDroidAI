import 'package:home_widget/home_widget.dart';

/// 桌面小组件数据同步
class ChatWidgets {
  static const List<String> androidProviders = [
    'ChatWidgetProvider',
    'ChatWidgetProviderWide',
    'ChatWidgetProviderSquare',
  ];

  static Future<void> update({
    required String title,
    required String body,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('widget_title', title);
      await HomeWidget.saveWidgetData<String>('widget_body', body);
      for (final provider in androidProviders) {
        await HomeWidget.updateWidget(androidName: provider);
      }
    } catch (_) {
      // 小组件未添加时忽略
    }
  }
}
