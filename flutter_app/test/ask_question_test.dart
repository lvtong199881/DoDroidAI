import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/models/ask_question.dart';

void main() {
  group('问题解析', () {
    test('正常批量', () {
      final questions = AskQuestion.parseList([
        {
          'id': 'q1',
          'question': '上午还是下午？',
          'header': '确认',
          'options': [
            {'label': '上午', 'description': '9-12 点'},
            {'label': '下午'},
          ],
          'multi_select': false,
        },
        {'id': 'q2', 'question': '还有其他要求吗', 'multi_select': true},
      ])!;
      expect(questions, hasLength(2));
      expect(questions.first.header, '确认');
      expect(questions.first.options, hasLength(2));
      expect(questions.first.options.first.description, '9-12 点');
      expect(questions.first.multiSelect, isFalse);
      expect(questions[1].hasOptions, isFalse);
      expect(questions[1].multiSelect, isTrue);
    });

    test('缺 id 用序号兜底', () {
      final questions = AskQuestion.parseList([
        {'question': '第一个问题'},
        {'question': '第二个问题'},
      ])!;
      expect(questions[0].id, 'q0');
      expect(questions[1].id, 'q1');
    });

    test('options 非数组按空处理', () {
      final questions = AskQuestion.parseList([
        {'id': 'q1', 'question': '测试', 'options': 'not-a-list'},
      ])!;
      expect(questions.first.options, isEmpty);
    });

    test('multi_select 缺省为 false', () {
      final questions = AskQuestion.parseList([
        {'id': 'q1', 'question': '测试'},
      ])!;
      expect(questions.first.multiSelect, isFalse);
    });

    test('空数组与非法结构返回 null', () {
      expect(AskQuestion.parseList(const []), isNull);
      expect(AskQuestion.parseList('nope'), isNull);
      expect(AskQuestion.parseList([1, 2]), isNull);
      expect(AskQuestion.parseList([{'id': 'q1'}]), isNull); // 缺 question
    });

    test('重复 id 能检出', () {
      final questions = AskQuestion.parseList([
        {'id': 'dup', 'question': 'A'},
        {'id': 'dup', 'question': 'B'},
      ])!;
      expect(AskQuestion.duplicateId(questions), 'dup');
    });
  });

  group('答案编码', () {
    test('仅选中', () {
      const answer = AskAnswer(id: 'q1', selected: ['上午']);
      expect(jsonEncode(answer.toJson()), '{"id":"q1","selected":["上午"]}');
    });

    test('选中 + 自定义', () {
      const answer = AskAnswer(id: 'q1', selected: ['上午'], custom: '尽量早点');
      expect(
        jsonEncode(answer.toJson()),
        '{"id":"q1","selected":["上午"],"custom":"尽量早点"}',
      );
    });

    test('跳过：空 selected 且无 custom', () {
      const answer = AskAnswer(id: 'q1', selected: []);
      expect(answer.isSkipped, isTrue);
      expect(jsonEncode(answer.toJson()), '{"id":"q1","selected":[]}');
    });

    test('空白 custom 视为跳过且不输出字段', () {
      const answer = AskAnswer(id: 'q1', custom: '   ');
      expect(answer.isSkipped, isTrue);
      expect(answer.toJson().containsKey('custom'), isFalse);
    });
  });

  group('结果形状', () {
    test('answers 批次', () {
      final payload = jsonEncode({
        'answers': [
          const AskAnswer(id: 'q1', selected: ['A']).toJson(),
          const AskAnswer(id: 'q2', selected: [], custom: '补充说明').toJson(),
        ],
      });
      expect(
        payload,
        '{"answers":[{"id":"q1","selected":["A"]},'
        '{"id":"q2","selected":[],"custom":"补充说明"}]}',
      );
    });

    test('pending 结果带 callId 与提示', () {
      final payload = jsonEncode({
        'pending': true,
        'callId': 'call_1',
        'message': kAskPendingNotice,
      });
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      expect(decoded['pending'], isTrue);
      expect(decoded['callId'], 'call_1');
      expect((decoded['message'] as String).contains('pending'), isTrue);
    });
  });

  group('PendingQuestion 持久化', () {
    test('questions JSON 可往返', () {
      final pending = PendingQuestion(
        callId: 'call_1',
        sessionId: 's1',
        questions: [
          const AskQuestion(
            id: 'q1',
            question: '选哪个方案？',
            header: '确认',
            options: [AskQuestionOption(label: 'A', description: '快')],
            multiSelect: false,
          ),
        ],
        createdAt: DateTime.fromMillisecondsSinceEpoch(1793000000000),
      );
      final decoded = PendingQuestion.decodeQuestions(pending.questionsJson);
      expect(decoded, hasLength(1));
      expect(decoded.first.id, 'q1');
      expect(decoded.first.options.first.label, 'A');
      expect(decoded.first.options.first.description, '快');
    });

    test('补答消息格式', () {
      final message = pendingAnswerMessage('call_1', [
        const AskAnswer(id: 'q1', selected: ['A']),
      ]);
      expect(message.startsWith('[answer_to_pending_question callId=call_1]'),
          isTrue);
      expect(message.contains('"answers"'), isTrue);
    });
  });
}
