import 'dart:convert';

import 'package:android_intent_plus/android_intent.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/memory_database.dart';
import '../data/note_database.dart';
import '../data/scheduled_task_database.dart';

import 'session_tools.dart';
import 'web_search.dart';

const MethodChannel _nativeChannel = MethodChannel('dodroidai/native');

/// Flutter 侧工具注册与执行
class ToolRegistry {
  static const List<Map<String, dynamic>> definitions = [
    {
      'type': 'function',
      'function': {
        'name': 'web_search',
        'description': '搜索互联网获取实时信息（需要配置 Brave Search API Key）。'
            '支持一次提交 1-4 个查询，会逐个检索并合并结果。',
        'parameters': {
          'type': 'object',
          'properties': {
            'queries': {
              'type': 'array',
              'items': {'type': 'string'},
              'minItems': 1,
              'maxItems': 4,
              'description': '搜索关键词列表，1-4 个；需要对比多个主题时一次传多个',
            },
            'count': {
              'type': 'integer',
              'description': '每个查询返回条数，默认 5，最大 10',
            },
          },
          'required': ['queries'],
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
        'description': '记住一条长期信息，例如用户称呼、城市、偏好。'
            '与已有记忆语义重复时不会重复存储；'
            '后续会按相关性自动注入相关记忆，无需每次复述。',
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
        'name': 'recall_memory',
        'description': '按语义检索已记住的长期信息（用户偏好、城市、称呼等）。'
            '回答涉及用户个人情况、且当前对话上下文里没有时使用。',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': '要回忆的内容，例如"用户住在哪里""咖啡偏好"',
            },
            'limit': {
              'type': 'integer',
              'description': '最多返回条数，默认 5，最大 10',
            },
          },
          'required': ['query'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'forget_memory',
        'description': '删除一条已记住的长期信息'
            '（用户明确要求忘记或更正某条信息时使用）。'
            '只删除语义匹配的条目，结果里会列出删除的内容。',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': '要忘记的内容描述，例如"之前住的城市"',
            },
          },
          'required': ['query'],
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
    {
      'type': 'function',
      'function': {
        'name': 'ask_user_question',
        'description':
            '当需要用户确认、选择或补充信息才能继续时，向用户提简明、自洽、面向用户的问题。'
            '某项 selected 为空且没有 custom 表示用户跳过该问题：继续执行、不要重复询问、'
            '也不要把跳过当作许可。返回 pending 表示超时未答，这不是跳过。',
        'parameters': {
          'type': 'object',
          'properties': {
            'questions': {
              'type': 'array',
              'description': '要询问用户的问题列表',
              'items': {
                'type': 'object',
                'properties': {
                  'id': {
                    'type': 'string',
                    'description': '本问题在本批次内的稳定标识，答案会原样带回',
                  },
                  'question': {
                    'type': 'string',
                    'description': '要问用户的具体问题',
                  },
                  'header': {
                    'type': 'string',
                    'description': '可选短标题，例如「确认」「选择模式」',
                  },
                  'options': {
                    'type': 'array',
                    'description': '可选选项列表；若推荐某个选项，把它放第一位并在标签后加「（推荐）」',
                    'items': {
                      'type': 'object',
                      'properties': {
                        'label': {
                          'type': 'string',
                          'description': '面向用户的简短选项标签',
                        },
                        'description': {
                          'type': 'string',
                          'description': '一句话解释该选项的取舍或影响',
                        },
                      },
                      'required': ['label'],
                    },
                  },
                  'multi_select': {
                    'type': 'boolean',
                    'description': '用户是否可以多选，默认 false',
                  },
                },
                'required': ['id', 'question'],
              },
            },
            'timeout': {
              'type': 'integer',
              'description': '整批问题的等待秒数，默认 120。'
                  '除非用户明确要求等待时长，否则省略。'
                  '只有在必须拿到答案才能继续时才用 -1（无限等待）',
            },
          },
          'required': ['questions'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'session_search',
        'description': '跨所有历史会话搜索关键词，返回命中的会话、命中条数与最佳片段。'
            '需要回忆用户过去说过什么时使用。结果里的 session_id 可用于 '
            'session_event_search / session_event_read。',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': '搜索关键词'},
            'limit': {
              'type': 'integer',
              'description': '最多返回几个会话，默认 5，最大 20',
            },
          },
          'required': ['query'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'session_event_search',
        'description': '在指定会话（默认当前会话）内按关键词检索消息，'
            '返回消息 id、角色、时间与片段。',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': '搜索关键词'},
            'session_id': {
              'type': 'string',
              'description': '会话 id，省略则用当前会话',
            },
            'role': {
              'type': 'string',
              'enum': ['user', 'assistant', 'tool'],
              'description': '只搜某种角色的消息',
            },
            'since': {'type': 'string', 'description': 'ISO8601 起始时间（含）'},
            'until': {'type': 'string', 'description': 'ISO8601 结束时间（含）'},
            'limit': {
              'type': 'integer',
              'description': '最多返回条数，默认 10，最大 50',
            },
          },
          'required': ['query'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'session_event_read',
        'description': '读取一条历史消息的完整内容，并附带前后若干条消息的摘要。',
        'parameters': {
          'type': 'object',
          'properties': {
            'id': {
              'type': 'integer',
              'description': '消息 id（来自 session_event_search 的结果）',
            },
            'session_id': {
              'type': 'string',
              'description': '会话 id，省略则用当前会话',
            },
            'before': {
              'type': 'integer',
              'description': '前文条数，默认 2，最大 5',
            },
            'after': {
              'type': 'integer',
              'description': '后文条数，默认 2，最大 5',
            },
          },
          'required': ['id'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'session_trace',
        'description': '查看一个会话的概览：标题、消息总数与角色分布、起止时间、'
            '首条用户诉求与最近回复。',
        'parameters': {
          'type': 'object',
          'properties': {
            'session_id': {
              'type': 'string',
              'description': '会话 id，省略则用当前会话',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'session_event_trace',
        'description': '查看一条消息所属的完整对话轮次：从该轮用户请求到下一次'
            '用户请求之间的消息序列，含工具调用。',
        'parameters': {
          'type': 'object',
          'properties': {
            'id': {
              'type': 'integer',
              'description': '消息 id（来自 session_event_search 的结果）',
            },
            'session_id': {
              'type': 'string',
              'description': '会话 id，省略则用当前会话',
            },
            'max_messages': {
              'type': 'integer',
              'description': '最多返回条数，默认 10，最大 20',
            },
          },
          'required': ['id'],
        },
      },
    },
  ];

  /// 交互式工具：执行时需要挂起等待用户输入
  static const String askQuestionTool = 'ask_user_question';

  static bool isInteractive(String name) => name == askQuestionTool;

  static const Set<String> highRiskTools = {'send_sms', 'add_note'};

  /// forget_memory 的删除阈值：低于该相关性的条目一律不动
  static const double _forgetScoreThreshold = 0.5;

  static bool isKnown(String name) =>
      definitions.any((d) => d['function']['name'] == name);

  static bool isHighRisk(String name) => highRiskTools.contains(name);

  /// 工具所需的运行时权限（与原生 requiredPermissions 对齐）
  static List<Permission> permissionsFor(String name) {
    switch (name) {
      case 'send_sms':
        return [Permission.sms];
      case 'search_contacts':
        return [Permission.contacts];
      case 'add_calendar_event':
        return [Permission.calendarFullAccess];
      default:
        return const [];
    }
  }

  /// 确保权限已授予；返回 null 表示通过，否则返回错误文案
  static Future<String?> ensurePermissions(String name) async {
    final permissions = permissionsFor(name);
    if (permissions.isEmpty) return null;
    for (final permission in permissions) {
      final status = await permission.status;
      if (status.isGranted) continue;
      final result = await permission.request();
      if (!result.isGranted) {
        return '缺少权限：${permission.toString().split('.').last}，请在系统设置中授予';
      }
    }
    return null;
  }

  static Future<String> execute(
    String name,
    String argumentsJson, {
    String? sessionId,
  }) async {
    final args = _decode(argumentsJson);
    switch (name) {
      case askQuestionTool:
        // 交互式工具由 ChatController 挂起处理，走到这里说明状态异常
        return 'Error: ask_user_question 需要交互界面，不能直接执行';

      case 'session_search':
      case 'session_event_search':
      case 'session_event_read':
      case 'session_trace':
      case 'session_event_trace':
        return SessionTools.execute(
          name,
          args,
          currentSessionId: sessionId,
        );

      case 'web_search':
        final queries = _queriesOf(args);
        final count = ((args['count'] as num?)?.toInt() ?? 5).clamp(1, 10);
        return WebSearch.searchMany(queries, count: count);
      case 'add_note':
        final title = (args['title'] as String?) ?? '';
        final content = (args['content'] as String?) ?? '';
        await NoteRepository.instance.insert(title, content);
        return '已保存笔记：$title';
      case 'remember_fact':
        final key = (args['key'] as String?) ?? '';
        final value = (args['value'] as String?) ?? '';
        if (key.isEmpty || value.isEmpty) {
          return '参数不合法：key 与 value 必填';
        }
        final content = '$key: $value';
        final fact = await MemoryRepository.instance.insert(content);
        if (fact.content != content) {
          return '已有相似记忆，未重复存储：${fact.content}';
        }
        return '已记住：$key = $value';
      case 'recall_memory':
        final query = (args['query'] as String?) ?? '';
        if (query.isEmpty) return '参数不合法：query 不能为空';
        final limit = ((args['limit'] as num?)?.toInt() ?? 5).clamp(1, 10);
        final facts =
            await MemoryRepository.instance.searchRelevant(query, limit: limit);
        if (facts.isEmpty) return '还没有记住任何信息';
        return facts.map((f) => '- ${f.content}').join('\n');
      case 'forget_memory':
        final query = (args['query'] as String?) ?? '';
        if (query.isEmpty) return '参数不合法：query 不能为空';
        final candidates = await MemoryRepository.instance.searchRelevant(
          query,
          limit: 5,
        );
        final matched =
            candidates.where((f) => f.score >= _forgetScoreThreshold).toList();
        if (matched.isEmpty) return '没有找到与「$query」匹配的记忆，未删除';
        for (final fact in matched) {
          await MemoryRepository.instance.delete(fact.id);
        }
        return '已删除 ${matched.length} 条记忆：\n'
            '${matched.map((f) => '- ${f.content}').join('\n')}';
      case 'schedule_task':
        final prompt = (args['prompt'] as String?) ?? '';
        final delay = (args['delay_minutes'] as num?)?.toInt() ?? 0;
        if (prompt.isEmpty || delay < 1) {
          return '参数不合法：prompt 与 delay_minutes(>=1) 必填';
        }
        final runAt = DateTime.now().add(Duration(minutes: delay));
        final timeText =
            '${runAt.hour.toString().padLeft(2, '0')}:${runAt.minute.toString().padLeft(2, '0')}';
        await ScheduledTaskRepository.instance.insert(
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

  /// 解析查询列表：优先 queries 数组，兼容旧的 query 字符串
  static List<String> _queriesOf(Map<String, dynamic> args) {
    final result = <String>[];
    final raw = args['queries'];
    if (raw is List) {
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty) {
          result.add(item.trim());
        }
      }
    }
    final single = args['query'];
    if (single is String && single.trim().isNotEmpty) {
      result.add(single.trim());
    }
    return result;
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
