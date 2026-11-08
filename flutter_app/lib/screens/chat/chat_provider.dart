import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_config.dart';
import '../../ai/chat_api.dart';
import '../../ai/token_counter.dart';
import '../../ai/tools.dart';
import '../../data/memory_database.dart';
import '../../widget/home_widget_sync.dart';
import '../../data/tool_audit_database.dart';
import '../../home_widgets.dart';
import 'dart:async';
import '../../data/chat_database.dart';
import '../../models/chat_message.dart';

class ChatState {
  ChatState({
    List<ChatMessage>? messages,
    List<ChatSession>? sessions,
    this.currentSessionId,
    this.isLoading = false,
    this.autoRead = false,
    this.error,
    this.pendingConfirmation,
  })  : messages = messages ?? [],
        sessions = sessions ?? [];

  final List<ChatMessage> messages;
  final List<ChatSession> sessions;
  final String? currentSessionId;
  final bool isLoading;
  final bool autoRead;
  final String? error;
  final ToolCallInfo? pendingConfirmation;

  ChatState copyWith({
    List<ChatMessage>? messages,
    List<ChatSession>? sessions,
    String? currentSessionId,
    bool? isLoading,
    bool? autoRead,
    String? error,
    ToolCallInfo? pendingConfirmation,
    bool clearPending = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      sessions: sessions ?? this.sessions,
      currentSessionId: currentSessionId ?? this.currentSessionId,
      isLoading: isLoading ?? this.isLoading,
      autoRead: autoRead ?? this.autoRead,
      error: error,
      pendingConfirmation:
          clearPending ? null : (pendingConfirmation ?? this.pendingConfirmation),
    );
  }

  ChatSession? get currentSession {
    for (final session in sessions) {
      if (session.id == currentSessionId) return session;
    }
    return null;
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController({
    ChatApi? api,
    ChatDatabase? database,
    AiConfigStore? configStore,
  })  : _api = api ?? ChatApi(),
        _database = database ?? ChatDatabase.instance,
        _configStore = configStore ?? AiConfigStore(),
        super(ChatState());

  final ChatApi _api;
  final ChatDatabase _database;
  final AiConfigStore _configStore;

  AiConfig? _config;
  String? _sessionId;
  bool _ready = false;
  bool _cancelled = false;
  DateTime? _lastStreamNotify;

  /// 流式增量节流：50ms 内最多刷新一次 UI，减少重建压力
  void _notifyStream() {
    final now = DateTime.now();
    if (_lastStreamNotify == null ||
        now.difference(_lastStreamNotify!) >= const Duration(milliseconds: 50)) {
      _lastStreamNotify = now;
      state = state.copyWith();
    }
  }
  Completer<bool>? _confirmationCompleter;

  Future<void> ensureReady() async {
    if (_ready) return;
    _ready = true;
    _config = await _configStore.loadActive();
    final sessions = await _database.sessions();
    // 与原生一致：新会话在发出第一条消息时才创建，启动时不落库
    state = state.copyWith(
      messages: const [],
      sessions: sessions,
      currentSessionId: null,
    );
  }

  /// 懒创建会话：仅在真正要写入消息时调用
  Future<String> _ensureSessionId() async {
    final existing = _sessionId;
    if (existing != null) return existing;
    final id = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _sessionId = id;
    await _database.ensureSession(id, 'hello');
    return id;
  }

  Future<void> loadSession(String sessionId) async {
    if (state.isLoading) return;
    _sessionId = sessionId;
    final history = await _database.messagesOf(sessionId);
    state = state.copyWith(messages: history, currentSessionId: sessionId);
  }

  Future<void> deleteSession(String sessionId) async {
    await _database.deleteSession(sessionId);
    final sessions = await _database.sessions();
    if (_sessionId == sessionId) {
      if (sessions.isEmpty) {
        _sessionId = null;
        state = state.copyWith(messages: const [], currentSessionId: null);
        return;
      }
      _sessionId = sessions.first.id;
      final history = await _database.messagesOf(_sessionId!);
      state = state.copyWith(
        messages: history,
        sessions: await _database.sessions(),
        currentSessionId: _sessionId,
      );
      return;
    }
    state = state.copyWith(sessions: sessions);
  }

  Future<void> reloadConfig() async {
    _config = await _configStore.loadActive();
  }

  Future<void> send(
    String text, {
    List<String> images = const [],
    bool deepThink = false,
  }) async {
    if (text.trim().isEmpty || state.isLoading) return;

    _cancelled = false;
    final config = _config;
    if (config == null || !config.isConfigured) {
      state = state.copyWith(error: '请先在设置中配置 API 地址、Key 和模型');
      return;
    }

    final user = ChatMessage(
      role: ChatRole.user,
      content: text.trim(),
      images: images,
    );
    final assistant =
        ChatMessage(role: ChatRole.assistant, content: '', isLoading: true);
    state = state.copyWith(
      messages: [...state.messages, user, assistant],
      isLoading: true,
      error: null,
    );
    final sessionId = await _ensureSessionId();
    await _database.insertMessage(sessionId, user);

    // 首条消息作为会话标题
    final current = state.currentSession;
    if (current == null || current.name == 'hello' || current.name == '新对话') {
      final raw = text.trim().replaceAll('\n', ' ');
      final title = raw.length > 20 ? raw.substring(0, 20) : raw;
      await _database.renameSession(sessionId, title);
      state = state.copyWith(sessions: await _database.sessions());
    }

    // 按模型上下文窗口压缩：超过 80% 时从最旧开始丢弃，降到 60% 以下
    final allMessages = state.messages.where((m) => !m.isLoading).toList();
    final history = await _fitContextAsync(allMessages, config);

    // 把长期记忆注入 system prompt，让模型真正"记得"用户信息
    final systemPrompt = await _buildSystemPrompt();

    var iteration = 0;
    try {
      while (iteration < 5) {
        if (_cancelled) break;
        iteration++;
        final builders = <int, _ToolCallBuilder>{};
        // 本轮内的"当前块"：思考或正文增量连续到达时复用同一块
        MessageBlock? currentBlock;
        // 当前思考块的起止时间，用于展示思考耗时
        DateTime? reasoningStartedAt;
        DateTime? reasoningEndedAt;

        /// 结束当前思考块的计时
        void closeReasoningTimer() {
          if (currentBlock?.kind == MessageBlockKind.reasoning &&
              reasoningStartedAt != null) {
            final end = reasoningEndedAt ?? DateTime.now();
            currentBlock!.seconds =
                end.difference(reasoningStartedAt!).inSeconds.clamp(0, 3600);
          }
          reasoningStartedAt = null;
          reasoningEndedAt = null;
        }
        await for (final event in _api.stream(
          config,
          history,
          tools: ToolRegistry.definitions,
          deepThink: deepThink,
          systemPrompt: systemPrompt,
        )) {
          if (_cancelled) break;
          final tc = event.toolCall;
          if (tc != null) {
            final builder = builders.putIfAbsent(tc.index, () => _ToolCallBuilder());
            if (tc.id != null) builder.id = tc.id!;
            if (tc.name != null) builder.name = tc.name!;
            if (tc.arguments != null) builder.arguments += tc.arguments!;
            continue;
          }
          final content = event.content;
          if (content != null && content.isNotEmpty) {
            if (currentBlock?.kind != MessageBlockKind.text) {
              closeReasoningTimer();
              currentBlock = MessageBlock.text();
              assistant.blocks.add(currentBlock);
            }
            currentBlock!.text += content;
            assistant.content += content;
            _notifyStream();
          }
          final reasoning = event.reasoning;
          if (reasoning != null && reasoning.isNotEmpty) {
            if (currentBlock?.kind != MessageBlockKind.reasoning) {
              closeReasoningTimer();
              currentBlock = MessageBlock.reasoning();
              assistant.blocks.add(currentBlock);
              reasoningStartedAt = DateTime.now();
            }
            reasoningEndedAt = DateTime.now();
            currentBlock!.text += reasoning;
            _notifyStream();
          }
        }

        closeReasoningTimer();
        _lastStreamNotify = null;
        state = state.copyWith();
        if (builders.isEmpty) break;

        final calls = builders.values
            .map((b) => ToolCallInfo(
                  id: b.id,
                  name: b.name,
                  arguments: b.arguments,
                  argsSummary: b.arguments,
                  isRunning: true,
                ))
            .toList();
        for (final call in calls) {
          assistant.blocks.add(MessageBlock.tool(call));
        }
        state = state.copyWith();

        history.add(ChatMessage(
          role: ChatRole.assistant,
          content: assistant.content,
          blocks: [for (final call in calls) MessageBlock.tool(call)],
        ));
        for (final call in calls) {
          if (ToolRegistry.isHighRisk(call.name)) {
            final approved = await _confirmTool(call);
            if (!approved) {
              call.isRunning = false;
              call.isSuccess = false;
              call.resultSummary = '用户取消执行';
              history.add(ChatMessage(
                role: ChatRole.tool,
                content: '用户取消执行',
                toolCallId: call.id,
              ));
              continue;
            }
          }
          final permissionError = await ToolRegistry.ensurePermissions(call.name);
          final output = permissionError ??
              await ToolRegistry.execute(call.name, call.arguments);
          call.isRunning = false;
          call.isSuccess = true;
          call.resultSummary = output;
          await ToolAuditRepository.instance.insert(
            toolName: call.name,
            argsSummary: call.arguments,
            resultSummary: output,
            success: true,
          );
          history.add(ChatMessage(
            role: ChatRole.tool,
            content: output,
            toolCallId: call.id,
          ));
        }
        assistant.content = '';
        state = state.copyWith();
      }
      if (assistant.content.isEmpty && assistant.toolCalls.isEmpty) {
        assistant.content = '（空回复）';
      }
    } catch (e) {
      assistant.isError = true;
      assistant.content = _friendlyError(e);
    } finally {
      assistant.isLoading = false;
      final sessions = await _database.sessions();
      state = state.copyWith(isLoading: false, sessions: sessions);
      await _database.insertMessage(sessionId, assistant);
      unawaited(HomeWidgetSync.refresh());
      ChatWidgets.update(
        title: state.currentSession?.name ?? 'DoDroidAI',
        body: assistant.content,
      );
    }
  }

  Future<bool> _confirmTool(ToolCallInfo call) {
    final completer = Completer<bool>();
    _confirmationCompleter = completer;
    state = state.copyWith(pendingConfirmation: call);
    return completer.future;
  }

  void resolveConfirmation(bool approved) {
    _confirmationCompleter?.complete(approved);
    _confirmationCompleter = null;
    state = state.copyWith(clearPending: true);
  }

  Future<void> retryLastMessage() async {
    if (state.isLoading) return;
    final messages = List<ChatMessage>.from(state.messages);
    final lastUserIndex = messages.lastIndexWhere(
      (m) => m.role == ChatRole.user && m.content.trim().isNotEmpty,
    );
    if (lastUserIndex < 0) return;
    final lastUser = messages[lastUserIndex];
    // 移除该 user 之后的所有消息，然后重新发送
    final removed = messages.sublist(lastUserIndex);
    messages.removeRange(lastUserIndex, messages.length);
    state = state.copyWith(messages: messages);
    // 同步删除数据库里对应的消息（简单做法：重新插入会话）
    final sid = _sessionId;
    if (sid != null) {
      await _database.clearMessagesAfter(sid, lastUserIndex);
    }
    await send(lastUser.content, images: lastUser.images);
    if (removed.isEmpty) return;
  }

  Future<void> startNewChat() async {
    _sessionId = null;
    final sessions = await _database.sessions();
    state = ChatState(
      sessions: sessions,
      currentSessionId: _sessionId,
      autoRead: state.autoRead,
    );
  }

  /// 停止生成：保留已生成内容
  void stopGeneration() {
    if (!state.isLoading) return;
    _cancelled = true;
    state = state.copyWith(isLoading: false);
  }

  /// 用 tiktoken 精确统计消息 token（含思考与工具内容）
  int _estimateTokens(List<ChatMessage> messages) {
    final counter = TokenCounter.instance;
    var total = 0;
    for (final m in messages) {
      total += counter.count(m.content);
      for (final block in m.blocks) {
        total += counter.count(block.text);
        final tool = block.tool;
        if (tool != null) {
          total += counter.count(tool.arguments);
          total += counter.count(tool.resultSummary ?? '');
        }
      }
    }
    return total;
  }

  /// 上下文压缩：超过窗口 80% 时把旧消息摘要成一条，保留最近对话
  Future<List<ChatMessage>> _fitContextAsync(
    List<ChatMessage> all,
    AiConfig config,
  ) async {
    if (all.isEmpty) return all;
    final window = config.contextWindow > 0 ? config.contextWindow : 200000;
    // TEMP: 调试用触发阈值，便于在少量对话下验证摘要链路
    const debugTrigger = int.fromEnvironment('CTX_TRIGGER');
    final trigger = debugTrigger > 0 ? debugTrigger : (window * 0.8).round();
    final tokens = _estimateTokens(all);
    if (tokens <= trigger) return all;

    // 保留最近一段（目标占用 <= 40%），其余交给摘要
    // 调试阈值下按同比例缩放，便于小对话验证
    final keepBudget = debugTrigger > 0
        ? (debugTrigger * 0.5).round()
        : (window * 0.4).round();
    var start = 0;
    while (start < all.length - 2 &&
        _estimateTokens(all.sublist(start)) > keepBudget) {
      start++;
    }
    if (start == 0) return all;

    final older = all.sublist(0, start);
    final recent = all.sublist(start);
    debugPrint(
      'CONTEXT_COMPRESS summarizing ${older.length} msgs '
      'tokens≈${_estimateTokens(all)} window=$window',
    );

    final summary = await _summarize(older, config);
    if (summary == null || summary.trim().isEmpty) {
      // 摘要失败时降级为保留最近对话，避免请求直接超限
      return [
        ChatMessage(
          role: ChatRole.user,
          content: '[更早的 ${older.length} 条对话因超出上下文已省略]',
        ),
        ...recent,
      ];
    }
    return [
      ChatMessage(
        role: ChatRole.user,
        content: '[以下是更早对话的摘要，供你保持上下文连续性]\n$summary',
      ),
      ...recent,
    ];
  }

  /// 用当前模型把旧消息压缩成要点摘要
  Future<String?> _summarize(
    List<ChatMessage> messages,
    AiConfig config,
  ) async {
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
    final transcript = buffer.toString();
    if (transcript.trim().isEmpty) return null;

    final prompt = ChatMessage(
      role: ChatRole.user,
      content:
          '请把下面这段历史对话压缩成要点摘要，保留：用户的关键诉求与偏好、'
          '已完成的工具操作及其结果、未完成的事项。用简洁的中文条目输出，不要寒暄。\n\n'
          '$transcript',
    );
    try {
      final collected = StringBuffer();
      await for (final event in _api.stream(
        config,
        [prompt],
        systemPrompt: '你是对话摘要器，只输出精简摘要。',
      )) {
        final content = event.content;
        if (content != null) collected.write(content);
      }
      return collected.toString();
    } catch (e) {
      debugPrint('CONTEXT_COMPRESS summarize failed: $e');
      return null;
    }
  }

  /// 拼装 system prompt：固定角色说明 + 长期记忆
  Future<String?> _buildSystemPrompt() async {
    final base =
        '你是 DoDroidAI，一个运行在 Android 手机上的助手。'
        '你可以调用工具操作手机（闹钟、日历、短信、笔记、通讯录、剪贴板、定时任务、联网搜索）。'
        '需要操作手机时直接调用工具，不要只描述步骤；回答简洁准确。';
    try {
      final facts = await MemoryRepository.instance.list();
      if (facts.isEmpty) return base;
      final lines = facts
          .take(50)
          .map((f) => '- ${f.content}')
          .join('\n');
      return '$base\n\n你记住的关于用户的信息：\n$lines';
    } catch (_) {
      return base;
    }
  }

  /// 把底层异常转成用户能看懂的提示
  String _friendlyError(Object error) {
    final text = error.toString();
    final lower = text.toLowerCase();
    if (lower.contains('failed host lookup') ||
        lower.contains('connection error') ||
        lower.contains('socketexception') ||
        lower.contains('network is unreachable')) {
      return '网络连接失败，请检查网络后重试';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return '请求超时，请稍后重试';
    }
    if (lower.contains('401') || lower.contains('unauthorized')) {
      return 'API Key 无效或已过期，请检查配置';
    }
    if (lower.contains('403')) {
      return '无权限访问该模型，请检查 API Key 权限';
    }
    if (lower.contains('404')) {
      return '接口地址不正确，请检查 Base URL';
    }
    if (lower.contains('429')) {
      return '请求过于频繁或额度不足，请稍后重试';
    }
    if (lower.contains('500') || lower.contains('502') || lower.contains('503')) {
      return '服务端暂时不可用，请稍后重试';
    }
    if (lower.contains('insufficient') || lower.contains('balance')) {
      return '账户余额不足或额度已用完';
    }
    // 其余情况保留简短原文，避免完全无法定位
    final brief = text.length > 200 ? '${text.substring(0, 200)}…' : text;
    return '请求失败：$brief';
  }

  void toggleAutoRead() {
    state = state.copyWith(autoRead: !state.autoRead);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

class _ToolCallBuilder {
  String id = '';
  String name = '';
  String arguments = '';
}

final chatProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) => ChatController(),
);
