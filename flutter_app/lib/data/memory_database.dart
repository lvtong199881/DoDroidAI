import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class MemoryFact {
  MemoryFact({
    required this.id,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final String content;
  final int createdAt;
}

class MemoryRepository {
  static final MemoryRepository instance = MemoryRepository._();

  MemoryRepository._();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'memory.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE memory_facts (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'content TEXT, created_at INTEGER)',
        );
      },
    );
    return _db!;
  }

  Future<List<MemoryFact>> list() async {
    final db = await _open();
    final rows = await db.query('memory_facts', orderBy: 'created_at DESC');
    return rows
        .map((r) => MemoryFact(
              id: r['id'] as int,
              content: r['content'] as String? ?? '',
              createdAt: r['created_at'] as int? ?? 0,
            ))
        .toList();
  }

  Future<void> insert(String content) async {
    final db = await _open();
    await db.insert('memory_facts', {
      'content': content,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> delete(int id) async {
    final db = await _open();
    await db.delete('memory_facts', where: 'id = ?', whereArgs: [id]);
  }
}
