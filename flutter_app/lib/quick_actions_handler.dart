import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

/// 桌面快捷方式待处理事件（新对话 / 设置）
final ValueNotifier<String?> pendingShortcut = ValueNotifier<String?>(null);

Future<void> initQuickActions() async {
  final quickActions = const QuickActions();
  await quickActions.initialize((type) {
    pendingShortcut.value = type;
  });
  await quickActions.setShortcutItems([
    const ShortcutItem(
      type: 'new_chat',
      localizedTitle: '新对话',
      icon: 'ic_launcher',
    ),
    const ShortcutItem(
      type: 'settings',
      localizedTitle: '设置',
      icon: 'ic_launcher',
    ),
  ]);
}
