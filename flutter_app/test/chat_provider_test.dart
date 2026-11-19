import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dodroidai/data/chat_database.dart';
import 'package:dodroidai/screens/chat/chat_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<ChatController> buildController() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE sessions (id TEXT PRIMARY KEY, name TEXT, updated_at INTEGER)',
          );
        },
      ),
    );
    final chatDb = ChatDatabase.instance;
    chatDb.useDatabaseForTest(db);
    return ChatController(database: chatDb);
  }

  test('自动朗读默认开启，关闭后持久化', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await buildController();
    await controller.ensureReady();
    expect(controller.state.autoRead, isTrue);

    controller.toggleAutoRead();
    expect(controller.state.autoRead, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ChatController.autoReadPrefKey), isFalse);

    controller.dispose();
    await ChatDatabase.instance.closeForTest();
  });

  test('重启后读取持久化的自动朗读状态', () async {
    SharedPreferences.setMockInitialValues({
      ChatController.autoReadPrefKey: false,
    });
    final controller = await buildController();
    await controller.ensureReady();
    expect(controller.state.autoRead, isFalse);

    controller.dispose();
    await ChatDatabase.instance.closeForTest();
  });
}
