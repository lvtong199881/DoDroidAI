import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/ask_question.dart';
import '../models/chat_message.dart';

class ChatSession {
  ChatSession({required this.id, required this.name, required this.updatedAt});

  final String id;
  final String name;
  final int updatedAt;
}

/// 会话检索命中的一条消息（含命中片段，供工具层直接展示）
class MessageHit {
  MessageHit({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.snippet,
    this.toolName,
  });

  final int id;
  final String sessionId;
  final String role;
  final String content;
  final int createdAt;
  final String snippet;

  /// 该条消息里第一个工具调用的名称（无则 null）
  final String? toolName;
}

/// 会话概览：session_trace 的返回数据
class SessionOverview {
  SessionOverview({
    required this.id,
    required this.name,
    required this.messageCount,
    required this.userCount,
    required this.assistantCount,
    required this.toolCount,
    required this.firstAt,
    required this.lastAt,
    required this.firstUserSnippet,
    required this.lastAssistantSnippet,
  });

  final String id;
  final String name;
  final int messageCount;
  final int userCount;
  final int assistantCount;
  final int toolCount;
  final int? firstAt;
  final int? lastAt;
  final String? firstUserSnippet;
  final String? lastAssistantSnippet;
}

class ChatDatabase {
  static final ChatDatabase instance = ChatDatabase._();

  ChatDatabase._();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'dodroidai_flutter.db'),
      version: 5,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE sessions (id TEXT PRIMARY KEY, name TEXT, updated_at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE messages (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'session_id TEXT, role TEXT, content TEXT, blocks TEXT, '
          'tool_call_id TEXT, images TEXT, created_at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE pending_questions (id TEXT PRIMARY KEY, '
          'session_id TEXT, call_id TEXT, questions TEXT, '
          'created_at INTEGER, answered_at INTEGER)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE messages ADD COLUMN images TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE messages ADD COLUMN blocks TEXT');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE messages ADD COLUMN tool_call_id TEXT');
        }
        if (oldVersion < 5) {
          await db.execute(
            'CREATE TABLE pending_questions (id TEXT PRIMARY KEY, '
            'session_id TEXT, call_id TEXT, questions TEXT, '
            'created_at INTEGER, answered_at INTEGER)',
          );
        }
      },
    );
    return _db!;
  }

  Future<void> ensureSession(String id, String name) async {
    final db = await _open();
    final existing = await db.query('sessions', where: 'id = ?', whereArgs: [id]);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (existing.isEmpty) {
      await db.insert('sessions', {
        'id': id,
        'name': name,
        'updated_at': now,
      });
    } else {
      await db.update('sessions', {'updated_at': now},
          where: 'id = ?', whereArgs: [id]);
    }
  }

  List<String> _decodeImages(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {
      // ignore invalid json
    }
    return const [];
  }

  Future<List<ChatSession>> sessions() async {
    final db = await _open();
    final rows = await db.query('sessions', orderBy: 'updated_at DESC');
    return rows
        .map((r) => ChatSession(
              id: r['id'] as String,
              name: r['name'] as String? ?? '',
              updatedAt: r['updated_at'] as int? ?? 0,
            ))
        .toList();
  }

  Future<void> renameSession(String sessionId, String name) async {
    final db = await _open();
    await db.update('sessions', {'name': name},
        where: 'id = ?', whereArgs: [sessionId]);
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await _open();
    await db.delete('messages', where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('pending_questions',
        where: 'session_id = ?', whereArgs: [sessionId]);
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  /// 超时未答的问题落库，支持重启后补答
  Future<void> insertPendingQuestion(PendingQuestion pending) async {
    final db = await _open();
    await db.insert(
      'pending_questions',
      {
        'id': pending.callId,
        'session_id': pending.sessionId,
        'call_id': pending.callId,
        'questions': pending.questionsJson,
        'created_at': pending.createdAt.millisecondsSinceEpoch,
        'answered_at': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 某个会话下所有未回答的问题
  Future<List<PendingQuestion>> pendingQuestionsOf(String sessionId) async {
    final db = await _open();
    final rows = await db.query(
      'pending_questions',
      where: 'session_id = ? AND answered_at IS NULL',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return rows.map(PendingQuestion.fromRow).toList();
  }

  Future<void> markPendingAnswered(String id) async {
    final db = await _open();
    await db.update(
      'pending_questions',
      {'answered_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertMessage(String sessionId, ChatMessage message) async {
    final db = await _open();
    await db.insert('messages', {
      'session_id': sessionId,
      'role': message.role.name,
      'content': message.content,
      'blocks': message.blocksToJson(),
      'tool_call_id': message.toolCallId,
      'images': jsonEncode(message.images),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    await db.update(
      'sessions',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// 保留前 keepCount 条消息，删除其余（重试用）
  Future<void> clearMessagesAfter(String sessionId, int keepCount) async {
    final db = await _open();
    final rows = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'id ASC',
    );
    if (rows.length <= keepCount) return;
    final ids = rows.skip(keepCount).map((r) => r['id'] as int).toList();
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete('messages', where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<List<ChatMessage>> messagesOf(String sessionId) async {
    final db = await _open();
    final rows = await db.query(
      'messages',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'id ASC',
    );
    return rows.map((r) {
      return ChatMessage(
        role: (r['role'] as String?) == 'user' ? ChatRole.user : ChatRole.assistant,
        content: r['content'] as String? ?? '',
        blocks: ChatMessage.blocksFromJson(r['blocks'] as String?),
        toolCallId: r['tool_call_id'] as String?,
        images: _decodeImages(r['images'] as String?),
      );
    }).toList();
  }

  /// 测试注入：用内存库替换真实连接
  @visibleForTesting
  void useDatabaseForTest(Database db) {
    _db = db;
  }

  @visibleForTesting
  Future<void> closeForTest() async {
    await _db?.close();
    _db = null;
  }

  static String _escapeLike(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  static String _clip(String text, int max) {
    final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length <= max ? flat : '${flat.substring(0, max)}…';
  }

  /// 命中片段：关键词前后各取 context 个字符
  static String _snippet(String content, String query, {int context = 80}) {
    final flat = content.replaceAll(RegExp(r'\s+'), ' ');
    final idx = flat.toLowerCase().indexOf(query.toLowerCase());
    if (idx < 0) return _clip(content, 200);
    final start = (idx - context).clamp(0, flat.length);
    final end = (idx + query.length + context).clamp(0, flat.length);
    final prefix = start > 0 ? '…' : '';
    final suffix = end < flat.length ? '…' : '';
    return '$prefix${flat.substring(start, end)}$suffix';
  }

  MessageHit _hitFromRow(Map<String, Object?> row, String query) {
    final content = row['content'] as String? ?? '';
    String? toolName;
    for (final block
        in ChatMessage.blocksFromJson(row['blocks'] as String?)) {
      if (block.kind == MessageBlockKind.toolCall && block.tool != null) {
        toolName = block.tool!.name;
        break;
      }
    }
    return MessageHit(
      id: row['id'] as int? ?? 0,
      sessionId: row['session_id'] as String? ?? '',
      role: row['role'] as String? ?? '',
      content: content,
      createdAt: row['created_at'] as int? ?? 0,
      snippet: _snippet(content, query),
      toolName: toolName,
    );
  }

  /// 单会话内按关键词检索消息（content 与 blocks 都参与匹配）
  Future<List<MessageHit>> searchMessages(
    String query, {
    String? sessionId,
    String? role,
    int limit = 10,
    int? sinceMs,
    int? untilMs,
  }) async {
    final db = await _open();
    final pattern = '%${_escapeLike(query)}%';
    final where = StringBuffer(
      "((content LIKE ? ESCAPE '\\') OR (blocks LIKE ? ESCAPE '\\'))",
    );
    final args = <Object?>[pattern, pattern];
    if (sessionId != null) {
      where.write(' AND session_id = ?');
      args.add(sessionId);
    }
    if (role != null) {
      where.write(' AND role = ?');
      args.add(role);
    }
    if (sinceMs != null) {
      where.write(' AND created_at >= ?');
      args.add(sinceMs);
    }
    if (untilMs != null) {
      where.write(' AND created_at <= ?');
      args.add(untilMs);
    }
    args.add(limit);
    final rows = await db.rawQuery(
      'SELECT id, session_id, role, content, created_at FROM messages '
      'WHERE $where ORDER BY id DESC LIMIT ?',
      args,
    );
    return rows.map((r) => _hitFromRow(r, query)).toList();
  }

  /// 跨会话扫描命中（按时间倒序，由调用方按会话聚合）
  Future<List<MessageHit>> searchAllSessions(
    String query, {
    int scanLimit = 500,
  }) async {
    final db = await _open();
    final pattern = '%${_escapeLike(query)}%';
    final rows = await db.rawQuery(
      'SELECT id, session_id, role, content, created_at FROM messages '
      "WHERE (content LIKE ? ESCAPE '\\') OR (blocks LIKE ? ESCAPE '\\') "
      'ORDER BY created_at DESC LIMIT ?',
      [pattern, pattern, scanLimit],
    );
    return rows.map((r) => _hitFromRow(r, query)).toList();
  }

  /// 目标消息 + 前后若干条（按 id 排序返回）
  Future<List<MessageHit>> messageWindow(
    String sessionId,
    int messageId, {
    int before = 2,
    int after = 2,
    String query = '',
  }) async {
    final db = await _open();
    final prev = await db.rawQuery(
      'SELECT id, session_id, role, content, created_at FROM messages '
      'WHERE session_id = ? AND id < ? ORDER BY id DESC LIMIT ?',
      [sessionId, messageId, before],
    );
    final target = await db.rawQuery(
      'SELECT id, session_id, role, content, created_at FROM messages '
      'WHERE session_id = ? AND id = ? LIMIT 1',
      [sessionId, messageId],
    );
    final next = await db.rawQuery(
      'SELECT id, session_id, role, content, created_at FROM messages '
      'WHERE session_id = ? AND id > ? ORDER BY id ASC LIMIT ?',
      [sessionId, messageId, after],
    );
    return [
      ...prev.reversed.map((r) => _hitFromRow(r, query)),
      ...target.map((r) => _hitFromRow(r, query)),
      ...next.map((r) => _hitFromRow(r, query)),
    ];
  }

  /// 消息所属轮次：前一个 user 到下一个 user 之间的消息
  Future<List<MessageHit>> turnContext(
    String sessionId,
    int messageId, {
    int maxMessages = 10,
  }) async {
    final db = await _open();
    final startRows = await db.rawQuery(
      'SELECT id FROM messages WHERE session_id = ? AND id <= ? AND role = ? '
      'ORDER BY id DESC LIMIT 1',
      [sessionId, messageId, 'user'],
    );
    final startId =
        startRows.isEmpty ? messageId : startRows.first['id'] as int;
    final nextUser = await db.rawQuery(
      'SELECT id FROM messages WHERE session_id = ? AND id > ? AND role = ? '
      'ORDER BY id ASC LIMIT 1',
      [sessionId, messageId, 'user'],
    );
    final endId = nextUser.isEmpty ? null : nextUser.first['id'] as int;
    final where = endId == null
        ? 'session_id = ? AND id >= ?'
        : 'session_id = ? AND id >= ? AND id < ?';
    final args =
        endId == null ? [sessionId, startId] : [sessionId, startId, endId];
    final rows = await db.rawQuery(
      'SELECT id, session_id, role, content, created_at FROM messages '
      'WHERE $where ORDER BY id ASC LIMIT ?',
      [...args, maxMessages],
    );
    return rows.map((r) => _hitFromRow(r, '')).toList();
  }

  /// 会话概览；会话不存在时返回 null
  Future<SessionOverview?> sessionOverview(String sessionId) async {
    final db = await _open();
    final session = await db.query(
      'sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    if (session.isEmpty) return null;
    final counts = await db.rawQuery(
      'SELECT COUNT(*) AS n, MIN(created_at) AS first_at, '
      'MAX(created_at) AS last_at FROM messages WHERE session_id = ?',
      [sessionId],
    );
    final roleRows = await db.rawQuery(
      'SELECT role, COUNT(*) AS n FROM messages WHERE session_id = ? '
      'GROUP BY role',
      [sessionId],
    );
    final roleCounts = <String, int>{
      for (final r in roleRows)
        (r['role'] as String? ?? ''): (r['n'] as int? ?? 0),
    };
    final firstUser = await db.rawQuery(
      'SELECT content FROM messages WHERE session_id = ? AND role = ? '
      'ORDER BY id ASC LIMIT 1',
      [sessionId, 'user'],
    );
    final lastAssistant = await db.rawQuery(
      "SELECT content FROM messages WHERE session_id = ? AND role = 'assistant' "
      'ORDER BY id DESC LIMIT 1',
      [sessionId],
    );
    final first = counts.first;
    return SessionOverview(
      id: sessionId,
      name: session.first['name'] as String? ?? '',
      messageCount: first['n'] as int? ?? 0,
      userCount: roleCounts['user'] ?? 0,
      assistantCount: roleCounts['assistant'] ?? 0,
      toolCount: roleCounts['tool'] ?? 0,
      firstAt: first['first_at'] as int?,
      lastAt: first['last_at'] as int?,
      firstUserSnippet: firstUser.isEmpty
          ? null
          : _clip(firstUser.first['content'] as String? ?? '', 120),
      lastAssistantSnippet: lastAssistant.isEmpty
          ? null
          : _clip(lastAssistant.first['content'] as String? ?? '', 200),
    );
  }
}
