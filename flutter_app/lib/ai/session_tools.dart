import '../data/chat_database.dart';

/// 会话检索工具的执行与格式化。
///
/// 五个工具的 JSON Schema 统一在 [ToolRegistry] 注册，这里只负责参数校验、
/// 查询与面向模型的文本输出；全部只读，不弹确认、不需要系统权限。
class SessionTools {
  static const int _maxOutputChars = 6000;
  static const Set<String> _roles = {'user', 'assistant', 'tool'};

  static Future<String> execute(
    String name,
    Map<String, dynamic> args, {
    String? currentSessionId,
  }) async {
    switch (name) {
      case 'session_search':
        return _search(args);
      case 'session_event_search':
        return _eventSearch(args, currentSessionId);
      case 'session_event_read':
        return _eventRead(args, currentSessionId);
      case 'session_trace':
        return _trace(args, currentSessionId);
      case 'session_event_trace':
        return _eventTrace(args, currentSessionId);
      default:
        return '未知工具: $name';
    }
  }

  // ---------- 具体实现 ----------

  /// 跨会话检索：按会话聚合命中数、最近命中时间与最佳片段
  static Future<String> _search(Map<String, dynamic> args) async {
    final query = _queryOf(args);
    if (query == null) return '参数不合法：query 不能为空';
    final limit = _intOf(args, 'limit', def: 5, min: 1, max: 20);
    final hits = await ChatDatabase.instance.searchAllSessions(query);
    if (hits.isEmpty) return '没有找到包含「$query」的历史消息';

    final grouped = <String, List<MessageHit>>{};
    for (final hit in hits) {
      grouped.putIfAbsent(hit.sessionId, () => []).add(hit);
    }
    final sessions = await ChatDatabase.instance.sessions();
    final names = {for (final s in sessions) s.id: s.name};
    final entries = grouped.entries.toList()
      ..sort(
        (a, b) => b.value.first.createdAt.compareTo(a.value.first.createdAt),
      );

    final buffer = StringBuffer('找到 ${grouped.length} 个会话提及「$query」：');
    for (var i = 0; i < entries.length && i < limit; i++) {
      final entry = entries[i];
      final best = entry.value.first;
      final name = names[entry.key] ?? '';
      buffer.writeln(
        '\n${i + 1}. 会话 ${entry.key}（$name）| 命中 ${entry.value.length} 条 '
        '| 最近 ${_fmt(best.createdAt)}',
      );
      buffer.writeln('   片段：${best.snippet}');
    }
    return _limit(buffer.toString());
  }

  /// 单会话内检索
  static Future<String> _eventSearch(
    Map<String, dynamic> args,
    String? currentSessionId,
  ) async {
    final query = _queryOf(args);
    if (query == null) return '参数不合法：query 不能为空';
    final sessionId = _sessionOf(args, currentSessionId);
    if (sessionId == null) return '当前没有可检索的会话';
    final role = (args['role'] as String?)?.trim();
    if (role != null && role.isNotEmpty && !_roles.contains(role)) {
      return '参数不合法：role 只能是 user / assistant / tool';
    }
    final limit = _intOf(args, 'limit', def: 10, min: 1, max: 50);
    final (since, sinceBad) = _timeOf(args['since']);
    if (sinceBad) return '参数不合法：since 需为 ISO8601 时间';
    final (until, untilBad) = _timeOf(args['until']);
    if (untilBad) return '参数不合法：until 需为 ISO8601 时间';

    final hits = await ChatDatabase.instance.searchMessages(
      query,
      sessionId: sessionId,
      role: (role == null || role.isEmpty) ? null : role,
      limit: limit,
      sinceMs: since?.millisecondsSinceEpoch,
      untilMs: until?.millisecondsSinceEpoch,
    );
    if (hits.isEmpty) return '会话 $sessionId 内没有找到「$query」';

    final buffer = StringBuffer('会话 $sessionId 内找到 ${hits.length} 条「$query」：');
    for (final hit in hits) {
      final tool = hit.toolName == null ? '' : '（${hit.toolName}）';
      buffer.writeln(
        '\n[id ${hit.id}] ${hit.role}$tool ${_fmt(hit.createdAt)}\n  ${hit.snippet}',
      );
    }
    return _limit(buffer.toString());
  }

  /// 读一条消息全文 + 前后上下文
  static Future<String> _eventRead(
    Map<String, dynamic> args,
    String? currentSessionId,
  ) async {
    final id = _idOf(args);
    if (id == null) return '参数不合法：id 必填且为整数';
    final sessionId = _sessionOf(args, currentSessionId);
    if (sessionId == null) return '当前没有可检索的会话';
    final before = _intOf(args, 'before', def: 2, min: 0, max: 5);
    final after = _intOf(args, 'after', def: 2, min: 0, max: 5);

    final window = await ChatDatabase.instance
        .messageWindow(sessionId, id, before: before, after: after);
    if (!window.any((hit) => hit.id == id)) return '未找到消息 #$id';
    final target = window.firstWhere((hit) => hit.id == id);

    final buffer = StringBuffer(
      '会话 $sessionId · 消息 #$id · ${target.role} · ${_fmt(target.createdAt)}\n',
    );
    buffer.writeln(_clip(target.content, 4000));

    final prev = window.where((hit) => hit.id < id).toList();
    final next = window.where((hit) => hit.id > id).toList();
    if (prev.isNotEmpty) {
      buffer.writeln('\n— 前文 —');
      for (final hit in prev) {
        buffer.writeln('[id ${hit.id}] ${hit.role}：${_clip(hit.content, 200)}');
      }
    }
    if (next.isNotEmpty) {
      buffer.writeln('\n— 后文 —');
      for (final hit in next) {
        buffer.writeln('[id ${hit.id}] ${hit.role}：${_clip(hit.content, 200)}');
      }
    }
    return _limit(buffer.toString());
  }

  /// 会话概览
  static Future<String> _trace(
    Map<String, dynamic> args,
    String? currentSessionId,
  ) async {
    final sessionId = _sessionOf(args, currentSessionId);
    if (sessionId == null) return '当前没有可检索的会话';
    final overview = await ChatDatabase.instance.sessionOverview(sessionId);
    if (overview == null) return '未找到会话 $sessionId';

    final buffer = StringBuffer()
      ..writeln('会话「${overview.name}」（${overview.id}）')
      ..writeln(
        '消息 ${overview.messageCount} 条'
        '（user ${overview.userCount} / assistant ${overview.assistantCount} '
        '/ tool ${overview.toolCount}）',
      );
    if (overview.firstAt != null && overview.lastAt != null) {
      buffer.writeln(
        '时间：${_fmt(overview.firstAt!)} → ${_fmt(overview.lastAt!)}',
      );
    }
    if (overview.firstUserSnippet != null) {
      buffer.writeln('首条用户诉求：${overview.firstUserSnippet}');
    }
    if (overview.lastAssistantSnippet != null) {
      buffer.writeln('最近回复：${overview.lastAssistantSnippet}');
    }
    return _limit(buffer.toString());
  }

  /// 消息所属轮次的上下文
  static Future<String> _eventTrace(
    Map<String, dynamic> args,
    String? currentSessionId,
  ) async {
    final id = _idOf(args);
    if (id == null) return '参数不合法：id 必填且为整数';
    final sessionId = _sessionOf(args, currentSessionId);
    if (sessionId == null) return '当前没有可检索的会话';
    final maxMessages = _intOf(args, 'max_messages', def: 10, min: 1, max: 20);

    final hits = await ChatDatabase.instance
        .turnContext(sessionId, id, maxMessages: maxMessages);
    if (!hits.any((hit) => hit.id == id)) return '未找到消息 #$id';

    final buffer = StringBuffer('消息 #$id 所属轮次（共 ${hits.length} 条）：');
    for (final hit in hits) {
      final tool = hit.toolName == null ? '' : '（${hit.toolName}）';
      buffer.writeln(
        '\n[id ${hit.id}] ${hit.role}$tool ${_fmt(hit.createdAt)}\n'
        '  ${_clip(hit.content, 200)}',
      );
    }
    return _limit(buffer.toString());
  }

  // ---------- 参数与格式化辅助 ----------

  static String? _queryOf(Map<String, dynamic> args) {
    final raw = args['query'];
    final text = raw is String ? raw.trim() : '';
    return text.isEmpty ? null : text;
  }

  static String? _sessionOf(Map<String, dynamic> args, String? current) {
    final raw = args['session_id'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    final fallback = current?.trim();
    return (fallback == null || fallback.isEmpty) ? null : fallback;
  }

  static int? _idOf(Map<String, dynamic> args) {
    final raw = args['id'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }

  static int _intOf(
    Map<String, dynamic> args,
    String key, {
    required int def,
    required int min,
    required int max,
  }) {
    final raw = args[key];
    var value = def;
    if (raw is num) value = raw.toInt();
    if (raw is String) value = int.tryParse(raw.trim()) ?? def;
    return value.clamp(min, max);
  }

  /// 返回 (解析结果, 是否非法)
  static (DateTime?, bool) _timeOf(Object? raw) {
    if (raw == null) return (null, false);
    final text = raw.toString().trim();
    if (text.isEmpty) return (null, false);
    final parsed = DateTime.tryParse(text);
    return (parsed, parsed == null);
  }

  static String _fmt(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  static String _clip(String text, int max) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= max ? flat : '${flat.substring(0, max)}…';
  }

  static String _limit(String text) => text.length <= _maxOutputChars
      ? text
      : '${text.substring(0, _maxOutputChars)}\n…（内容过长已截断）';
}
