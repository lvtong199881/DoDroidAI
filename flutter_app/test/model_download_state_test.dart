import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/ai/model_catalog.dart';
import 'package:dodroidai/ai/model_manager.dart';

/// 造一个测试用模型（清单大小可自定义，不必真的写那么大）
const _model = VoiceModel(
  id: 'probe_model',
  displayName: 'probe',
  repo: 'probe/repo',
  files: [
    ModelFile('weights.onnx', 2000000),
    ModelFile('tokens.txt', 3000),
  ],
  languages: 'probe',
);

void main() {
  late Directory support;
  late Directory modelDir;

  setUp(() {
    support = Directory.systemTemp.createTempSync('model_state_test');
    modelDir = Directory('${support.path}/stt_models/${_model.id}')
      ..createSync(recursive: true);
  });

  tearDown(() {
    if (support.existsSync()) support.deleteSync(recursive: true);
  });

  void write(String name, int bytes) {
    File('${modelDir.path}/$name')
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(bytes, 0));
  }

  void writeMeta(Map<String, int> sizes) {
    File('${modelDir.path}/$modelMetaFileName').writeAsStringSync(
      jsonEncode({'version': 1, 'model': _model.id, 'files': sizes}),
    );
  }

  ModelManager manager() => ModelManager('stt', supportDirOverride: support.path);

  test('文件齐全且大小对得上 → 已下载', () async {
    write('weights.onnx', 2000000);
    write('tokens.txt', 3000);
    expect(await manager().isDownloaded(_model), isTrue);
  });

  test('缺文件 → 未下载', () async {
    write('weights.onnx', 2000000);
    expect(await manager().isDownloaded(_model), isFalse);
  });

  test('没有清单时：半截文件（-5%）→ 未下载，不再被 ±5% 容差放过', () async {
    write('weights.onnx', 1900000);
    write('tokens.txt', 3000);
    expect(await manager().isDownloaded(_model), isFalse);
  });

  test('有清单时：哪怕只少 1 字节也判损坏（真机上那种截断）', () async {
    write('weights.onnx', 1999999);
    write('tokens.txt', 3000);
    writeMeta({'weights.onnx': 2000000, 'tokens.txt': 3000});
    expect(await manager().isDownloaded(_model), isFalse);
  });

  test('清单记录与磁盘一致 → 已下载（即使清单大小本身不准）', () async {
    write('weights.onnx', 1998000); // 清单写 2000000，但下载记录是 1998000
    write('tokens.txt', 3000);
    writeMeta({'weights.onnx': 1998000, 'tokens.txt': 3000});
    expect(await manager().isDownloaded(_model), isTrue);
  });

  test('清单损坏 → 回落到清单大小比对', () async {
    write('weights.onnx', 2000000);
    write('tokens.txt', 3000);
    File('${modelDir.path}/$modelMetaFileName').writeAsStringSync('{not json');
    expect(await manager().isDownloaded(_model), isTrue);
  });

  test('空文件一律算损坏', () async {
    write('weights.onnx', 2000000);
    write('tokens.txt', 0);
    writeMeta({'weights.onnx': 2000000, 'tokens.txt': 0});
    expect(await manager().isDownloaded(_model), isFalse);
  });

  test('真实清单：sense_voice 模型大小校验拦得住 -4.83% 的截断', () {
    // 复现设备上的情况：225,665,753 / 237,115,547
    const expected = 237115547;
    const truncated = 225665753;
    expect(isModelFileSizeAcceptable(truncated, expected), isFalse);
    expect(
      isModelFileIntact(actual: expected, recorded: null, expected: expected),
      isTrue,
    );
  });
}
