import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat_message.dart';
import 'chat_provider.dart';
import 'widgets/app_drawer.dart';
import 'widgets/chat_input_box.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(chatProvider.notifier).send(text);
    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider);
    final scheme = Theme.of(context).colorScheme;
    ref.listen<ChatState>(chatProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        onNewChat: () => ref.read(chatProvider.notifier).startNewChat(),
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          state.messages.isEmpty ? '' : 'hello',
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(chatProvider.notifier).toggleAutoRead();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.autoRead ? '已关闭自动朗读' : '已开启自动朗读'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            icon: Icon(
              state.autoRead ? Icons.volume_up : Icons.volume_off,
              color: state.autoRead ? scheme.primary : scheme.onSurface,
            ),
          ),
          IconButton(
            onPressed: () {
              if (state.messages.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已经在新对话中'),
                    duration: Duration(seconds: 1),
                  ),
                );
                return;
              }
              ref.read(chatProvider.notifier).startNewChat();
            },
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? Center(
                    child: Text(
                      '发送消息开始对话',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      final message = state.messages[index];
                      return message.role == ChatRole.user
                          ? UserMessageBubble(message: message)
                          : AssistantMessageView(message: message);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ChatInputBox(
              controller: _controller,
              onSend: _send,
              onNewChat: () => ref.read(chatProvider.notifier).startNewChat(),
            ),
          ),
        ],
      ),
    );
  }
}
