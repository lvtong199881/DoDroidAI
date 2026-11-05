import 'dart:convert';

import 'tool_channel.dart';

/// Flutter 侧的工具注册与执行
class ToolRegistry {
  static const List<Map<String, dynamic>> definitions = [
    {
      'type': 'function',
      'function': {
        'name': 'get_current_time',
        'description': '获取设备当前日期与时间，返回 ISO 格式字符串',
        'parameters': {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_battery_level',
        'description': '获取设备电池电量百分比',
        'parameters': {
          'type': 'object',
          'properties': <String, dynamic>{},
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'send_sms',
        'description': '向指定手机号发送短信（高风险，需要用户确认）',
        'parameters': {
          'type': 'object',
          'properties': {
            'number': {'type': 'string', 'description': '手机号'},
            'message': {'type': 'string', 'description': '短信内容'},
          },
          'required': ['number', 'message'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'set_alarm',
        'description': '在设备上设置闹钟',
        'parameters': {
          'type': 'object',
          'properties': {
            'hour': {'type': 'integer', 'description': '小时（0-23）'},
            'minute': {'type': 'integer', 'description': '分钟（0-59）'},
            'label': {'type': 'string', 'description': '闹钟标签'},
          },
          'required': ['hour', 'minute'],
        },
      },
    },
  ];

  static const Set<String> highRiskTools = {'send_sms', 'add_note'};

  static bool isKnown(String name) =>
      definitions.any((d) => d['function']['name'] == name);

  static bool isHighRisk(String name) => highRiskTools.contains(name);

  static Future<String> execute(String name, String argumentsJson) async {
    switch (name) {
      case 'get_current_time':
        return DateTime.now().toIso8601String();
      case 'get_battery_level':
        return ToolChannel.getBattery();
      case 'send_sms':
        final smsArgs = _decode(argumentsJson);
        return ToolChannel.sendSms(
          number: (smsArgs['number'] as String?) ?? '',
          message: (smsArgs['message'] as String?) ?? '',
        );
      case 'set_alarm':
        final args = _decode(argumentsJson);
        return ToolChannel.setAlarm(
          hour: (args['hour'] as num?)?.toInt() ?? 8,
          minute: (args['minute'] as num?)?.toInt() ?? 0,
          label: args['label'] as String?,
        );
      default:
        return '未知工具: $name';
    }
  }

  static Map<String, dynamic> _decode(String json) {
    if (json.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // ignore invalid args
    }
    return const {};
  }
}
