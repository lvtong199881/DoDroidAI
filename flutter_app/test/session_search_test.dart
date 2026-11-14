import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dodroidai/data/chat_database.dart';

void main() {
  final chat = ChatDatabase.instance;
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE sessions (id TEXT PRIMARY KEY, name TEXT, '
            'updated_at INTEGER)',
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
      ),
    );
    chat.useDatabaseForTest(db);
  });

  tearDown(() async {
    await chat.closeForTest();
  });

  Future<int> addMessage(
    String sessionId,
    String role,
    String content, {
    String blocks = '',
    int? createdAt,
  }) {
    return db.insert('messages', {
      'session_id': sessionId,
      'role': role,
      'content': content,
      'blocks': blocks,
      'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> addSession(String id, String name) {
    return db.insert('sessions', {
      'id': id,
      'name': name,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  test('searchMessages 命中关键词并按 role 过滤', () async {
    await addSession('s1', '买咖啡机');
    await addMessage('s1', 'user', '我想买一台咖啡机');
    await addMessage('s1', 'assistant', '推荐几款咖啡机');
    await addMessage('s1', 'tool', '搜索结果：咖啡机');

    final all = await chat.searchMessages('咖啡机', sessionId: 's1');
    expect(all.length, 3);
    expect(all.first.snippet, contains('咖啡机'));

    final users = await chat.searchMessages(
      '咖啡机',
      sessionId: 's1',
      role: 'user',
    );
    expect(users.length, 1);
    expect(users.first.role, 'user');
  });

  test('关键词里的 % 与 _ 按字面量匹配', () async {
    await addSession('s1', '甲');
    await addMessage('s1', 'user', '进度 50% 完成');
    await addMessage('s1', 'user', '普通消息');

    final literal = await chat.searchMessages('50%', sessionId: 's1');
    expect(literal.length, 1);

    // 若 % 未转义会命中两条，这里应当只命中含字面 % 的那条
    final percent = await chat.searchMessages('%', sessionId: 's1');
    expect(percent.length, 1);
    expect(percent.first.content, contains('50%'));
  });

  test('时间窗过滤生效', () async {
    await addSession('s1', '甲');
    final base = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    await addMessage('s1', 'user', '早上的消息', createdAt: base);
    await addMessage(
      's1',
      'user',
      '晚上的消息',
      createdAt: base + 3600 * 1000,
    );

    final later = await chat.searchMessages(
      '消息',
      sessionId: 's1',
      sinceMs: base + 1800 * 1000,
    );
    expect(later.length, 1);
    expect(later.first.content, '晚上的消息');

    final earlier = await chat.searchMessages(
      '消息',
      sessionId: 's1',
      untilMs: base + 1800 * 1000,
    );
    expect(earlier.length, 1);
    expect(earlier.first.content, '早上的消息');
  });

  test('searchAllSessions 跨会话命中并带 sessionId', () async {
    await addSession('s1', '甲');
    await addSession('s2', '乙');
    await addMessage('s1', 'user', '周末去看电影');
    await addMessage('s2', 'assistant', '电影推荐清单');

    final hits = await chat.searchAllSessions('电影');
    expect(hits.length, 2);
    expect(hits.map((h) => h.sessionId).toSet(), {'s1', 's2'});
  });

  test('messageWindow 返回目标与前后条数', () async {
    await addSession('s1', '甲');
    await addMessage('s1', 'user', '问题一');
    await addMessage('s1', 'assistant', '回答一');
    final target = await addMessage('s1', 'user', '问题二');
    await addMessage('s1', 'assistant', '回答二');

    final window = await chat.messageWindow('s1', target, before: 1, after: 1);
    expect(window.map((h) => h.id), [target - 1, target, target + 1]);
  });

  test('sessionOverview 统计角色与首末消息', () async {
    await addSession('s1', '周末计划');
    final base = DateTime(2026, 2, 1).millisecondsSinceEpoch;
    await addMessage('s1', 'user', '帮我规划周末', createdAt: base);
    await addMessage('s1', 'assistant', '推荐去爬山', createdAt: base + 1000);
    await addMessage('s1', 'tool', '天气晴', createdAt: base + 2000);

    final overview = await chat.sessionOverview('s1');
    expect(overview, isNotNull);
    expect(overview!.name, '周末计划');
    expect(overview.messageCount, 3);
    expect(overview.userCount, 1);
    expect(overview.assistantCount, 1);
    expect(overview.toolCount, 1);
    expect(overview.firstAt, base);
    expect(overview.lastAt, base + 2000);
    expect(overview.firstUserSnippet, contains('规划周末'));
    expect(overview.lastAssistantSnippet, contains('爬山'));
  });

  test('turnContext 按 user 消息切分轮次', () async {
    await addSession('s1', '甲');
    final q1 = await addMessage('s1', 'user', '问题一');
    final a1 = await addMessage('s1', 'assistant', '回答一');
    final q2 = await addMessage('s1', 'user', '问题二');
    final a2 = await addMessage('s1', 'assistant', '回答二');
    final t2 = await addMessage('s1', 'tool', '结果二');

    final firstTurn = await chat.turnContext('s1', a1);
    expect(firstTurn.map((h) => h.id), [q1, a1]);

    final secondTurn = await chat.turnContext('s1', a2);
    expect(secondTurn.map((h) => h.id), [q2, a2, t2]);
  });

  test('未找到会话返回 null', () async {
    expect(await chat.sessionOverview('missing'), isNull);
  });
}
