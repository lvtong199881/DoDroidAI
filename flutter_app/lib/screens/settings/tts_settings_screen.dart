import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../ai/model_catalog.dart';
import '../../ai/model_manager.dart';
import '../../ai/sherpa_tts.dart';
import '../../widgets/app_toast.dart';

/// 语音输出设置：多模型列表（Matcha 更快 / MeloTTS 兼容）
class TtsSettingsScreen extends StatefulWidget {
  const TtsSettingsScreen({super.key});

  @override
  State<TtsSettingsScreen> createState() => _TtsSettingsScreenState();
}

class _TtsSettingsScreenState extends State<TtsSettingsScreen> {
  final _manager = ModelManager('tts');
  final _models = TtsModels.all;
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
    final activeId = await _manager.activeModelId();
    final downloaded = <String, bool>{};
    for (final model in _models) {
      downloaded[model.id] = await _isReady(model);
    }
    if (!mounted) return;
    setState(() {
      _activeId = activeId;
      _downloaded
        ..clear()
        ..addAll(downloaded);
    });
  }

  Future<bool> _isReady(VoiceModel model) async {
    final downloaded = await _manager.isDownloaded(model);
    if (!downloaded) return false;
    if (model.kind == 'matcha') {
      final dir = await _manager.modelDir(model);
      return await _manager.isDownloaded(model) &&
          await Future.value(dir.isNotEmpty);
    }
    return true;
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
      final source = await _manager.source();
      await _manager.download(
        model,
        source: source,
        cancelToken: token,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() => _progress = total > 0 ? done * 100 ~/ total : 0);
        },
      );
      await _manager.setActive(model);
      await SherpaTts.warmUp();
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
    await SherpaTts.warmUp();
    await _load();
    if (!mounted) return;
    showToast(context, '已切换为 ${model.displayName}');
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
        title: const Text('语音输出', style: TextStyle(fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final model in _models) _buildCard(model, scheme),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '离线合成，不依赖系统语音引擎；下载后自动启用。Matcha 为 flow-matching 引擎，首声更快。',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(VoiceModel model, ColorScheme scheme) {
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
              Text(
                status,
                style: TextStyle(
                  fontSize: 13,
                  color: active || downloading
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
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
