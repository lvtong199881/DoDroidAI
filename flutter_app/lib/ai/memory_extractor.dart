import 'dart:convert';

import '../models/chat_message.dart';
import 'ai_config.dart';
import 'chat_api.dart';

/// 一轮对话里提炼出的候选记忆
class ExtractedMemory {
  const ExtractedMemory({required this.key, required this.value});

  final String key;
  final String value;
}

/// 每轮对话结束后自动提炼长期记忆。
///
/// 只负责「提炼 + 解析」，落库与去重由调用方走 MemoryRepository
/// （其 insert 自带语义去重），保持本类无状态、可单测。
class MemoryExtractor {
  MemoryExtractor({required ChatApi api}) : _api = api;

  final ChatApi _api;

  static const systemPrompt = '你是记忆提炼器，只输出 JSON，不输出其他内容。';

  /// 从一轮「用户-助手」对话里提炼值得长期记住的稳定信息（最多 3 条）。
  /// 模型没有输出合法 JSON 或无新信息时返回空列表，任何异常都吞掉。
  Future<List<ExtractedMemory>> extract(
    AiConfig config,
    String userText,
    String assistantText, {
    List<String> knownFacts = const [],
  }) async {
    try {
      final user = userText.trim();
      if (user.length < 6) return const [];
      final assistant = assistantText.trim();
      final known = knownFacts.isEmpty
          ? '（暂无）'
          : knownFacts.take(30).map((f) => '- $f').join('\n');
      final prompt = ChatMessage(
        role: ChatRole.user,
        content: '从下面这轮对话里，提炼值得长期记住的关于用户的信息'
            '（称呼、城市、职业、偏好、习惯、正在进行的项目、重要事实）。\n'
            '规则：\n'
            '1. 只提炼稳定信息，不记一次性问答或临时上下文；\n'
            '2. 不要与「已有记忆」重复或只是换种说法；\n'
            '3. 最多 3 条；没有就输出 []；\n'
            '4. 只输出 JSON 数组，格式：'
            '[{"key":"简短键名","value":"一句话事实"}]。\n\n'
            '已有记忆：\n$known\n\n'
            '对话：\n用户：$user\n助手：$assistant',
      );
      final collected = StringBuffer();
      await for (final event in _api.stream(
        config,
        [prompt],
        systemPrompt: systemPrompt,
      )) {
        final content = event.content;
        if (content != null) collected.write(content);
      }
      return parse(collected.toString());
    } catch (_) {
      return const [];
    }
  }

  /// 解析模型输出：容忍 ```json 代码块包裹与前后杂质
  static List<ExtractedMemory> parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return const [];
    var payload = text;
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final fenceMatch = fence.firstMatch(text);
    if (fenceMatch != null) {
      payload = fenceMatch.group(1)!.trim();
    }
    final start = payload.indexOf('[');
    final end = payload.lastIndexOf(']');
    if (start < 0 || end <= start) return const [];
    try {
      final decoded = jsonDecode(payload.substring(start, end + 1));
      if (decoded is! List) return const [];
      final result = <ExtractedMemory>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final key = item['key']?.toString().trim() ?? '';
        final value = item['value']?.toString().trim() ?? '';
        if (key.isEmpty || value.isEmpty) continue;
        result.add(ExtractedMemory(key: key, value: value));
        if (result.length >= 3) break;
      }
      return result;
    } catch (_) {
      return const [];
    }
  }
}
