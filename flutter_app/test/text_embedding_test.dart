import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/ai/text_embedding.dart';

void main() {
  group('encode', () {
    test('向量维度与 L2 归一化', () {
      final v = TextEmbedder.instance.encode('用户喜欢喝美式咖啡');
      expect(v.length, TextEmbedder.dimensions);
      final norm = v.fold<double>(0, (s, x) => s + x * x);
      expect(norm, closeTo(1, 1e-6));
    });

    test('确定性：同一文本两次编码结果一致', () {
      final a = TextEmbedder.instance.encode('每周三下午开产品评审会');
      final b = TextEmbedder.instance.encode('每周三下午开产品评审会');
      expect(a, orderedEquals(b));
    });

    test('空文本得到零向量', () {
      final v = TextEmbedder.instance.encode('   ');
      expect(v.every((x) => x == 0), isTrue);
    });
  });

  group('cosine', () {
    test('相近文本相似度高于无关文本', () {
      final target = TextEmbedder.instance.encode('用户住在上海，是一名后端工程师');
      final related = TextEmbedder.instance.encode('用户在上海做后端开发');
      final unrelated = TextEmbedder.instance.encode('明天记得提醒我买猫粮');
      final relatedScore = TextEmbedder.cosine(target, related);
      final unrelatedScore = TextEmbedder.cosine(target, unrelated);
      expect(relatedScore, greaterThan(unrelatedScore));
      expect(relatedScore, greaterThan(0.2));
    });

    test('相同文本相似度为 1', () {
      final v = TextEmbedder.instance.encode('记住这件事');
      expect(TextEmbedder.cosine(v, v), closeTo(1, 1e-6));
    });

    test('长度不一致或零向量返回 0', () {
      final v = TextEmbedder.instance.encode('文本');
      expect(TextEmbedder.cosine(v, <double>[]), 0);
      expect(TextEmbedder.cosine(v, List.filled(TextEmbedder.dimensions, 0)), 0);
    });
  });

  group('featureCounts', () {
    test('中文字符与二字组', () {
      final counts = TextEmbedder.featureCounts('你好');
      expect(counts['c:你'], 1);
      expect(counts['c:好'], 1);
      expect(counts['b:你好'], 1);
    });

    test('ASCII 词小写归一', () {
      final counts = TextEmbedder.featureCounts('Hello World hello');
      expect(counts['w:hello'], 2);
      expect(counts['w:world'], 1);
    });

    test('空文本返回空表', () {
      expect(TextEmbedder.featureCounts('').isEmpty, isTrue);
    });
  });
}
