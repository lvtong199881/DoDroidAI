import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/models/chat_message.dart';

/// 与 ChatController 内部一致的分词估算和压缩策略（对外行为验证）
int estimate(List<ChatMessage> messages) {
  var chars = 0;
  for (final m in messages) {
    chars += m.content.length;
  }
  return chars ~/ 2;
}

List<ChatMessage> fit(List<ChatMessage> all, int window) {
  if (all.isEmpty) return all;
  final trigger = (window * 0.8).round();
  if (estimate(all) <= trigger) return all;
  final target = (window * 0.6).round();
  var start = 0;
  while (start < all.length - 2 && estimate(all.sublist(start)) > target) {
    start++;
  }
  if (start == 0) return all;
  return [
    ChatMessage(role: ChatRole.user, content: '[省略 $start 条]'),
    ...all.sublist(start),
  ];
}

ChatMessage _msg(String text) =>
    ChatMessage(role: ChatRole.user, content: text);

void main() {
  test('低于 80% 窗口时不压缩', () {
    final messages = List.generate(10, (_) => _msg('a' * 100));
    // 1000 字符 ≈ 500 token，窗口 10000 → 未到 80%
    expect(fit(messages, 10000).length, 10);
  });

  test('超过 80% 时丢弃最旧消息', () {
    final messages = List.generate(100, (_) => _msg('a' * 200));
    // 20000 字符 ≈ 10000 token，窗口 10000 → 触发压缩
    final result = fit(messages, 10000);
    expect(result.length, lessThan(messages.length));
    expect(result.first.content, contains('省略'));
  });

  test('至少保留最近两条', () {
    final messages = List.generate(5, (_) => _msg('a' * 5000));
    final result = fit(messages, 1000);
    // 最后两条必须保留
    expect(result.length, greaterThanOrEqualTo(3));
    expect(result.last.content, messages.last.content);
  });

  test('空列表安全', () {
    expect(fit(const [], 1000), isEmpty);
  });
}
