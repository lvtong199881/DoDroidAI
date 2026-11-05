import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../ai/model_catalog.dart';
import '../../ai/model_manager.dart';
import '../../widgets/app_toast.dart';

/// 语音输入设置（对齐原生 fragment_stt_settings.xml + item_stt_model.xml）
class SttSettingsScreen extends StatefulWidget {
  const SttSettingsScreen({super.key});

  @override
  State<SttSettingsScreen> createState() => _SttSettingsScreenState();
}

class _SttSettingsScreenState extends State<SttSettingsScreen> {
  final _manager = ModelManager('stt');
  final _models = SttModels.all;
  ModelSource _source = ModelSource.hfMirror;
  final Map<String, bool> _downloaded = {};
  String _activeId = '';
  String? _downloadingId;
  int _progress = 0;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
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
          setState(() => _progress = total > 0 ? done * 100 ~/ total : 0);
        },
      );
      await _manager.setActive(model);
      if (!mounted) return;
      showToast(context, '下载完成');
    } on DioException catch (e) {
      if (!mounted || e.type == DioExceptionType.cancel) return;
      showToast(context, '下载失败，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _downloadingId = null;
          _progress = 0;
        });
      }
      _cancelToken = null;
      await _load();
    }
  }

  Future<void> _delete(VoiceModel model) async {
    _cancelToken?.cancel();
    await _manager.delete(model);
    await _load();
  }

  Future<void> _use(VoiceModel model) async {
    await _manager.setActive(model);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('语音输入', style: TextStyle(fontSize: 20)),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              '下载源',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                _SourceRadio(
                  label: '国内镜像（hf-mirror）',
                  selected: _source == ModelSource.hfMirror,
                  onTap: () async {
                    await _manager.setSource(ModelSource.hfMirror);
                    await _load();
                  },
                ),
                _SourceRadio(
                  label: 'HuggingFace',
                  selected: _source == ModelSource.huggingFace,
                  onTap: () async {
                    await _manager.setSource(ModelSource.huggingFace);
                    await _load();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final model in _models) _buildModelCard(model, scheme),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildModelCard(VoiceModel model, ColorScheme scheme) {
    final downloaded = _downloaded[model.id] == true;
    final downloading = _downloadingId == model.id;
    final active = downloaded && _activeId == model.id;
    final status = downloading
        ? '下载中'
        : active
            ? '使用中'
            : downloaded
                ? '已下载'
                : '未下载';
    final statusColor = active || downloading ? scheme.primary : scheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Text(status, style: TextStyle(fontSize: 13, color: statusColor)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            model.languages,
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            '${(model.totalBytes / 1048576).toStringAsFixed(0)} MB',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (downloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _progress / 100,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (downloaded && !downloading)
                TextButton(
                  onPressed: () => _delete(model),
                  child: const Text('删除'),
                ),
              const SizedBox(width: 8),
              if (!downloading)
                FilledButton.tonal(
                  onPressed: downloaded && active
                      ? null
                      : downloaded
                          ? () => _use(model)
                          : () => _startDownload(model),
                  child: Text(
                    downloaded && active ? '使用中' : (downloaded ? '使用' : '下载'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceRadio extends StatelessWidget {
  const _SourceRadio({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Radio<bool>(
                value: true,
                groupValue: selected ? true : null,
                onChanged: (_) => onTap(),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: scheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
