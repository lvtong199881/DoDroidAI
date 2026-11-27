import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/ai/ai_config.dart';
import 'package:dodroidai/ai/chat_api.dart';
import 'package:dodroidai/ai/memory_extractor.dart';
import 'package:dodroidai/models/chat_message.dart';

/// 只回一段固定文本的 fake
class _FakeApi extends ChatApi {
  _FakeApi(this.reply);
  final String reply;

  @override
  Stream<ChatEvent> stream(
    AiConfig config,
    List<ChatMessage> messages, {
    List<Map<String, dynamic>>? tools,
    bool deepThink = false,
    String? systemPrompt,
  }) async* {
    yield ChatEvent(content: reply);
  }
}

AiConfig get _config => AiConfig(
      id: 'test',
      provider: AiProvider.custom,
      providerName: 'Test',
      apiFormat: ApiFormat.openAiChatCompletions,
      baseUrl: 'https://example.com',
      apiKey: 'sk-test',
      mainModel: 'test-model',
    );

void main() {
  group('parse', () {
    test('普通 JSON 数组', () {
      final r = MemoryExtractor.parse(
        '[{"key":"城市","value":"用户住在杭州"},{"key":"职业","value":"后端工程师"}]',
      );
      expect(r.length, 2);
      expect(r[0].key, '城市');
      expect(r[1].value, '后端工程师');
    });

    test('容忍 ```json 围栏与前后杂质', () {
      final r = MemoryExtractor.parse(
        '好的：\n```json\n[{"key":"宠物","value":"养了一只橘猫"}]\n```\n以上',
      );
      expect(r.length, 1);
      expect(r[0].key, '宠物');
    });

    test('非法条目被过滤、最多 3 条', () {
      final r = MemoryExtractor.parse(
        '[{"key":"","value":"空键"},{"key":"有值","value":""},'
        '{"key":"a","value":"1"},{"key":"b","value":"2"},'
        '{"key":"c","value":"3"},{"key":"d","value":"4"}]',
      );
      expect(r.length, 3);
      expect(r.map((e) => e.key).toList(), ['a', 'b', 'c']);
    });

    test('空文本、无数组、坏 JSON 都返回空', () {
      expect(MemoryExtractor.parse(''), isEmpty);
      expect(MemoryExtractor.parse('没有数组'), isEmpty);
      expect(MemoryExtractor.parse('[{broken'), isEmpty);
    });
  });

  group('extract', () {
    test('调用模型并解析返回', () async {
      final api = _FakeApi('[{"key":"城市","value":"用户在北京工作"}]');
      final extractor = MemoryExtractor(api: api);
      final r = await extractor.extract(
        _config,
        '我最近搬到北京了，在那边的公司上班',
        '恭喜乔迁！',
      );
      expect(r.length, 1);
      expect(r[0].key, '城市');
    });

    test('用户输入过短直接跳过，不发请求', () async {
      final api = _FakeApi('[{"key":"x","value":"y"}]');
      final extractor = MemoryExtractor(api: api);
      final r = await extractor.extract(_config, '好的', '嗯');
      expect(r, isEmpty);
    });

    test('模型输出非法 JSON 时返回空列表', () async {
      final api = _FakeApi('我觉得没什么值得记的。');
      final extractor = MemoryExtractor(api: api);
      final r = await extractor.extract(
        _config,
        '我平时喜欢在周末爬山',
        '好的，了解了。',
      );
      expect(r, isEmpty);
    });
  });
}
