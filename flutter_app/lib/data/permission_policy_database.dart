import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// 记录用户拒绝过的权限，避免反复弹窗
class PermissionPolicyRepository {
  static final PermissionPolicyRepository instance =
      PermissionPolicyRepository._();

  PermissionPolicyRepository._();

  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'permission_policy.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE permission_policy (permission TEXT PRIMARY KEY, denied INTEGER)',
        );
      },
    );
    return _db!;
  }

  Future<bool> isDenied(String permission) async {
    final db = await _open();
    final rows = await db.query(
      'permission_policy',
      where: 'permission = ?',
      whereArgs: [permission],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> setDenied(String permission) async {
    final db = await _open();
    await db.insert(
      'permission_policy',
      {'permission': permission, 'denied': 1},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearAll() async {
    final db = await _open();
    await db.delete('permission_policy');
  }
}
