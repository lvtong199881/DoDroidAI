
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../../ai/sherpa_asr.dart';
import '../../../data/permission_policy_database.dart';
import '../../../l10n/app_strings.dart';



class ChatInputBox extends StatefulWidget {
  const ChatInputBox({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onNewChat,
  });

  final TextEditingController controller;
  final VoidCallback onNewChat;
  final void Function(String text, List<String> images) onSend;

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
  final List<String> _images = [];
  String _fileText = '';

  Future<void> _showAttachMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(AppStrings.of(context).t('attachImage')),
              onTap: () => Navigator.of(ctx).pop('image'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: Text(AppStrings.of(context).t('attachFile')),
              onTap: () => Navigator.of(ctx).pop('file'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'image') {
      await _pickImage();
    } else if (choice == 'file') {
      await _pickFile();
    }
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'json', 'csv', 'log'],
    );
    final file = files.isEmpty ? null : files.first;
    if (file == null) return;
    final path = file.path;
    if (path == null) return;
    final bytes = await File(path).readAsBytes();
    final text = utf8.decode(bytes, allowMalformed: true);
    if (!mounted) return;
    setState(() => _fileText = text.length > 20000 ? text.substring(0, 20000) : text);
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1568,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final isPng = picked.path.toLowerCase().endsWith('.png');
    final dataUrl =
        'data:image/${isPng ? 'png' : 'jpeg'};base64,${base64Encode(bytes)}';
    if (!mounted) return;
    setState(() => _images.add(dataUrl));
  }

  void _send() {
    final text = widget.controller.text.trim();
    final withFile = _fileText.isEmpty
        ? text
        : '$text\n\n附件内容：\n$_fileText';
    if (withFile.isEmpty && _images.isEmpty) return;
    widget.onSend(withFile.trim(), List.of(_images));
    widget.controller.clear();
    setState(() {
      _images.clear();
      _fileText = '';
    });
  }

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

    final policy = PermissionPolicyRepository.instance;
    final denied = await policy.isDenied('microphone');
    if (!mounted) return;
    if (denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('麦克风权限已被拒绝，请在系统设置中开启'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final hasPerm = await _recorder.hasPermission();
    if (!mounted) return;
    if (!hasPerm) {
      await policy.setDenied('microphone');
      if (!mounted) return;
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
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: AppStrings.of(context).inputHint,
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                onPressed: _showAttachMenu,
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
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: widget.controller,
                builder: (context, value, _) {
                  if (value.text.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                    ),
                  );
                },
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
          : scheme.surface,
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
