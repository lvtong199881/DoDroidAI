import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_config.dart';
import '../../ai/chat_api.dart';
import '../../data/chat_database.dart';
import '../../models/chat_message.dart';

class ChatState {
  ChatState({
    List<ChatMessage>? messages,
    this.isLoading = false,
    this.autoRead = false,
    this.error,
  }) : messages = messages ?? [];

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool autoRead;
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? autoRead,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      autoRead: autoRead ?? this.autoRead,
      error: error,
    );
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

  Future<void> ensureReady() async {
    if (_ready) return;
    _ready = true;
    _config = await _configStore.load();
    _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    await _database.ensureSession(_sessionId!, 'hello');
    final history = await _database.messagesOf(_sessionId!);
    if (history.isNotEmpty) {
      state = state.copyWith(messages: history);
    }
  }

  Future<void> reloadConfig() async {
    _config = await _configStore.load();
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty || state.isLoading) return;

    final config = _config;
    if (config == null || !config.isConfigured) {
      state = state.copyWith(error: '请先在设置中配置 API 地址、Key 和模型');
      return;
    }

    final user = ChatMessage(role: ChatRole.user, content: text.trim());
    final assistant =
        ChatMessage(role: ChatRole.assistant, content: '', isLoading: true);
    state = state.copyWith(
      messages: [...state.messages, user, assistant],
      isLoading: true,
      error: null,
    );
    await _database.insertMessage(_sessionId!, user);

    final history = state.messages.where((m) => m.content.isNotEmpty).toList();
    try {
      await for (final delta in _api.stream(config, history)) {
        assistant.content += delta;
        state = state.copyWith();
      }
      if (assistant.content.isEmpty) {
        assistant.content = '（空回复）';
      }
    } catch (e) {
      assistant.isError = true;
      assistant.content = '请求失败：$e';
    } finally {
      assistant.isLoading = false;
      state = state.copyWith(isLoading: false);
      await _database.insertMessage(_sessionId!, assistant);
    }
  }

  void startNewChat() {
    _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _database.ensureSession(_sessionId!, 'hello');
    state = ChatState(autoRead: state.autoRead);
  }

  void toggleAutoRead() {
    state = state.copyWith(autoRead: !state.autoRead);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final chatProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) => ChatController(),
);
