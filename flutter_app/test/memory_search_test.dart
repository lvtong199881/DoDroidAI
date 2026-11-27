import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dodroidai/data/memory_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('完全相同的记忆去重：返回已有条目而不是新插入', () async {
    final repo = MemoryRepository.instance;
    final first = await repo.insert('我的紧急联系人电话是 13800001111');
    final second = await repo.insert('我的紧急联系人电话是 13800001111');
    expect(second.id, first.id);
    await repo.delete(first.id);
  });

  test('searchRelevant：相关记忆排在不相关前面', () async {
    final repo = MemoryRepository.instance;
    final coffee = await repo.insert('用户每天早上都喝一杯美式咖啡');
    final cat = await repo.insert('用户家里养了一只橘猫叫年糕');
    final hits = await repo.searchRelevant('用户平时喜欢喝什么咖啡', limit: 2);
    expect(hits, isNotEmpty);
    expect(hits.first.id, coffee.id);
    // 相关条目的分数应明显高于不相关条目
    final catHit = hits.where((h) => h.id == cat.id).toList();
    if (catHit.isNotEmpty) {
      expect(hits.first.score, greaterThan(catHit.first.score));
    }
    await repo.delete(coffee.id);
    await repo.delete(cat.id);
  });

  test('searchRelevant：limit 截断与空查询', () async {
    final repo = MemoryRepository.instance;
    expect(await repo.searchRelevant('   '), isEmpty);
    final a = await repo.insert('记得每天给绿萝浇水');
    final b = await repo.insert('项目 deadline 是下周五');
    final c = await repo.insert('用户偏好简洁的回答风格');
    final hits = await repo.searchRelevant('绿萝', limit: 2);
    expect(hits.length <= 2, isTrue);
    expect(hits.first.id, a.id);
    await repo.delete(a.id);
    await repo.delete(b.id);
    await repo.delete(c.id);
  });

  test('旧数据缺 embedding 时检索中懒回填', () async {
    final repo = MemoryRepository.instance;
    final fact = await repo.insert('用户的名字叫莫寒');
    // 直接抹掉向量模拟旧版本数据
    final db = repo.debugDb;
    expect(db, isNotNull);
    await db!.update(
      'memory_facts',
      {'embedding': null},
      where: 'id = ?',
      whereArgs: [fact.id],
    );
    final hits = await repo.searchRelevant('用户叫什么名字', limit: 3);
    final hit = hits.where((h) => h.id == fact.id).toList();
    expect(hit, isNotEmpty);
    expect(hit.first.score, greaterThan(0));
    // 回填后向量已写回
    final row = await db.query(
      'memory_facts',
      where: 'id = ?',
      whereArgs: [fact.id],
    );
    expect(row.first['embedding'], isNotNull);
    await repo.delete(fact.id);
  });
}
