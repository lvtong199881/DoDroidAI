import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_strings.dart';
import '../../ai/sherpa_tts.dart';
import '../../models/chat_message.dart';
import '../../settings/welcome_contract.dart';
import '../../settings/welcome_providers.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/welcome_dialog.dart';
import '../../quick_actions_handler.dart';
import '../settings/settings_screen.dart';
import 'chat_provider.dart';
import 'widgets/app_drawer.dart';
import 'widgets/chat_input_box.dart';
import '../../models/ask_question.dart';
import 'widgets/ask_question_sheet.dart';
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
  bool _askSheetOpen = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(chatProvider.notifier).ensureReady());
    pendingShortcut.addListener(_handleShortcut);
    // 首页首帧渲染完成后再检查欢迎弹窗，不阻塞首帧与后台初始化。
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkWelcome());
  }

  /// 进程内只会有一次实际检查（由 [WelcomeController.runOnce] 单飞保证）。
  Future<void> _checkWelcome() async {
    if (!mounted) return;
    final locale =
        Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'zh';
    await ref.read(welcomeControllerProvider).runOnce(
          locale: locale,
          presenter: _presentWelcome,
        );
  }

  /// 展示欢迎弹窗并返回关闭方式与可见时长；render 异常由控制器记录。
  Future<WelcomeDismissResult> _presentWelcome(void Function() onShown) async {
    if (!mounted) {
      throw StateError('首页已销毁，跳过欢迎弹窗');
    }
    final startedAt = DateTime.now();
    final closing = showDialog<WelcomeDismissMethod>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const WelcomeDialog(),
    );
    // showDialog 已 push 路由，此时记录 welcome_shown。
    onShown();
    final method = await closing;
    return WelcomeDismissResult(
      method: method ?? WelcomeDismissMethod.back,
      visibleMs: DateTime.now().difference(startedAt).inMilliseconds,
    );
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

  Future<void> _showAskQuestionSheet(List<AskQuestion> questions) async {
    _askSheetOpen = true;
    final answers = await showAskQuestionSheet(
      context,
      questions: questions,
      timeoutSeconds: 120,
    );
    _askSheetOpen = false;
    if (!mounted) return;
    ref.read(chatProvider.notifier).resolveQuestions(answers);
  }

  Future<void> _openPendingAnswer(PendingQuestion pending) async {
    final answers = await showAskQuestionSheet(
      context,
      questions: pending.questions,
      timeoutSeconds: 0,
    );
    if (!mounted || answers == null) return;
    await ref
        .read(chatProvider.notifier)
        .answerPendingQuestion(pending.callId, answers);
    if (!mounted) return;
    showToast(context, AppStrings.of(context).t('askAnswered'));
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
      final questions = next.pendingQuestions;
      if (questions != null && previous?.pendingQuestions == null) {
        _showAskQuestionSheet(questions);
      } else if (questions == null &&
          previous?.pendingQuestions != null &&
          _askSheetOpen) {
        // 超时：provider 清空挂起状态，主动关闭面板
        Navigator.of(context, rootNavigator: true).maybePop();
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
          ValueListenableBuilder<bool>(
            valueListenable: SherpaTts.speaking,
            builder: (context, speaking, _) {
              if (speaking) {
                return IconButton(
                  tooltip: '停止朗读',
                  onPressed: () => SherpaTts.stop(),
                  icon: Icon(
                    Icons.stop_circle_outlined,
                    color: scheme.primary,
                  ),
                );
              }
              return IconButton(
                tooltip: state.autoRead ? '关闭自动朗读' : '开启自动朗读',
                onPressed: () {
                  ref.read(chatProvider.notifier).toggleAutoRead();
                  showToast(context, state.autoRead ? '已关闭自动朗读' : '已开启自动朗读');
                },
                icon: Icon(
                  state.autoRead ? Icons.volume_up : Icons.volume_off,
                  color: state.autoRead ? scheme.primary : scheme.onSurface,
                ),
              );
            },
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
          if (state.awaitingAnswers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openPendingAnswer(state.awaitingAnswers.first),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        size: 18,
                        color: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${state.awaitingAnswers.length} '
                          '${AppStrings.of(context).t('askPendingBanner')}',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: scheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            // 底部额外让出系统手势条高度，使输入框下方留白与左右一致
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              12 + MediaQuery.viewPaddingOf(context).bottom,
            ),
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
