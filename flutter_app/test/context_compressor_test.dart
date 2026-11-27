import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/ai/context_compressor.dart';
import 'package:dodroidai/data/chat_database.dart';
import 'package:dodroidai/models/chat_message.dart';

class _Recorder {
  final freshCalls = <String>[];
  final incrementalCalls = <List<String>>[];
  final saved = <String, SessionContextRecord>{};

  Future<SessionContextRecord?> load(String sessionId) async =>
      saved[sessionId];

  Future<void> save(String sessionId, String summary, int count) async {
    saved[sessionId] = SessionContextRecord(
      sessionId: sessionId,
      summary: summary,
      summarizedCount: count,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// 每条消息固定 10 token，便于精确控制触发阈值
ChatMessage _msg(String content, [ChatRole role = ChatRole.user]) =>
    ChatMessage(role: role, content: content);

ContextCompressor _compressor(
  _Recorder r, {
  String? freshReply,
  bool freshFails = false,
}) =>
    ContextCompressor(
      tokenOf: (_) => 10,
      summarizeFresh: (transcript) async {
        r.freshCalls.add(transcript);
        if (freshFails) return null;
        return freshReply ?? '摘要内容';
      },
      summarizeIncremental: (previous, transcript) async {
        r.incrementalCalls.add([previous, transcript]);
        return '$previous（含新增）';
      },
    );

void main() {
  test('总量低于触发阈值时不压缩、不请求摘要', () async {
    final r = _Recorder();
    final c = _compressor(r);
    final all = [_msg('1'), _msg('2'), _msg('3'), _msg('4')];
    final out = await c.fit(
      all: all,
      contextWindow: 200000,
      sessionId: 's1',
      loadContext: r.load,
      saveContext: r.save,
      // 40 条消息量级才触发；这里只有 4 条
      triggerOverride: 100,
      keepBudgetOverride: 40,
    );
    expect(out, same(all));
    expect(r.freshCalls, isEmpty);
    expect(r.saved, isEmpty);
  });

  test('超过阈值：旧消息摘要替换，摘要持久化', () async {
    final r = _Recorder();
    final c = _compressor(r);
    // 10 条 × 10 token = 100；trigger 80，keepBudget 40
    final all = [for (var i = 1; i <= 10; i++) _msg('m$i')];
    final out = await c.fit(
      all: all,
      contextWindow: 100,
      sessionId: 's1',
      loadContext: r.load,
      saveContext: r.save,
      triggerOverride: 80,
      keepBudgetOverride: 40,
    );
    // 保留最近的 4 条（40 token），前 6 条被摘要
    expect(out.length, 5);
    expect(out.first.content, contains('摘要内容'));
    expect(out.first.content, contains('更早对话的摘要'));
    expect(out.sublist(1), everyElement(isA<ChatMessage>()));
    expect(out.last.content, 'm10');
    expect(r.freshCalls.length, 1);
    expect(r.freshCalls.first, contains('m1'));
    expect(r.freshCalls.first, isNot(contains('m10')));
    // 持久化：摘要覆盖 6 条
    expect(r.saved['s1']!.summarizedCount, 6);
    expect(r.saved['s1']!.summary, '摘要内容');
  });

  test('同一批旧消息再次触发：直接复用持久化摘要，不再请求模型', () async {
    final r = _Recorder();
    final c = _compressor(r);
    final all = [for (var i = 1; i <= 10; i++) _msg('m$i')];
    await c.fit(
      all: all,
      contextWindow: 100,
      sessionId: 's2',
      loadContext: r.load,
      saveContext: r.save,
      triggerOverride: 80,
      keepBudgetOverride: 40,
    );
    final freshBefore = r.freshCalls.length;
    // 同一批消息再次超限：旧段 6 条与已摘计数一致，应复用摘要
    await c.fit(
      all: all,
      contextWindow: 100,
      sessionId: 's2',
      loadContext: r.load,
      saveContext: r.save,
      triggerOverride: 80,
      keepBudgetOverride: 40,
    );
    expect(r.freshCalls.length, freshBefore,
        reason: '旧消息没有新增时应复用已持久化的摘要');
    expect(r.incrementalCalls, isEmpty);
  });

  test('旧消息有新增时走增量摘要', () async {
    final r = _Recorder();
    final c = _compressor(r);
    final all = [for (var i = 1; i <= 10; i++) _msg('m$i')];
    await c.fit(
      all: all,
      contextWindow: 100,
      sessionId: 's3',
      loadContext: r.load,
      saveContext: r.save,
      triggerOverride: 80,
      keepBudgetOverride: 40,
    );
    // 再追加两条：旧段变为 8 条（已摘 6 条 + 新增 m7 m8 落入旧段）
    final all2 = [...all, _msg('m11'), _msg('m12')];
    final out = await c.fit(
      all: all2,
      contextWindow: 100,
      sessionId: 's3',
      loadContext: r.load,
      saveContext: r.save,
      triggerOverride: 80,
      keepBudgetOverride: 40,
    );
    expect(r.incrementalCalls.length, 1);
    expect(r.incrementalCalls.first[0], '摘要内容');
    expect(r.incrementalCalls.first[1], contains('m7'));
    expect(r.incrementalCalls.first[1], isNot(contains('m11')));
    // 增量摘要后更新持久化计数
    expect(r.saved['s3']!.summarizedCount, 8);
    expect(r.saved['s3']!.summary, '摘要内容（含新增）');
    expect(out.first.content, contains('摘要内容（含新增）'));
  });

  test('摘要失败：降级占位且不覆盖已存摘要', () async {
    final r = _Recorder();
    final c = _compressor(r, freshFails: true);
    final all = [for (var i = 1; i <= 10; i++) _msg('m$i')];
    final out = await c.fit(
      all: all,
      contextWindow: 100,
      sessionId: 's4',
      loadContext: r.load,
      saveContext: r.save,
      triggerOverride: 80,
      keepBudgetOverride: 40,
    );
    expect(out.first.content, contains('已省略'));
    expect(r.saved, isEmpty, reason: '摘要失败不应写入存储');
  });

  test('buildTranscript：角色与工具行', () {
    final toolMsg = ChatMessage(
      role: ChatRole.assistant,
      content: '',
      blocks: [
        MessageBlock.tool(
          ToolCallInfo(
            id: 'call_1',
            name: 'set_alarm',
            arguments: '{"time":"07:30"}',
            argsSummary: '{"time":"07:30"}',
          )..resultSummary = '闹钟已设置',
        ),
      ],
    );
    final transcript = ContextCompressor.buildTranscript([
      _msg('帮我设个闹钟'),
      toolMsg,
      _msg('好的，已设置', ChatRole.assistant),
    ]);
    expect(transcript, contains('用户：帮我设个闹钟'));
    expect(transcript, contains('工具 set_alarm：闹钟已设置'));
    expect(transcript, contains('助手：好的，已设置'));
  });
}
