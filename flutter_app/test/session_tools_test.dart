import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dodroidai/ai/session_tools.dart';
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

    final base = DateTime(2026, 3, 1, 9).millisecondsSinceEpoch;
    await db.insert('sessions', {
      'id': 's1',
      'name': '买咖啡机',
      'updated_at': base,
    });
    await db.insert('sessions', {
      'id': 's2',
      'name': '周末计划',
      'updated_at': base + 1000,
    });
    await db.insert('messages', {
      'session_id': 's1',
      'role': 'user',
      'content': '我想买一台咖啡机，预算 3000',
      'blocks': '',
      'created_at': base,
    });
    await db.insert('messages', {
      'session_id': 's1',
      'role': 'assistant',
      'content': '推荐几款咖啡机',
      'blocks': '',
      'created_at': base + 1000,
    });
    await db.insert('messages', {
      'session_id': 's2',
      'role': 'user',
      'content': '周末去爬山吧',
      'blocks': '',
      'created_at': base + 2000,
    });
  });

  tearDown(() async {
    await chat.closeForTest();
  });

  test('session_search 跨会话聚合输出', () async {
    final output = await SessionTools.execute(
      'session_search',
      {'query': '咖啡机'},
    );
    expect(output, contains('s1'));
    expect(output, contains('命中 2 条'));
    expect(output, contains('片段'));
  });

  test('session_event_search 在当前会话内检索', () async {
    final output = await SessionTools.execute(
      'session_event_search',
      {'query': '咖啡机'},
      currentSessionId: 's1',
    );
    expect(output, contains('会话 s1'));
    expect(output, contains('user'));
    expect(output, contains('咖啡机'));

    final filtered = await SessionTools.execute(
      'session_event_search',
      {'query': '咖啡机', 'role': 'assistant'},
      currentSessionId: 's1',
    );
    expect(filtered, contains('推荐几款咖啡机'));
    expect(filtered, isNot(contains('预算 3000')));
  });

  test('session_event_read 输出全文与前后文', () async {
    final output = await SessionTools.execute(
      'session_event_read',
      {'id': 2, 'before': 1, 'after': 1},
      currentSessionId: 's1',
    );
    expect(output, contains('消息 #2'));
    expect(output, contains('推荐几款咖啡机'));
    expect(output, contains('前文'));
  });

  test('session_trace 输出会话概览', () async {
    final output = await SessionTools.execute(
      'session_trace',
      {},
      currentSessionId: 's1',
    );
    expect(output, contains('买咖啡机'));
    expect(output, contains('消息 2 条'));
    expect(output, contains('user 1 / assistant 1 / tool 0'));
  });

  test('session_event_trace 输出所属轮次', () async {
    final output = await SessionTools.execute(
      'session_event_trace',
      {'id': 2},
      currentSessionId: 's1',
    );
    expect(output, contains('所属轮次'));
    expect(output, contains('推荐几款咖啡机'));
  });

  test('缺参数与缺会话的错误文案', () async {
    expect(
      await SessionTools.execute('session_search', {}),
      '参数不合法：query 不能为空',
    );
    expect(
      await SessionTools.execute('session_event_search', {'query': 'x'}),
      '当前没有可检索的会话',
    );
    expect(
      await SessionTools.execute('session_event_read', {'id': 999}, currentSessionId: 's1'),
      '未找到消息 #999',
    );
    expect(
      await SessionTools.execute('session_trace', {}, currentSessionId: 'nope'),
      '未找到会话 nope',
    );
    expect(
      await SessionTools.execute(
        'session_event_search',
        {'query': 'x', 'role': 'bad'},
        currentSessionId: 's1',
      ),
      '参数不合法：role 只能是 user / assistant / tool',
    );
  });
}
