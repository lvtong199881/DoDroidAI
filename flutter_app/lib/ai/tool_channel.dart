import 'package:flutter/services.dart';

/// 桥接原生系统工具（dodroidai/tools）
class ToolChannel {
  static const MethodChannel _channel = MethodChannel('dodroidai/tools');

  static Future<String> getBattery() async {
    try {
      final level = await _channel.invokeMethod<String>('get_battery');
      return level == null ? '未知' : '$level%';
    } on PlatformException {
      return '读取电池信息失败';
    }
  }

  static Future<String> setAlarm({
    required int hour,
    required int minute,
    String? label,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('set_alarm', {
        'hour': hour,
        'minute': minute,
        'label': label ?? 'DoDroidAI 闹钟',
      });
      return result ?? '已设置闹钟';
    } on PlatformException catch (e) {
      return '设置闹钟失败: ${e.message}';
    }
  }
}
