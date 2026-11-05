import 'package:flutter_test/flutter_test.dart';
import 'package:dodroidai/ai/sherpa_tts.dart';

void main() {
  group('splitForSpeech', () {
    test('按中文句读切分', () {
      final parts = SherpaTts.splitForSpeech('你好。今天天气怎么样？我们出去走走吧！');
      expect(parts.length, greaterThanOrEqualTo(2));
      expect(parts.first.contains('你好'), isTrue);
    });

    test('英文句子按标点与空格切分', () {
      final parts = SherpaTts.splitForSpeech(
        'Hello there. This is a longer sentence to test splitting behavior.',
      );
      expect(parts.length, greaterThanOrEqualTo(1));
      expect(parts.join(' ').contains('Hello'), isTrue);
    });

    test('超长无标点文本会被切成多段', () {
      final text = '这是一个没有任何标点的很长文本' * 12;
      final parts = SherpaTts.splitForSpeech(text);
      expect(parts.length, greaterThan(1));
      for (final part in parts) {
        expect(part.length, lessThanOrEqualTo(120));
      }
    });

    test('空白文本返回空列表', () {
      expect(SherpaTts.splitForSpeech('   '), isEmpty);
      expect(SherpaTts.splitForSpeech(''), isEmpty);
    });
  });
}
