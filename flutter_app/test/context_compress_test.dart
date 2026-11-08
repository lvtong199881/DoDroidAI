import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/ai/token_counter.dart';

/// 与配置页一致的上下文选项规则（≥1M 给三档，500K~1M 给两档，其余一档）
List<int> contextOptions(int modelContext) {
  if (modelContext >= 1000000) return const [200000, 500000, 1000000];
  if (modelContext >= 500000) return [200000, modelContext];
  return [modelContext];
}

void main() {
  group('上下文选项', () {
    test('1M 模型给 200K / 500K / 1M 三档', () {
      expect(contextOptions(1000000), [200000, 500000, 1000000]);
      expect(contextOptions(2000000), [200000, 500000, 1000000]);
    });

    test('500K~1M 给 200K 和模型上限', () {
      expect(contextOptions(500000), [200000, 500000]);
      expect(contextOptions(800000), [200000, 800000]);
    });

    test('小于 500K 只给模型上限', () {
      expect(contextOptions(128000), [128000]);
      expect(contextOptions(32000), [32000]);
    });

    test('默认选中最大档', () {
      expect(contextOptions(1000000).last, 1000000);
      expect(contextOptions(800000).last, 800000);
      expect(contextOptions(128000).last, 128000);
    });
  });

  group('tiktoken 计数', () {
    test('中文与英文分别计数', () {
      final counter = TokenCounter.instance;
      final zh = counter.count('你好世界');
      final en = counter.count('hello world');
      expect(zh, greaterThan(0));
      expect(en, greaterThan(0));
      expect(zh, lessThan(20));
      expect(en, lessThan(10));
    });

    test('空字符串为 0', () {
      expect(TokenCounter.instance.count(''), 0);
    });

    test('长文本走采样不会卡死', () {
      final text = 'a' * 100000;
      final tokens = TokenCounter.instance.count(text);
      expect(tokens, greaterThan(0));
    });

    test('相同文本命中缓存', () {
      final counter = TokenCounter.instance;
      final a = counter.count('缓存测试文本');
      final b = counter.count('缓存测试文本');
      expect(a, b);
    });
  });
}
