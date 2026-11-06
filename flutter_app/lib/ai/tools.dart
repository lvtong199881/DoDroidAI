import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/memory_database.dart';
import '../data/note_database.dart';
import '../data/scheduled_task_database.dart';

import 'web_search.dart';

const MethodChannel _nativeChannel = MethodChannel('dodroidai/native');

/// Flutter 侧工具注册与执行
class ToolRegistry {
  static const List<Map<String, dynamic>> definitions = [
    {
      'type': 'function',
      'function': {
        'name': 'web_search',
        'description': '搜索互联网获取实时信息（需要配置 Brave Search API Key）',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': '搜索关键词'},
          },
          'required': ['query'],
        },
      },
    },

    {
      'type': 'function',
      'function': {
        'name': 'add_note',
        'description': '添加一条笔记',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': '笔记标题'},
            'content': {'type': 'string', 'description': '笔记内容'},
          },
          'required': ['title', 'content'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'remember_fact',
        'description': '记住一条长期信息，例如用户称呼、城市、偏好',
        'parameters': {
          'type': 'object',
          'properties': {
            'key': {'type': 'string', 'description': '信息的键'},
            'value': {'type': 'string', 'description': '信息的值'},
          },
          'required': ['key', 'value'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'schedule_task',
        'description': '安排一个定时任务，到点后提醒',
        'parameters': {
          'type': 'object',
          'properties': {
            'prompt': {'type': 'string', 'description': '到点后要执行的任务描述'},
            'delay_minutes': {
              'type': 'integer',
              'description': '多少分钟后执行（1-1440）',
            },
          },
          'required': ['prompt', 'delay_minutes'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'read_clipboard',
        'description': '读取剪贴板内容',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'write_clipboard',
        'description': '把文本复制到剪贴板',
        'parameters': {
          'type': 'object',
          'properties': {
            'text': {'type': 'string', 'description': '要复制的文本'},
          },
          'required': ['text'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'add_calendar_event',
        'description': '创建日历事件',
        'parameters': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string', 'description': '事件标题'},
            'description': {'type': 'string', 'description': '事件描述'},
            'start_time': {'type': 'string', 'description': '开始时间 ISO8601'},
            'end_time': {'type': 'string', 'description': '结束时间 ISO8601'},
          },
          'required': ['title', 'start_time'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'search_contacts',
        'description': '按姓名或号码搜索通讯录联系人',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': '姓名或号码的一部分'},
            'limit': {'type': 'integer', 'description': '最多返回条数，默认 5'},
          },
          'required': ['query'],
        },
      },
    },
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
        'name': 'set_alarm',
        'description': '在设备上设置闹钟（打开系统闹钟设置）',
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
    {
      'type': 'function',
      'function': {
        'name': 'send_sms',
        'description': '打开发短信界面并预填内容（需用户手动确认发送）',
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
  ];

  static const Set<String> highRiskTools = {'send_sms', 'add_note'};

  static bool isKnown(String name) =>
      definitions.any((d) => d['function']['name'] == name);

  static bool isHighRisk(String name) => highRiskTools.contains(name);

  static Future<String> execute(String name, String argumentsJson) async {
    final args = _decode(argumentsJson);
    switch (name) {
      case 'web_search':
        final query = (args['query'] as String?) ?? '';
        return WebSearch.search(query);
      case 'add_note':
        final title = (args['title'] as String?) ?? '';
        final content = (args['content'] as String?) ?? '';
        await NoteDatabase().insert(title, content);
        return '已保存笔记：$title';
      case 'remember_fact':
        final key = (args['key'] as String?) ?? '';
        final value = (args['value'] as String?) ?? '';
        await MemoryDatabase().insert('$key: $value');
        return '已记住：$key = $value';
      case 'schedule_task':
        final prompt = (args['prompt'] as String?) ?? '';
        final delay = (args['delay_minutes'] as num?)?.toInt() ?? 0;
        if (prompt.isEmpty || delay < 1) {
          return '参数不合法：prompt 与 delay_minutes(>=1) 必填';
        }
        final runAt = DateTime.now().add(Duration(minutes: delay));
        final timeText =
            '${runAt.hour.toString().padLeft(2, '0')}:${runAt.minute.toString().padLeft(2, '0')}';
        await ScheduledTaskDatabase().insert(
          title: prompt,
          prompt: prompt,
          schedule: timeText,
        );
        return '已安排任务（$delay 分钟后执行）：$prompt';
      case 'read_clipboard':
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text ?? '';
        return text.isEmpty ? '剪贴板为空' : text;
      case 'write_clipboard':
        final text = (args['text'] as String?) ?? '';
        if (text.isEmpty) return '参数不合法：text 不能为空';
        await Clipboard.setData(ClipboardData(text: text));
        return '已复制到剪贴板';
      case 'add_calendar_event':
        final title = (args['title'] as String?) ?? '';
        final description = (args['description'] as String?) ?? '';
        final start = (args['start_time'] as String?) ?? '';
        if (title.isEmpty || start.isEmpty) {
          return '参数不合法：title 与 start_time 必填';
        }
        final begin = DateTime.tryParse(start);
        final endRaw = args['end_time'] as String?;
        final end = endRaw == null
            ? (begin?.add(const Duration(hours: 1)))
            : DateTime.tryParse(endRaw);
        if (begin == null) return '参数不合法：start_time 需为 ISO8601';
        final intent = AndroidIntent(
          action: 'android.intent.action.INSERT',
          data: 'content://com.android.calendar/events',
          arguments: <String, dynamic>{
            'title': title,
            'description': description,
            'beginTime': begin.millisecondsSinceEpoch,
            if (end != null) 'endTime': end.millisecondsSinceEpoch,
          },
        );
        await intent.launch();
        return '已打开日历创建事件：$title';
      case 'search_contacts':
        final query = (args['query'] as String?) ?? '';
        final limit = (args['limit'] as num?)?.toInt() ?? 5;
        if (query.isEmpty) return '参数不合法：query 不能为空';
        try {
          final result = await _nativeChannel.invokeMethod<List<dynamic>>(
            'searchContacts',
            {'query': query, 'limit': limit.clamp(1, 20)},
          );
          if (result == null || result.isEmpty) return '未找到匹配的联系人';
          return result
              .whereType<Map>()
              .map((m) => '${m['name']}：${m['number']}')
              .join('\n');
        } on PlatformException catch (e) {
          return '搜索联系人失败：${e.message}';
        }
      case 'get_current_time':
        return DateTime.now().toIso8601String();
      case 'get_battery_level':
        final level = await Battery().batteryLevel;
        return '$level%';
      case 'set_alarm':
        return _setAlarm(args);
      case 'send_sms':
        return _sendSms(args);
      default:
        return '未知工具: $name';
    }
  }

  static Future<String> _setAlarm(Map<String, dynamic> args) async {
    final hour = (args['hour'] as num?)?.toInt() ?? 8;
    final minute = (args['minute'] as num?)?.toInt() ?? 0;
    final label = args['label'] as String? ?? 'DoDroidAI 闹钟';
    final intent = AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: {
        'android.intent.extra.alarm.HOUR': hour,
        'android.intent.extra.alarm.MINUTES': minute,
        'android.intent.extra.alarm.MESSAGE': label,
        'android.intent.extra.alarm.SKIP_UI': true,
      },
    );
    await intent.launch();
    return '已设置闹钟 ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static Future<String> _sendSms(Map<String, dynamic> args) async {
    final number = args['number'] as String? ?? '';
    final message = args['message'] as String? ?? '';
    if (number.isEmpty || message.isEmpty) {
      return '手机号或短信内容为空';
    }
    final uri = Uri.parse('sms:$number?body=${Uri.encodeComponent(message)}');
    final ok = await launchUrl(uri);
    return ok ? '已打开发短信界面（请手动确认发送）' : '无法打开短信应用';
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
