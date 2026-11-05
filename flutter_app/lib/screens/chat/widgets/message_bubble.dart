import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../ai/speech_channel.dart';
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
        child: Text(
          message.content,
          style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 15),
        ),
      ),
    );
  }
}

class AssistantMessageView extends StatefulWidget {
  const AssistantMessageView({super.key, required this.message});

  final ChatMessage message;

  @override
  State<AssistantMessageView> createState() => _AssistantMessageViewState();
}

class _AssistantMessageViewState extends State<AssistantMessageView> {
  bool _reasoningExpanded = false;
  bool _toolExpanded = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.reasoning != null && message.reasoning!.isNotEmpty)
            _ReasoningCard(
              reasoning: message.reasoning!,
              seconds: message.reasoningSeconds,
              expanded: _reasoningExpanded,
              onToggle: () =>
                  setState(() => _reasoningExpanded = !_reasoningExpanded),
            ),
          for (final tool in message.toolCalls)
            _ToolCallCard(
              tool: tool,
              expanded: _toolExpanded,
              onToggle: () => setState(() => _toolExpanded = !_toolExpanded),
            ),
          if (message.content.isNotEmpty)
            MarkdownBody(
              data: message.content,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(fontSize: 15, height: 1.7, color: scheme.onSurface),
                code: TextStyle(
                  fontFamily: 'monospace',
                  backgroundColor: scheme.surfaceContainerHighest,
                  fontSize: 13,
                ),
              ),
            ),
          if (message.isLoading && message.content.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('AI思考中…', style: TextStyle(fontSize: 13)),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                onPressed: () => SpeechChannel.speak(message.content),
                icon: Icon(Icons.volume_up_outlined, size: 20, color: scheme.outline),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.copy_outlined, size: 20, color: scheme.outline),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {},
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
