import 'package:flutter/foundation.dart';

import '../data/chat_database.dart';
import '../models/chat_message.dart';

/// 上下文压缩器：把超出窗口的旧对话滚动摘要成一条，并持久化到
/// `session_context` 表，下一轮只摘要「新增的旧消息」，不再全量重摘。
///
/// token 计数与摘要调用均由调用方注入（`tokenOf` / `summarizeFresh` /
/// `summarizeIncremental`），本类不依赖 ChatApi，可直接单测。
class ContextCompressor {
  ContextCompressor({
    required this.tokenOf,
    required this.summarizeFresh,
    required this.summarizeIncremental,
  });

  /// 单条消息的 token 数
  final int Function(ChatMessage) tokenOf;

  /// 首次压缩：输入旧消息转录，输出摘要；失败返回 null
  final Future<String?> Function(String transcript) summarizeFresh;

  /// 增量压缩：输入已有摘要与新增旧消息转录，输出合并后的摘要
  final Future<String?> Function(String previousSummary, String newTranscript)
      summarizeIncremental;

  /// 调试用触发阈值（与旧行为一致）：dart-define CTX_TRIGGER 覆盖默认 80%
  static int _debugTrigger() => int.fromEnvironment('CTX_TRIGGER');

  /// 返回用于本次请求的消息列表；无需压缩时原样返回 `all`
  Future<List<ChatMessage>> fit({
    required List<ChatMessage> all,
    required int contextWindow,
    required String sessionId,
    required Future<SessionContextRecord?> Function(String sessionId)
        loadContext,
    required Future<void> Function(String sessionId, String summary, int count)
        saveContext,
    int? triggerOverride,
    int? keepBudgetOverride,
  }) async {
    if (all.isEmpty) return all;
    final window = contextWindow > 0 ? contextWindow : 200000;
    final debugTrigger = _debugTrigger();
    final trigger = triggerOverride ??
        (debugTrigger > 0 ? debugTrigger : (window * 0.8).round());
    final keepBudget = keepBudgetOverride ??
        (debugTrigger > 0 ? (debugTrigger * 0.5).round() : (window * 0.4).round());

    // 每条消息只估一次 token，配合后缀和做 O(n) 扫描
    final tokenCounts = [for (final m in all) tokenOf(m)];
    final suffix = List<int>.filled(all.length + 1, 0);
    for (var i = all.length - 1; i >= 0; i--) {
      suffix[i] = suffix[i + 1] + tokenCounts[i];
    }
    final total = suffix[0];
    if (total <= trigger) return all;

    // 保留最近一段（目标占用 <= keepBudget），其余交给摘要
    var start = 0;
    while (start < all.length - 2 && suffix[start] > keepBudget) {
      start++;
    }
    if (start == 0) return all;

    final older = all.sublist(0, start);
    final recent = all.sublist(start);
    debugPrint(
      'CONTEXT_COMPRESS summarizing ${older.length} msgs '
      'tokens≈$total window=$window',
    );

    final saved = await loadContext(sessionId);
    String? summary;
    if (saved != null &&
        saved.summarizedCount > 0 &&
        saved.summarizedCount <= older.length) {
      if (saved.summarizedCount == older.length) {
        // 没有新的旧消息，直接复用已持久化的摘要，不发请求
        summary = saved.summary.trim().isEmpty ? null : saved.summary;
      } else {
        final newTranscript =
            buildTranscript(older.sublist(saved.summarizedCount));
        summary = await summarizeIncremental(saved.summary, newTranscript);
      }
    }
    summary ??= await summarizeFresh(buildTranscript(older));

    if (summary == null || summary.trim().isEmpty) {
      // 摘要失败时降级为保留最近对话，避免请求直接超限；不覆盖已存的摘要
      return [
        ChatMessage(
          role: ChatRole.user,
          content: '[更早的 ${older.length} 条对话因超出上下文已省略]',
        ),
        ...recent,
      ];
    }
    await saveContext(sessionId, summary, older.length);
    return [
      ChatMessage(
        role: ChatRole.user,
        content: '[以下是更早对话的摘要，供你保持上下文连续性]\n$summary',
      ),
      ...recent,
    ];
  }

  /// 把消息列表压成「角色：内容」转录，供摘要请求使用
  static String buildTranscript(List<ChatMessage> messages) {
    final buffer = StringBuffer();
    for (final m in messages) {
      final role = switch (m.role) {
        ChatRole.user => '用户',
        ChatRole.assistant => '助手',
        ChatRole.tool => '工具',
      };
      if (m.content.trim().isNotEmpty) {
        buffer.writeln('$role：${m.content.trim()}');
      }
      for (final block in m.blocks) {
        if (block.kind == MessageBlockKind.toolCall && block.tool != null) {
          buffer.writeln(
            '工具 ${block.tool!.name}：${block.tool!.resultSummary ?? ''}',
          );
        }
      }
    }
    return buffer.toString();
  }
}
