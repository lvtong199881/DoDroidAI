
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../../ai/sherpa_asr.dart';



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
  bool _recording = false;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _micSub;
  final List<int> _pcmBuffer = [];

  Future<void> _toggleMic() async {
    if (_recording) {
      setState(() => _recording = false);
      await _micSub?.cancel();
      _micSub = null;
      await _recorder.stop();
      if (_pcmBuffer.isEmpty) return;
      final samples = Float32List(_pcmBuffer.length ~/ 2);
      for (var i = 0; i < samples.length; i++) {
        final lo = _pcmBuffer[i * 2];
        final hi = _pcmBuffer[i * 2 + 1];
        var v = (hi << 8) | lo;
        if (v >= 32768) v -= 65536;
        samples[i] = v / 32768.0;
      }
      _pcmBuffer.clear();
      final text = await SherpaAsr.transcribe(samples);
      if (!mounted) return;
      if (text.isNotEmpty) {
        widget.controller.text = text;
        widget.controller.selection =
            TextSelection.collapsed(offset: text.length);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未识别到语音'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    final hasPerm = await _recorder.hasPermission();
    if (!mounted) return;
    if (!hasPerm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先授予录音权限'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    _pcmBuffer.clear();
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    ));
    _micSub = stream.listen((data) => _pcmBuffer.addAll(data));
    setState(() => _recording = true);
  }

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
                onPressed: _toggleMic,
                icon: Icon(
                  _recording ? Icons.mic : Icons.mic_none,
                  color: _recording ? scheme.error : scheme.onSurfaceVariant,
                ),
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
