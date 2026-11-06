import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/models/chat_message.dart';

void main() {
  group('MessageBlock', () {
    test('序列化与反序列化往返一致', () {
      final block = MessageBlock.reasoning(seconds: 3)
        ..text = '先思考一下';
      final restored = MessageBlock.fromJson(block.toJson());
      expect(restored.kind, MessageBlockKind.reasoning);
      expect(restored.text, '先思考一下');
      expect(restored.seconds, 3);
    });

    test('工具块保留参数与结果', () {
      final tool = ToolCallInfo(
        id: 't1',
        name: 'add_note',
        arguments: '{"title":"a"}',
        argsSummary: 'a',
        isRunning: false,
        isSuccess: true,
        resultSummary: '已保存',
      );
      final restored =
          MessageBlock.fromJson(MessageBlock.tool(tool).toJson());
      expect(restored.kind, MessageBlockKind.toolCall);
      expect(restored.tool!.name, 'add_note');
      expect(restored.tool!.isSuccess, isTrue);
      expect(restored.tool!.resultSummary, '已保存');
    });
  });

  group('ChatMessage', () {
    test('toolCalls 从 blocks 派生', () {
      final message = ChatMessage(
        role: ChatRole.assistant,
        blocks: [
          MessageBlock.reasoning()..text = 'r1',
          MessageBlock.tool(ToolCallInfo(
            id: 't1',
            name: 'add_note',
            arguments: '{}',
            argsSummary: '',
          )),
          MessageBlock.text()..text = '回答',
        ],
      );
      expect(message.toolCalls.length, 1);
      expect(message.toolCalls.first.name, 'add_note');
      expect(message.reasoningText, 'r1');
    });

    test('blocks JSON 往返保留顺序', () {
      final message = ChatMessage(
        role: ChatRole.assistant,
        blocks: [
          MessageBlock.reasoning()..text = 'r1',
          MessageBlock.tool(ToolCallInfo(
            id: 't1',
            name: 'web_search',
            arguments: '{}',
            argsSummary: '',
          )),
          MessageBlock.reasoning()..text = 'r2',
          MessageBlock.text()..text = '最终',
        ],
      );
      final restored =
          ChatMessage.blocksFromJson(message.blocksToJson());
      expect(restored.map((b) => b.kind).toList(), [
        MessageBlockKind.reasoning,
        MessageBlockKind.toolCall,
        MessageBlockKind.reasoning,
        MessageBlockKind.text,
      ]);
      expect(restored[2].text, 'r2');
    });

    test('空 JSON 返回空列表', () {
      expect(ChatMessage.blocksFromJson(null), isEmpty);
      expect(ChatMessage.blocksFromJson(''), isEmpty);
      expect(ChatMessage.blocksFromJson('not json'), isEmpty);
    });
  });
}
