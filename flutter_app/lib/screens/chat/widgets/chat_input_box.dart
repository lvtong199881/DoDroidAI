import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    this.isLoading = false,
    this.onStop,
  });

  final TextEditingController controller;
  final VoidCallback onNewChat;
  final void Function(String text, List<String> images, bool deepThink) onSend;
  final bool isLoading;
  final VoidCallback? onStop;

  @override
  State<ChatInputBox> createState() => _ChatInputBoxState();
}

class _ChatInputBoxState extends State<ChatInputBox> {
  bool _deepThink = false;
  bool _webSearch = false;
  bool _recording = false;
  bool _voiceMode = false;
  bool _showAddOptions = false;
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
    _loadDeepThink();
  }

  Future<void> _loadDeepThink() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _deepThink = prefs.getBool('chat_deep_think') ?? false);
  }

  Future<void> _setDeepThink(bool value) async {
    setState(() => _deepThink = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chat_deep_think', value);
  }

  /// 添加选项区域：拍照 / 相册 / 文件（内联展开，不弹窗）
  Widget _buildAddOptions(ColorScheme scheme) {
    return Row(
      children: [
        Expanded(
          child: _addOption(
            scheme: scheme,
            icon: Icons.photo_camera_outlined,
            label: '拍照',
            onTap: () => _pickImage(source: ImageSource.camera),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _addOption(
            scheme: scheme,
            icon: Icons.photo_library_outlined,
            label: '相册',
            onTap: () => _pickImage(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _addOption(
            scheme: scheme,
            icon: Icons.insert_drive_file_outlined,
            label: '文件',
            onTap: _pickFile,
          ),
        ),
      ],
    );
  }

  Widget _addOption({
    required ColorScheme scheme,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() => _showAddOptions = false);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: scheme.onSurface),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
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
    setState(
      () => _fileText = text.length > 20000 ? text.substring(0, 20000) : text,
    );
  }

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    final picked = await ImagePicker().pickImage(
      source: source,
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
    final withFile = _fileText.isEmpty ? text : '$text\n\n附件内容：\n$_fileText';
    if (withFile.isEmpty && _images.isEmpty) return;
    widget.onSend(withFile.trim(), List.of(_images), _deepThink);
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
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
                  _toggleChip('深度思考', _deepThink, _setDeepThink),
                  const SizedBox(width: 8),
                  _toggleChip(
                    '智能搜索',
                    _webSearch,
                    (v) => setState(() => _webSearch = v),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        setState(() => _showAddOptions = !_showAddOptions),
                    icon: Icon(
                      _showAddOptions ? Icons.close : Icons.add,
                      color: scheme.onSurfaceVariant,
                    ),
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
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (widget.isLoading)
                    IconButton.filled(
                      onPressed: widget.onStop,
                      icon: const Icon(Icons.stop, size: 18),
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, _) {
                      if (widget.isLoading || value.text.trim().isEmpty) {
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
        ),
        if (_showAddOptions) ...[
          const SizedBox(height: 8),
          _buildAddOptions(scheme),
        ],
      ],
    );
  }

  Widget _toggleChip(
    String label,
    bool selected,
    ValueChanged<bool> onChanged,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: onChanged,
      showCheckmark: false,
      side: BorderSide(
        color: selected ? scheme.primary : scheme.outlineVariant,
      ),
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
