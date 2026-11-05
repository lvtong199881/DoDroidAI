import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class ToolAuditEntry {
  ToolAuditEntry({
    required this.id,
    required this.toolName,
    required this.argsSummary,
    required this.resultSummary,
    required this.success,
    required this.createdAt,
  });

  final int id;
  final String toolName;
  final String argsSummary;
  final String resultSummary;
  final bool success;
  final int createdAt;
}

class ToolAuditRepository {
  static final ToolAuditRepository instance = ToolAuditRepository._();

  ToolAuditRepository._();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'tool_audit.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE tool_audit (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'tool_name TEXT, args_summary TEXT, result_summary TEXT, '
          'success INTEGER, created_at INTEGER)',
        );
      },
    );
    return _db!;
  }

  Future<List<ToolAuditEntry>> list({int limit = 200}) async {
    final db = await _open();
    final rows = await db.query(
      'tool_audit',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows
        .map((r) => ToolAuditEntry(
              id: r['id'] as int,
              toolName: r['tool_name'] as String? ?? '',
              argsSummary: r['args_summary'] as String? ?? '',
              resultSummary: r['result_summary'] as String? ?? '',
              success: (r['success'] as int? ?? 1) == 1,
              createdAt: r['created_at'] as int? ?? 0,
            ))
        .toList();
  }

  Future<void> insert({
    required String toolName,
    required String argsSummary,
    required String resultSummary,
    required bool success,
  }) async {
    final db = await _open();
    await db.insert('tool_audit', {
      'tool_name': toolName,
      'args_summary': argsSummary,
      'result_summary': resultSummary,
      'success': success ? 1 : 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> clear() async {
    final db = await _open();
    await db.delete('tool_audit');
  }
}
