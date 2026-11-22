import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:dodroidai/settings/welcome_flag_store.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('welcome_flag_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  FileWelcomeFlagStore store() =>
      FileWelcomeFlagStore(supportDirectory: () async => tempDir);

  File flagFile() =>
      File(p.join(tempDir.path, FileWelcomeFlagStore.flagRelativePath));

  test('标记路径固定为 welcome/welcome_dialog_shown_v1', () {
    expect(
      FileWelcomeFlagStore.flagRelativePath,
      'welcome/welcome_dialog_shown_v1',
    );
  });

  test('文件缺失视为未展示', () async {
    expect(await store().read(), isFalse);
  });

  test('写入后内容为 1 且读取为 true', () async {
    final flagStore = store();
    await flagStore.write();

    final file = flagFile();
    expect(await file.exists(), isTrue);
    expect(await file.readAsString(), '1');
    expect(await flagStore.read(), isTrue);
    expect(p.basename(file.parent.path), 'welcome');
  });

  test('内容为 0 视为未展示', () async {
    final file = flagFile();
    await file.parent.create(recursive: true);
    await file.writeAsString('0');

    expect(await store().read(), isFalse);
  });

  test('内容为 1 加换行也视为已展示', () async {
    final file = flagFile();
    await file.parent.create(recursive: true);
    await file.writeAsString('1\n');

    expect(await store().read(), isTrue);
  });

  test('内容损坏抛 FormatException', () async {
    final file = flagFile();
    await file.parent.create(recursive: true);
    await file.writeAsString('yes');

    await expectLater(store().read(), throwsA(isA<FormatException>()));
  });

  test('读取 IO 失败向上抛异常', () async {
    final failing = FileWelcomeFlagStore(
      supportDirectory: () async =>
          throw const FileSystemException('应用私有目录不可用'),
    );

    await expectLater(
      failing.read(),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('写入失败向上抛异常', () async {
    // 用同名文件占住 welcome 目录位置，导致目录无法创建
    await File(p.join(tempDir.path, 'welcome')).writeAsString('x');

    await expectLater(store().write(), throwsA(isA<FileSystemException>()));
  });
}
