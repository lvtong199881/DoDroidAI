
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
import '../../../widgets/app_toast.dart';
import 'voice_input_overlay.dart';
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
  bool _voiceMode = false;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _micSub;
  Timer? _ampTimer;
  bool _ampBusy = false;
  final List<int> _pcmBuffer = [];
  final List<String> _images = [];
  String _fileText = '';

  @override
  void initState() {
    super.initState();
    // TEMP: dart-define=VOICE_LOOP_TEST 时自动跑两轮录音，验证可重复录音
    if (const bool.fromEnvironment('VOICE_LOOP_TEST')) {
      Future.delayed(const Duration(seconds: 3), () async {
        for (var i = 0; i < 2; i++) {
          debugPrint('VOICE_LOOP start#$i');
          await _startVoice();
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          await _stopVoice();
          debugPrint('VOICE_LOOP stop#$i recorderNull=${_recorder == null}');
          await Future<void>.delayed(const Duration(milliseconds: 800));
        }
        debugPrint('VOICE_LOOP done');
      });
    }
  }

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

  Future<void> _startVoice() async {
    if (_recording) return;
    try {
      final policy = PermissionPolicyRepository.instance;
      final denied = await policy.isDenied('microphone');
      if (!mounted) return;
      if (denied) {
        showToast(context, '麦克风权限已被拒绝，请在系统设置中开启');
        return;
      }
      // 每次录音用全新实例，避免复用状态导致第二次 startStream 失败
      await _recorder?.dispose();
      final recorder = AudioRecorder();
      _recorder = recorder;

      final hasPerm = await recorder.hasPermission();
      if (!mounted) return;
      if (!hasPerm) {
        await policy.setDenied('microphone');
        if (!mounted) return;
        showToast(context, '请先授予录音权限');
        return;
      }

      _pcmBuffer.clear();
      final stream = await recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      _micSub = stream.listen((data) => _pcmBuffer.addAll(data));
      // onAmplitudeChanged 是单订阅流，第二次录音会抛 "Stream has already been listened to"，
      // 这里改为定时轮询 getAmplitude（每次调用独立）。
      _ampTimer?.cancel();
      _ampTimer = Timer.periodic(const Duration(milliseconds: 80), (_) async {
        if (_ampBusy) return;
        _ampBusy = true;
        try {
          final amp = await recorder.getAmplitude();
          final normalized = ((amp.current + 60) / 60).clamp(0.0, 1.0);
          VoiceInputOverlay.update(normalized);
        } catch (_) {
          // 录音停止瞬间可能失败，忽略
        } finally {
          _ampBusy = false;
        }
      });
      if (!mounted) return;
      setState(() => _recording = true);
      VoiceInputOverlay.show(context);
    } catch (e) {
      debugPrint('MIC start failed: $e');
      await _recorder?.dispose();
      _recorder = null;
      _ampTimer?.cancel();
      _ampTimer = null;
      if (mounted) showToast(context, '语音输入暂不可用：$e');
    }
  }

  Future<void> _stopVoice() async {
    if (!_recording) return;
    setState(() => _recording = false);
    VoiceInputOverlay.dismiss();
    try {
      _ampTimer?.cancel();
      _ampTimer = null;
      await _micSub?.cancel();
      _micSub = null;
      await _recorder?.stop();
      await _recorder?.dispose();
    } catch (e) {
      debugPrint('MIC stop failed: $e');
    } finally {
      _recorder = null;
    }
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
      // 语音输入后直接发送
      widget.controller.text = text;
      _send();
    } else {
      showToast(context, '未识别到语音');
    }
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
          if (_voiceMode)
            Listener(
              onPointerDown: (_) => _startVoice(),
              onPointerUp: (_) => _stopVoice(),
              onPointerCancel: (_) => _stopVoice(),
              child: Container(
                height: 48,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _recording ? '正在录音…' : '按住说话',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            )
          else
            TextField(
              controller: widget.controller,
              minLines: 1,
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: AppStrings.of(context).inputHint,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                onPressed: () => setState(() => _voiceMode = !_voiceMode),
                icon: Icon(
                  _voiceMode ? Icons.keyboard : Icons.mic_none,
                  size: 24,
                  color: scheme.onSurfaceVariant,
                ),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
