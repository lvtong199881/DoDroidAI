import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_strings.dart';
import '../../ai/sherpa_tts.dart';
import '../../models/chat_message.dart';
import '../../widgets/app_toast.dart';
import '../../quick_actions_handler.dart';
import '../settings/settings_screen.dart';
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
  String? _lastAutoReadKey;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(chatProvider.notifier).ensureReady());
    pendingShortcut.addListener(_handleShortcut);
  }

  @override
  void dispose() {
    pendingShortcut.removeListener(_handleShortcut);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleShortcut() {
    final type = pendingShortcut.value;
    if (type == null) return;
    pendingShortcut.value = null;
    if (type == 'new_chat') {
      ref.read(chatProvider.notifier).startNewChat();
    } else if (type == 'settings') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
    }
  }


  Future<void> _showToolConfirmDialog(ToolCallInfo call) async {
    final strings = AppStrings.of(context);
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.confirmTool),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('工具：${call.name}'),
            const SizedBox(height: 8),
            Text(
              '参数：${call.arguments.isEmpty ? '无' : call.arguments}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.execute),
          ),
        ],
      ),
    );
    ref.read(chatProvider.notifier).resolveConfirmation(approved == true);
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

    // 自动朗读：助手回复完成后朗读一次（对齐原生 maybeAutoRead）
    ref.listen<ChatState>(chatProvider, (previous, next) {
      if (!next.autoRead) return;
      ChatMessage? last;
      for (final message in next.messages.reversed) {
        if (message.role == ChatRole.assistant && !message.isLoading) {
          last = message;
          break;
        }
      }
      if (last == null) return;
      final content = last.content.trim();
      if (content.isEmpty || last.isError) return;
      final key = last.createdAt.microsecondsSinceEpoch.toString();
      if (key == _lastAutoReadKey) return;
      _lastAutoReadKey = key;
      SherpaTts.speak(content);
    });
    final scheme = Theme.of(context).colorScheme;
    ref.listen<ChatState>(chatProvider, (previous, next) {
      _scrollToBottom();
      final error = next.error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), duration: const Duration(seconds: 2)),
        );
        ref.read(chatProvider.notifier).clearError();
      }
      final pending = next.pendingConfirmation;
      if (pending != null && previous?.pendingConfirmation == null) {
        _showToolConfirmDialog(pending);
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        onOpenSettings: () {
          Future.delayed(const Duration(milliseconds: 250), () {
            if (!context.mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) => ref.read(chatProvider.notifier).reloadConfig());
          });
        },
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          state.messages.isEmpty ? '' : (state.currentSession?.name ?? ''),
          style: const TextStyle(fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(chatProvider.notifier).toggleAutoRead();
              showToast(context, state.autoRead ? '已关闭自动朗读' : '已开启自动朗读');
            },
            icon: Icon(
              state.autoRead ? Icons.volume_up : Icons.volume_off,
              color: state.autoRead ? scheme.primary : scheme.onSurface,
            ),
          ),
          IconButton(
            onPressed: () {
              if (state.messages.isEmpty) {
                showToast(context, '已经在新对话中');
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
                      AppStrings.of(context).emptyHint,
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
              onSend: (text, images, deepThink) => ref
                  .read(chatProvider.notifier)
                  .send(text, images: images, deepThink: deepThink),
              onNewChat: () => ref.read(chatProvider.notifier).startNewChat(),
              isLoading: state.isLoading,
              onStop: () => ref.read(chatProvider.notifier).stopGeneration(),
            ),
          ),
        ],
      ),
    );
  }
}
