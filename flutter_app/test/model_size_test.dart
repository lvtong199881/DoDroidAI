import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/ai/model_manager.dart';

void main() {
  test('精确大小通过', () {
    expect(isModelFileSizeAcceptable(75717082, 75717082), isTrue);
  });

  test('容忍 ±5% 波动', () {
    const expected = 1000000;
    expect(isModelFileSizeAcceptable(950000, expected), isTrue); // 95%
    expect(isModelFileSizeAcceptable(1050000, expected), isTrue); // 105% 上界
    expect(isModelFileSizeAcceptable(949999, expected), isFalse); // 94.9999%
    expect(isModelFileSizeAcceptable(1050001, expected), isFalse); // 超上界
  });

  test('半截文件与空文件被拒绝', () {
    expect(isModelFileSizeAcceptable(0, 100), isFalse);
    expect(isModelFileSizeAcceptable(50000, 1000000), isFalse);
  });

  test('expected 未知时只要求非空', () {
    expect(isModelFileSizeAcceptable(1, 0), isTrue);
    expect(isModelFileSizeAcceptable(0, 0), isFalse);
  });
}
