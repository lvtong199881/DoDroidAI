import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class Note {
  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String content;
  final int createdAt;
}

class NoteRepository {
  static final NoteRepository instance = NoteRepository._();

  NoteRepository._();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'notes.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE notes (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'title TEXT, content TEXT, created_at INTEGER)',
        );
      },
    );
    return _db!;
  }

  Future<List<Note>> list() async {
    final db = await _open();
    final rows = await db.query('notes', orderBy: 'created_at DESC');
    return rows
        .map((r) => Note(
              id: r['id'] as int,
              title: r['title'] as String? ?? '',
              content: r['content'] as String? ?? '',
              createdAt: r['created_at'] as int? ?? 0,
            ))
        .toList();
  }

  Future<void> insert(String title, String content) async {
    final db = await _open();
    await db.insert('notes', {
      'title': title,
      'content': content,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> delete(int id) async {
    final db = await _open();
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
}
