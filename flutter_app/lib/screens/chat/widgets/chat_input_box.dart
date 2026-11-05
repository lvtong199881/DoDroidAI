import 'package:flutter/material.dart';

class ChatInputBox extends StatefulWidget {
  const ChatInputBox({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onNewChat,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onNewChat;

  @override
  State<ChatInputBox> createState() => _ChatInputBoxState();
}

class _ChatInputBoxState extends State<ChatInputBox> {
  bool _deepThink = false;
  bool _webSearch = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.controller,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => widget.onSend(),
            decoration: const InputDecoration(
              hintText: '输入消息...',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _toggleChip('深度思考', _deepThink, (v) => setState(() => _deepThink = v)),
              const SizedBox(width: 8),
              _toggleChip('智能搜索', _webSearch, (v) => setState(() => _webSearch = v)),
              const Spacer(),
              IconButton(
                onPressed: widget.onNewChat,
                icon: Icon(Icons.add, color: scheme.onSurfaceVariant),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.mic_none, color: scheme.onSurfaceVariant),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: widget.onSend,
                icon: const Icon(Icons.arrow_upward, size: 18),
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  minimumSize: const Size(32, 32),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggleChip(String label, bool selected, ValueChanged<bool> onChanged) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: onChanged,
      showCheckmark: false,
      side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
      backgroundColor: selected
          ? scheme.primary.withValues(alpha: 0.15)
          : Colors.transparent,
      selectedColor: scheme.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? scheme.primary : scheme.onSurface,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
