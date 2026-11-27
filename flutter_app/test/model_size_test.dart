import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/ai/model_manager.dart';

void main() {
  test('精确大小通过', () {
    expect(isModelFileSizeAcceptable(75717082, 75717082), isTrue);
  });

  test('容差是 0.1%，不再是 ±5%', () {
    const expected = 1000000; // 容差 = max(1000, 4096) = 4096
    expect(isModelFileSizeAcceptable(1000000, expected), isTrue);
    expect(isModelFileSizeAcceptable(996000, expected), isTrue); // -0.4%
    expect(isModelFileSizeAcceptable(1004000, expected), isTrue); // +0.4%
    expect(isModelFileSizeAcceptable(950000, expected), isFalse); // -5%（旧逻辑放过）
    expect(isModelFileSizeAcceptable(1050000, expected), isFalse); // +5%（旧逻辑放过）
    expect(isModelFileSizeAcceptable(995000, expected), isFalse); // -0.5%
    expect(isModelFileSizeAcceptable(1005000, expected), isFalse); // +0.5%
  });

  test('真机上那份被截断的 sense_voice 模型会被判为损坏', () {
    const expected = 237115547;
    const truncated = 225665753; // -4.83%，旧 ±5% 容差放过了它
    expect(isModelFileSizeAcceptable(truncated, expected), isFalse);
    expect(
      isModelFileIntact(actual: truncated, recorded: null, expected: expected),
      isFalse,
    );
  });

  test('有下载记录时要求字节数精确相等', () {
    const size = 237115547;
    expect(
      isModelFileIntact(actual: size, recorded: size, expected: size),
      isTrue,
    );
    // 清单大小对得上，但和下载时记录的字节数不同 → 文件被截断/替换
    expect(
      isModelFileIntact(
        actual: size - 1,
        recorded: size,
        expected: size,
      ),
      isFalse,
    );
    expect(
      isModelFileIntact(
        actual: size + 1,
        recorded: size,
        expected: size,
      ),
      isFalse,
    );
  });

  test('半截文件与空文件被拒绝', () {
    expect(isModelFileSizeAcceptable(0, 100), isFalse);
    expect(isModelFileSizeAcceptable(50000, 1000000), isFalse);
    expect(isModelFileIntact(actual: 0, recorded: 0, expected: 100), isFalse);
  });

  test('expected 未知时只要求非空', () {
    expect(isModelFileSizeAcceptable(1, 0), isTrue);
    expect(isModelFileSizeAcceptable(0, 0), isFalse);
    expect(isModelFileIntact(actual: 1, recorded: null, expected: 0), isTrue);
  });

  test('容差下限 4 KiB：小文件不会因比例太小而被卡死', () {
    expect(modelFileSizeTolerance(315894), 4096); // 0.1% = 315 → 取 4096
    expect(modelFileSizeTolerance(237115547), 237115);
    expect(isModelFileSizeAcceptable(315894 - 4096, 315894), isTrue);
    expect(isModelFileSizeAcceptable(315894 - 4097, 315894), isFalse);
  });
}
