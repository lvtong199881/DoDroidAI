import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_config.dart';
import '../../ai/chat_api.dart';
import '../../ai/tools.dart';
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
  Completer<bool>? _confirmationCompleter;

  Future<void> ensureReady() async {
    if (_ready) return;
    _ready = true;
    _config = await _configStore.load();
    _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    await _database.ensureSession(_sessionId!, 'hello');
    final sessions = await _database.sessions();
    final history = await _database.messagesOf(_sessionId!);
    state = state.copyWith(
      messages: history,
      sessions: sessions,
      currentSessionId: _sessionId,
    );
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
      _sessionId = sessions.isNotEmpty ? sessions.first.id : 'session_${DateTime.now().millisecondsSinceEpoch}';
      if (sessions.isEmpty) {
        await _database.ensureSession(_sessionId!, 'hello');
      }
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
    _config = await _configStore.load();
  }

  Future<void> send(String text, {List<String> images = const []}) async {
    if (text.trim().isEmpty || state.isLoading) return;

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
    await _database.insertMessage(_sessionId!, user);

    // 首条消息作为会话标题
    final current = state.currentSession;
    if (current == null || current.name == 'hello' || current.name == '新对话') {
      final raw = text.trim().replaceAll('\n', ' ');
      final title = raw.length > 20 ? raw.substring(0, 20) : raw;
      await _database.renameSession(_sessionId!, title);
      state = state.copyWith(sessions: await _database.sessions());
    }

    final history = <ChatMessage>[
      ...state.messages.where((m) => !m.isLoading),
    ];

    var iteration = 0;
    try {
      while (iteration < 5) {
        iteration++;
        final builders = <int, _ToolCallBuilder>{};
        await for (final event in _api.stream(
          config,
          history,
          tools: ToolRegistry.definitions,
        )) {
          final tc = event.toolCall;
          if (tc != null) {
            final builder = builders.putIfAbsent(tc.index, () => _ToolCallBuilder());
            if (tc.id != null) builder.id = tc.id!;
            if (tc.name != null) builder.name = tc.name!;
            if (tc.arguments != null) builder.arguments += tc.arguments!;
            continue;
          }
          final content = event.content;
          if (content != null) {
            assistant.content += content;
            state = state.copyWith();
          }
          final reasoning = event.reasoning;
          if (reasoning != null) {
            assistant.reasoning = (assistant.reasoning ?? '') + reasoning;
            state = state.copyWith();
          }
        }

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
        assistant.toolCalls = [...assistant.toolCalls, ...calls];
        state = state.copyWith();

        history.add(ChatMessage(
          role: ChatRole.assistant,
          content: assistant.content,
          toolCalls: calls,
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
          final output = await ToolRegistry.execute(call.name, call.arguments);
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
      assistant.content = '请求失败：$e';
    } finally {
      assistant.isLoading = false;
      final sessions = await _database.sessions();
      state = state.copyWith(isLoading: false, sessions: sessions);
      await _database.insertMessage(_sessionId!, assistant);
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

  Future<void> startNewChat() async {
    _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    await _database.ensureSession(_sessionId!, 'hello');
    final sessions = await _database.sessions();
    state = ChatState(
      sessions: sessions,
      currentSessionId: _sessionId,
      autoRead: state.autoRead,
    );
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
