import 'dart:async';

import 'package:home_widget/home_widget.dart';

import '../notifications.dart';
import 'welcome_contract.dart';

/// 判断本次进程启动来自哪里（冷启动 / 小组件 / 通知 / 其他）。
///
/// 两个探针都是可选插件调用：任一异常或超时都降级为 [WelcomeEntry.other]，
/// 绝不阻塞首页，也不影响弹窗展示本身。
class LaunchEntryResolver {
  LaunchEntryResolver({
    Future<Uri?> Function()? widgetProbe,
    Future<bool> Function()? notificationProbe,
    this.timeout = const Duration(milliseconds: 250),
  })  : _widgetProbe = widgetProbe ?? HomeWidget.initiallyLaunchedFromHomeWidget,
        _notificationProbe = notificationProbe ?? _notificationLaunchedApp;

  final Future<Uri?> Function() _widgetProbe;
  final Future<bool> Function() _notificationProbe;

  /// 每个探针的等待上限，超时按失败处理。
  final Duration timeout;

  static Future<bool> _notificationLaunchedApp() async {
    final details = await appNotifications.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp ?? false;
  }

  Future<WelcomeEntry> resolve() async {
    final widget = await _probe<Uri?>(_widgetProbe);
    if (widget.value != null) return WelcomeEntry.widget;

    final notification = await _probe<bool>(_notificationProbe);
    if (notification.value == true) return WelcomeEntry.notification;

    if (widget.failed || notification.failed) return WelcomeEntry.other;
    return WelcomeEntry.coldStart;
  }

  Future<_ProbeResult<T>> _probe<T>(Future<T> Function() probe) async {
    try {
      final value = await Future<T>.sync(probe).timeout(timeout);
      return _ProbeResult<T>(value: value, failed: false);
    } catch (_) {
      return _ProbeResult<T>(value: null, failed: true);
    }
  }
}

class _ProbeResult<T> {
  const _ProbeResult({required this.value, required this.failed});

  final T? value;
  final bool failed;
}
