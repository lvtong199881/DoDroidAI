import 'dart:async';

import 'package:flutter/foundation.dart';

import 'model_catalog.dart';
import 'model_manager.dart';

/// 下载任务状态
class DownloadTask {
  DownloadTask({
    required this.kind,
    required this.modelId,
  });

  final String kind; // stt / tts
  final String modelId;
  double progress = 0; // 0..1
  bool running = true;
  bool success = false;
  String? error;

  String get key => '${kind}_$modelId';
}

/// 全局下载管理器：页面退出后下载继续，页面重新进入可恢复进度
class DownloadManager {
  DownloadManager._();

  static final DownloadManager instance = DownloadManager._();
  final ValueNotifier<Map<String, DownloadTask>> tasks =
      ValueNotifier<Map<String, DownloadTask>>(<String, DownloadTask>{});

  final Map<String, ModelManager> _managers = {};

  ModelManager _managerOf(String kind) =>
      _managers.putIfAbsent(kind, () => ModelManager(kind));

  DownloadTask? taskFor(String kind, String modelId) =>
      tasks.value['${kind}_$modelId'];

  bool isDownloading(String kind, String modelId) =>
      taskFor(kind, modelId)?.running == true;

  /// 开始下载（若已在下载则复用）
  Future<void> start(String kind, VoiceModel model, {ModelSource? source}) async {
    final key = '${kind}_${model.id}';
    final existing = tasks.value[key];
    if (existing?.running == true) return;

    final task = DownloadTask(kind: kind, modelId: model.id);
    tasks.value = {...tasks.value, key: task};
    final manager = _managerOf(kind);
    try {
      final sourceId = source ?? await manager.source();
      await manager.download(
        model,
        source: sourceId,
        onProgress: (done, total) {
          task.progress = total > 0 ? done / total : 0;
          tasks.value = {...tasks.value};
        },
      );
      // 仅当当前没有可用激活模型时才自动启用，避免下载第二个模型把在用的换掉
      final activeId = await manager.activeModelId();
      final activeModel = kind == 'tts'
          ? TtsModels.byId(activeId)
          : SttModels.byId(activeId);
      final hasActive = await manager.isDownloaded(activeModel);
      if (!hasActive) {
        await manager.setActive(model);
      }
      task
        ..running = false
        ..success = true
        ..progress = 1;
    } catch (e) {
      task
        ..running = false
        ..error = e.toString();
    } finally {
      tasks.value = {...tasks.value};
    }
  }

  Future<void> delete(String kind, VoiceModel model) async {
    final key = '${kind}_${model.id}';
    await _managerOf(kind).delete(model);
    final next = {...tasks.value}..remove(key);
    tasks.value = next;
  }
}
