import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../ai/model_catalog.dart';
import '../../ai/model_manager.dart';
import '../../widgets/app_toast.dart';

/// 语音输入/输出的模型管理页（对齐原生 Stt/TtsSettingsFragment）
class VoiceModelSettingsScreen extends StatefulWidget {
  const VoiceModelSettingsScreen({super.key, required this.kind});

  /// 'stt' 或 'tts'
  final String kind;

  @override
  State<VoiceModelSettingsScreen> createState() =>
      _VoiceModelSettingsScreenState();
}

class _VoiceModelSettingsScreenState extends State<VoiceModelSettingsScreen> {
  late final ModelManager _manager;
  late final List<VoiceModel> _models;
  ModelSource _source = ModelSource.hfMirror;
  final Map<String, bool> _downloaded = {};
  String _activeId = '';
  String? _downloadingId;
  int _progress = 0;
  CancelToken? _cancelToken;
  bool _loading = true;

  bool get _isStt => widget.kind == 'stt';

  @override
  void initState() {
    super.initState();
    _manager = ModelManager(widget.kind);
    _models = _isStt ? SttModels.all : TtsModels.all;
    _load();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final source = await _manager.source();
    final activeId = await _manager.activeModelId();
    final downloaded = <String, bool>{};
    for (final model in _models) {
      downloaded[model.id] = await _manager.isDownloaded(model);
    }
    if (!mounted) return;
    setState(() {
      _source = source;
      _activeId = activeId;
      _downloaded
        ..clear()
        ..addAll(downloaded);
      _loading = false;
    });
  }

  Future<void> _startDownload(VoiceModel model) async {
    if (_downloadingId != null) return;
    setState(() {
      _downloadingId = model.id;
      _progress = 0;
    });
    final token = CancelToken();
    _cancelToken = token;
    try {
      await _manager.download(
        model,
        source: _source,
        cancelToken: token,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _progress = total > 0 ? (done * 100 ~/ total) : 0;
          });
        },
      );
      await _manager.setActive(model);
      if (!mounted) return;
      showToast(context, '${model.displayName} 下载完成');
      await _load();
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.type == DioExceptionType.cancel) return;
      showToast(context, '下载失败，请检查网络');
    } finally {
      if (mounted) {
        setState(() {
          _downloadingId = null;
          _progress = 0;
        });
      }
      _cancelToken = null;
    }
  }

  Future<void> _delete(VoiceModel model) async {
    _cancelToken?.cancel();
    await _manager.delete(model);
    await _load();
    if (!mounted) return;
    showToast(context, '已删除 ${model.displayName}');
  }

  Future<void> _use(VoiceModel model) async {
    await _manager.setActive(model);
    await _load();
    if (!mounted) return;
    showToast(context, '已切换为 ${model.displayName}');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _isStt ? '语音输入' : '语音输出';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title, style: const TextStyle(fontSize: 20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Text('下载源', style: TextStyle(fontSize: 15)),
                    const Spacer(),
                    SegmentedButton<ModelSource>(
                      segments: const [
                        ButtonSegment(
                          value: ModelSource.hfMirror,
                          label: Text('HF Mirror'),
                        ),
                        ButtonSegment(
                          value: ModelSource.huggingFace,
                          label: Text('HuggingFace'),
                        ),
                      ],
                      selected: {_source},
                      onSelectionChanged: (selection) async {
                        await _manager.setSource(selection.first);
                        await _load();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final model in _models) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                model.displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (_activeId == model.id)
                              Text(
                                '使用中',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${model.formatSize(model.totalBytes)} · ${model.languages}',
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_downloadingId == model.id) ...[
                          LinearProgressIndicator(value: _progress / 100),
                          const SizedBox(height: 4),
                          Text('下载中 $_progress%', style: const TextStyle(fontSize: 12)),
                        ] else
                          Row(
                            children: [
                              if (_downloaded[model.id] == true) ...[
                                if (_activeId != model.id)
                                  FilledButton.tonal(
                                    onPressed: () => _use(model),
                                    child: const Text('使用'),
                                  ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => _delete(model),
                                  child: Text(
                                    '删除',
                                    style: TextStyle(color: scheme.error),
                                  ),
                                ),
                              ] else
                                FilledButton(
                                  onPressed: () => _startDownload(model),
                                  child: const Text('下载'),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}
