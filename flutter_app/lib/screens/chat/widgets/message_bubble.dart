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
  final Map<int, bool> _expanded = {};
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
          for (var i = 0; i < message.blocks.length; i++)
            _buildBlock(context, scheme, i, message.blocks[i]),
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

  Widget _buildBlock(
    BuildContext context,
    ColorScheme scheme,
    int index,
    MessageBlock block,
  ) {
    final expanded = _expanded[index] ?? false;
    void toggle() => setState(() => _expanded[index] = !expanded);

    switch (block.kind) {
      case MessageBlockKind.reasoning:
        return _CollapsibleBlock(
          title: block.seconds > 0
              ? '已深度思考（用时 ${block.seconds} 秒）'
              : '已深度思考',
          expanded: expanded,
          onToggle: toggle,
          child: Text(
            block.text,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
        );
      case MessageBlockKind.toolCall:
        final tool = block.tool!;
        return _CollapsibleBlock(
          title: tool.name,
          statusTag: _statusTagFor(scheme, tool),
          expanded: expanded,
          onToggle: toggle,
          child: _ToolDetail(tool: tool),
        );
      case MessageBlockKind.text:
        return MarkdownBody(
          data: block.text,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(fontSize: 15, height: 1.7, color: scheme.onSurface),
            code: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: scheme.surfaceContainerHighest,
              fontSize: 13,
            ),
          ),
        );
    }
  }

  Widget? _statusTagFor(ColorScheme scheme, ToolCallInfo tool) {
    if (tool.isRunning) {
      return _StatusTag(text: '执行中', color: scheme.primary);
    }
    if (tool.isSuccess == true) {
      return const _StatusTag(text: '成功', color: Color(0xFF1E8E5A));
    }
    if (tool.isSuccess == false) {
      return _StatusTag(text: '失败', color: scheme.error);
    }
    return const _StatusTag(text: '已取消', color: Color(0xFF5A5F6B));
  }
}

/// 统一折叠块：箭头 + 标题（+ 可选状态 tag）+ 可折叠内容
class _CollapsibleBlock extends StatelessWidget {
  const _CollapsibleBlock({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.statusTag,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final Widget? statusTag;

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
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
                ),
              ),
              if (statusTag != null) ...[
                const SizedBox(width: 8),
                statusTag!,
              ],
            ],
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 6, bottom: 4),
            child: child,
          ),
      ],
    );
  }
}

/// 工具状态 tag
class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}


/// 工具块展开内容：参数 + 执行结果
class _ToolDetail extends StatelessWidget {
  const _ToolDetail({required this.tool});

  final ToolCallInfo tool;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monoStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.5,
      color: scheme.onSurface,
    );
    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tool.arguments.isNotEmpty) ...[
          Text('参数', style: labelStyle),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(tool.arguments, style: monoStyle),
          ),
        ],
        if (tool.resultSummary != null && tool.resultSummary!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('结果', style: labelStyle),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(tool.resultSummary!, style: monoStyle),
          ),
        ],
      ],
    );
  }
}
