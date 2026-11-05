import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat_message.dart';

class ChatState {
  ChatState({
    List<ChatMessage>? messages,
    this.isLoading = false,
    this.autoRead = false,
  }) : messages = messages ?? [];

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool autoRead;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? autoRead,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      autoRead: autoRead ?? this.autoRead,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController() : super(ChatState());

  Timer? _timer;

  /// 发送消息（当前为本地演示回复，后续接入 SSE）
  void send(String text) {
    if (text.trim().isEmpty || state.isLoading) return;
    final user = ChatMessage(role: ChatRole.user, content: text.trim());
    final assistant = ChatMessage(role: ChatRole.assistant, content: '', isLoading: true);
    state = state.copyWith(
      messages: [...state.messages, user, assistant],
      isLoading: true,
    );
    _generateReply(assistant);
  }

  void _generateReply(ChatMessage assistant) {
    const reply = '你好！我是 DoDroidAI。Flutter 版本正在迁移中，'
        '这条回复由本地演示逻辑生成。\n\n'
        '发送消息后可以看到流式效果：\n\n'
        '- 支持 Markdown\n'
        '- 支持**思考过程**折叠\n'
        '- 支持工具调用卡片';
    var index = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 24), (timer) {
      index += 2;
      if (index >= reply.length) {
        index = reply.length;
        timer.cancel();
        assistant.isLoading = false;
        state = state.copyWith(isLoading: false);
      }
      assistant.content = reply.substring(0, index);
      assistant.reasoning ??= '用户发送了消息，需要给出迁移中的演示回复。';
      assistant.reasoningSeconds = 1;
      state = state.copyWith();
    });
  }

  void startNewChat() {
    _timer?.cancel();
    state = ChatState(autoRead: state.autoRead);
  }

  void toggleAutoRead() {
    state = state.copyWith(autoRead: !state.autoRead);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final chatProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) => ChatController(),
);
