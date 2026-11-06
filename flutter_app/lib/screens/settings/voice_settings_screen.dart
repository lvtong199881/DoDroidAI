import 'package:flutter/material.dart';

import '../../ai/download_manager.dart';
import '../../ai/model_catalog.dart';
import '../../ai/model_manager.dart';
import '../../widgets/app_toast.dart';

/// 语音设置：输入 + 输出合并页，下载在全局管理器里进行（退出页面不中断）
class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  final _sttManager = ModelManager('stt');
  final _ttsManager = ModelManager('tts');
  ModelSource _sttSource = ModelSource.hfMirror;
  String _sttActiveId = '';
  String _ttsActiveId = '';
  final Map<String, bool> _downloaded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sttSource = await _sttManager.source();
    final sttActive = await _sttManager.activeModelId();
    final ttsActive = await _ttsManager.activeModelId();
    final downloaded = <String, bool>{};
    for (final model in SttModels.all) {
      downloaded['stt_${model.id}'] = await _sttManager.isDownloaded(model);
    }
    for (final model in TtsModels.all) {
      downloaded['tts_${model.id}'] = await _ttsManager.isDownloaded(model);
    }
    if (!mounted) return;
    setState(() {
      _sttSource = sttSource;
      _sttActiveId = sttActive;
      _ttsActiveId = ttsActive;
      _downloaded
        ..clear()
        ..addAll(downloaded);
    });
  }

  Future<void> _start(String kind, VoiceModel model) async {
    await DownloadManager.instance.start(
      kind,
      model,
      source: kind == 'stt' ? _sttSource : null,
    );
    await _load();
    final task = DownloadManager.instance.taskFor(kind, model.id);
    if (!mounted) return;
    showToast(
      context,
      task?.error == null ? '${model.displayName} 下载完成' : '下载失败，请重试',
    );
  }

  Future<void> _delete(String kind, VoiceModel model) async {
    await DownloadManager.instance.delete(kind, model);
    await _load();
  }

  Future<void> _use(String kind, VoiceModel model) async {
    final manager = kind == 'stt' ? _sttManager : _ttsManager;
    await manager.setActive(model);
    await _load();
    if (mounted) showToast(context, '已切换为 ${model.displayName}');
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
        title: const Text('语音', style: TextStyle(fontSize: 20)),
      ),
      body: ValueListenableBuilder<Map<String, DownloadTask>>(
        valueListenable: DownloadManager.instance.tasks,
        builder: (context, tasks, _) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const _SectionHeader(text: '语音输入'),
            _SourceRow(
              current: _sttSource,
              onChanged: (value) async {
                await _sttManager.setSource(value);
                if (!mounted) return;
                setState(() => _sttSource = value);
              },
            ),
            for (final model in SttModels.all)
              _ModelCard(
                model: model,
                downloaded: _downloaded['stt_${model.id}'] == true,
                active: _sttActiveId == model.id,
                task: tasks['stt_${model.id}'],
                onDownload: () => _start('stt', model),
                onUse: () => _use('stt', model),
                onDelete: () => _delete('stt', model),
              ),
            const SizedBox(height: 8),
            const _SectionHeader(text: '语音输出'),
            for (final model in TtsModels.all)
              _ModelCard(
                model: model,
                downloaded: _downloaded['tts_${model.id}'] == true,
                active: _ttsActiveId == model.id,
                task: tasks['tts_${model.id}'],
                onDownload: () => _start('tts', model),
                onUse: () => _use('tts', model),
                onDelete: () => _delete('tts', model),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '模型下载在后台进行，退出本页不会中断；下载完成后自动启用。',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.current, required this.onChanged});

  final ModelSource current;
  final ValueChanged<ModelSource> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text('下载源', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          Expanded(
            child: RadioGroup<ModelSource>(
              groupValue: current,
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
              child: const Row(
                children: [
                  Expanded(
                    child: RadioListTile<ModelSource>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('HF 镜像', style: TextStyle(fontSize: 14)),
                      value: ModelSource.hfMirror,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<ModelSource>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('HuggingFace', style: TextStyle(fontSize: 14)),
                      value: ModelSource.huggingFace,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.downloaded,
    required this.active,
    required this.task,
    required this.onDownload,
    required this.onUse,
    required this.onDelete,
  });

  final VoiceModel model;
  final bool downloaded;
  final bool active;
  final DownloadTask? task;
  final VoidCallback onDownload;
  final VoidCallback onUse;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final downloading = task?.running == true;
    final status = downloading
        ? '下载中 ${(task!.progress * 100).toStringAsFixed(0)}%'
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
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
            '${model.languages} · ${(model.totalBytes / 1048576).toStringAsFixed(0)} MB',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          if (downloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: task!.progress,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (downloaded && !downloading)
                TextButton(onPressed: onDelete, child: const Text('删除')),
              const SizedBox(width: 8),
              if (!downloading)
                FilledButton.tonal(
                  onPressed: downloaded
                      ? (active ? null : onUse)
                      : onDownload,
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
