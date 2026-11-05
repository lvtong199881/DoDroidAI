import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/sherpa_tts.dart';
import '../../../widgets/app_toast.dart';
import '../chat_provider.dart';
import '../../../models/chat_message.dart';

class UserMessageBubble extends StatelessWidget {
  const UserMessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 48, top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.images.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final image in message.images)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(image.split(',').last),
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                  ],
                ),
              ),
            if (message.content.isNotEmpty)
              Text(
                message.content,
                style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 15),
              ),
          ],
        ),
      ),
    );
  }
}

class AssistantMessageView extends ConsumerStatefulWidget {
  const AssistantMessageView({super.key, required this.message});

  final ChatMessage message;

  @override
  ConsumerState<AssistantMessageView> createState() =>
      _AssistantMessageViewState();
}

class _AssistantMessageViewState
    extends ConsumerState<AssistantMessageView> {
  bool _reasoningExpanded = false;
  bool _toolExpanded = false;
  bool _speaking = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message.reasoning != null && widget.message.reasoning!.isNotEmpty)
            _ReasoningCard(
              reasoning: widget.message.reasoning!,
              seconds: widget.message.reasoningSeconds,
              expanded: _reasoningExpanded,
              onToggle: () =>
                  setState(() => _reasoningExpanded = !_reasoningExpanded),
            ),
          for (final tool in widget.message.toolCalls)
            _ToolCallCard(
              tool: tool,
              expanded: _toolExpanded,
              onToggle: () => setState(() => _toolExpanded = !_toolExpanded),
            ),
          if (message.content.isNotEmpty)
            MarkdownBody(
              data: widget.message.content,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 15, height: 1.7, color: scheme.onSurface),
                code: TextStyle(
                  fontFamily: 'monospace',
                  backgroundColor: scheme.surfaceContainerHighest,
                  fontSize: 13,
                ),
              ),
            ),
          if (widget.message.isLoading && message.content.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('AI思考中…', style: TextStyle(fontSize: 13)),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                onPressed: _speaking
                    ? null
                    : () async {
                        setState(() => _speaking = true);
                        try {
                          await SherpaTts.speak(message.content);
                        } catch (_) {
                          if (context.mounted) {
                            showToast(context, '朗读失败，请检查语音模型');
                          }
                        } finally {
                          if (mounted) setState(() => _speaking = false);
                        }
                      },
                icon: Icon(
                  _speaking ? Icons.hourglass_empty : Icons.volume_up_outlined,
                  size: 20,
                  color: scheme.outline,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: message.content));
                  if (context.mounted) showToast(context, '已复制');
                },
                icon: Icon(Icons.copy_outlined, size: 20, color: scheme.outline),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  ref.read(chatProvider.notifier).retryLastMessage();
                },
                icon: Icon(Icons.refresh, size: 20, color: scheme.outline),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReasoningCard extends StatelessWidget {
  const _ReasoningCard({
    required this.reasoning,
    required this.seconds,
    required this.expanded,
    required this.onToggle,
  });

  final String reasoning;
  final int seconds;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Row(
            children: [
              AnimatedRotation(
                turns: expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 160),
                child: Icon(Icons.chevron_right, size: 18, color: scheme.outline),
              ),
              const SizedBox(width: 6),
              Text(
                seconds > 0 ? '已深度思考（用时 $seconds 秒）' : '已深度思考',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 6),
            child: Text(
              reasoning,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToolCallCard extends StatelessWidget {
  const _ToolCallCard({
    required this.tool,
    required this.expanded,
    required this.onToggle,
  });

  final ToolCallInfo tool;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = tool.isRunning
        ? '执行中…'
        : tool.isSuccess == true
            ? '成功'
            : tool.isSuccess == false
                ? '失败'
                : '';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Row(
              children: [
                const Text('🔧', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  tool.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: Icon(Icons.chevron_right, size: 16, color: scheme.outline),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 4),
            Text('参数', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            Text(tool.argsSummary,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 4),
            Text('结果', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            Text(tool.resultSummary ?? '无结果',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
