import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/chat_message.dart';

class ChatSession {
  ChatSession({required this.id, required this.name, required this.updatedAt});

  final String id;
  final String name;
  final int updatedAt;
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
      version: 2,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE sessions (id TEXT PRIMARY KEY, name TEXT, updated_at INTEGER)',
        );
        await db.execute(
          'CREATE TABLE messages (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'session_id TEXT, role TEXT, content TEXT, reasoning TEXT, '
          'tool_calls TEXT, images TEXT, created_at INTEGER)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE messages ADD COLUMN images TEXT');
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
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  Future<void> insertMessage(String sessionId, ChatMessage message) async {
    final db = await _open();
    await db.insert('messages', {
      'session_id': sessionId,
      'role': message.role.name,
      'content': message.content,
      'reasoning': message.reasoning,
      'tool_calls': jsonEncode(const []),
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
        reasoning: r['reasoning'] as String?,
        images: _decodeImages(r['images'] as String?),
      );
    }).toList();
  }
}
