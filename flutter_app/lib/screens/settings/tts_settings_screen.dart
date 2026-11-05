import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../ai/model_catalog.dart';
import '../../ai/model_manager.dart';
import '../../widgets/app_toast.dart';

/// 语音输出设置（对齐原生 fragment_tts_settings.xml：单模型详情页）
class TtsSettingsScreen extends StatefulWidget {
  const TtsSettingsScreen({super.key});

  @override
  State<TtsSettingsScreen> createState() => _TtsSettingsScreenState();
}

class _TtsSettingsScreenState extends State<TtsSettingsScreen> {
  final _manager = ModelManager('tts');
  final _model = TtsModels.melo;
  bool _downloaded = false;
  bool _active = false;
  bool _downloading = false;
  int _progress = 0;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _render();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _render() async {
    final downloaded = await _manager.isDownloaded(_model);
    final activeId = await _manager.activeModelId();
    if (!mounted) return;
    setState(() {
      _downloaded = downloaded;
      _active = downloaded && activeId == _model.id;
    });
  }

  Future<void> _startDownload() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    final token = CancelToken();
    _cancelToken = token;
    try {
      final source = await _manager.source();
      await _manager.download(
        _model,
        source: source,
        cancelToken: token,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() => _progress = total > 0 ? done * 100 ~/ total : 0);
        },
      );
      await _manager.setActive(_model);
      if (!mounted) return;
      showToast(context, '下载完成');
    } on DioException catch (e) {
      if (!mounted || e.type == DioExceptionType.cancel) return;
      showToast(context, '下载失败，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _progress = 0;
        });
      }
      _cancelToken = null;
      await _render();
    }
  }

  Future<void> _delete() async {
    _cancelToken?.cancel();
    await _manager.delete(_model);
    await _render();
  }

  Future<void> _use() async {
    await _manager.setActive(_model);
    await _render();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _downloading
        ? '下载中'
        : _active
            ? '使用中'
            : _downloaded
                ? '已下载'
                : '';
    final sizeMb = _model.totalBytes ~/ 1024 ~/ 1024;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('语音输出', style: TextStyle(fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _model.displayName,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_model.languages} · $sizeMb MB',
                      style: TextStyle(
                        fontSize: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                status,
                style: TextStyle(fontSize: 13, color: scheme.primary),
              ),
            ],
          ),
          if (_downloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _progress / 100,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 4),
            Text(
              '$_progress%',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (!_downloaded && !_downloading)
                FilledButton(
                  onPressed: _startDownload,
                  child: const Text('下载'),
                ),
              if (_downloaded && !_active)
                FilledButton(
                  onPressed: _use,
                  child: const Text('使用'),
                ),
              if (_downloaded) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _delete,
                  child: const Text('删除'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '离线合成，不依赖系统语音引擎；下载后自动启用。',
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
