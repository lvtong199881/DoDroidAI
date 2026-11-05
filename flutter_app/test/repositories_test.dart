import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dodroidai/data/memory_database.dart';
import 'package:dodroidai/data/note_database.dart';
import 'package:dodroidai/data/permission_policy_database.dart';
import 'package:dodroidai/data/tool_audit_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('note repository crud', () async {
    final repo = NoteRepository.instance;
    final before = await repo.list();
    await repo.insert('测试标题', '测试内容');
    final after = await repo.list();
    expect(after.length, before.length + 1);
    expect(after.first.title, '测试标题');
    await repo.delete(after.first.id);
    expect((await repo.list()).length, before.length);
  });

  test('memory repository crud', () async {
    final repo = MemoryRepository.instance;
    final before = await repo.list();
    await repo.insert('用户喜欢喝咖啡');
    final after = await repo.list();
    expect(after.length, before.length + 1);
    expect(after.first.content, '用户喜欢喝咖啡');
    await repo.delete(after.first.id);
    expect((await repo.list()).length, before.length);
  });

  test('tool audit insert and clear', () async {
    final repo = ToolAuditRepository.instance;
    await repo.clear();
    await repo.insert(
      toolName: 'get_current_time',
      argsSummary: '{}',
      resultSummary: '2026-01-01T00:00:00',
      success: true,
    );
    final entries = await repo.list();
    expect(entries.length, 1);
    expect(entries.first.toolName, 'get_current_time');
    expect(entries.first.success, isTrue);
    await repo.clear();
    expect((await repo.list()).isEmpty, isTrue);
  });

  test('permission policy remember and reset', () async {
    final repo = PermissionPolicyRepository.instance;
    await repo.clearAll();
    expect(await repo.isDenied('microphone'), isFalse);
    await repo.setDenied('microphone');
    expect(await repo.isDenied('microphone'), isTrue);
    await repo.clearAll();
    expect(await repo.isDenied('microphone'), isFalse);
  });
}
