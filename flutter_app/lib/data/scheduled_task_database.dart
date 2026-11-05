import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class ScheduledTask {
  ScheduledTask({
    required this.id,
    required this.title,
    required this.prompt,
    required this.schedule,
    required this.enabled,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String prompt;
  final String schedule;
  final bool enabled;
  final int createdAt;
}

class ScheduledTaskRepository {
  static final ScheduledTaskRepository instance = ScheduledTaskRepository._();

  ScheduledTaskRepository._();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'tasks.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE scheduled_tasks (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'title TEXT, prompt TEXT, schedule TEXT, enabled INTEGER, created_at INTEGER)',
        );
      },
    );
    return _db!;
  }

  Future<List<ScheduledTask>> list() async {
    final db = await _open();
    final rows = await db.query('scheduled_tasks', orderBy: 'created_at DESC');
    return rows
        .map((r) => ScheduledTask(
              id: r['id'] as int,
              title: r['title'] as String? ?? '',
              prompt: r['prompt'] as String? ?? '',
              schedule: r['schedule'] as String? ?? '',
              enabled: (r['enabled'] as int? ?? 1) == 1,
              createdAt: r['created_at'] as int? ?? 0,
            ))
        .toList();
  }

  Future<void> insert({
    required String title,
    required String prompt,
    required String schedule,
  }) async {
    final db = await _open();
    await db.insert('scheduled_tasks', {
      'title': title,
      'prompt': prompt,
      'schedule': schedule,
      'enabled': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> setEnabled(int id, bool enabled) async {
    final db = await _open();
    await db.update(
      'scheduled_tasks',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _open();
    await db.delete('scheduled_tasks', where: 'id = ?', whereArgs: [id]);
  }
}
