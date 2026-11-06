import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model_catalog.dart';

/// 语音模型的本地管理：下载 / 删除 / 当前选择 / 下载源
class ModelManager {
  ModelManager(this.kind);

  /// stt 或 tts
  final String kind;

  String get _prefsActiveKey => '${kind}_active_model';
  String get _prefsSourceKey => '${kind}_model_source';
  String get _modelRoot => kind == 'stt' ? 'stt_models' : 'tts_models';

  Future<Directory> _rootDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$_modelRoot');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<String> modelDir(VoiceModel model) async {
    final root = await _rootDir();
    return '${root.path}/${model.id}';
  }

  Future<bool> isDownloaded(VoiceModel model) async {
    final dir = await modelDir(model);
    for (final file in model.files) {
      if (!File('$dir/${file.name}').existsSync()) return false;
    }
    return true;
  }

  Future<String> activeModelId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsActiveKey) ??
        (kind == 'stt' ? SttModels.senseVoice.id : TtsModels.matcha.id);
  }

  Future<void> setActive(VoiceModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsActiveKey, model.id);
  }

  Future<ModelSource> source() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsSourceKey);
    return value == 'huggingface' ? ModelSource.huggingFace : ModelSource.hfMirror;
  }

  Future<void> setSource(ModelSource source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsSourceKey,
      source == ModelSource.huggingFace ? 'huggingface' : 'hf_mirror',
    );
  }

  Future<void> delete(VoiceModel model) async {
    final dir = await modelDir(model);
    final target = Directory(dir);
    if (target.existsSync()) target.deleteSync(recursive: true);
  }

  Future<void> download(
    VoiceModel model, {
    required ModelSource source,
    CancelToken? cancelToken,
    void Function(int done, int total)? onProgress,
  }) async {
    final dir = await modelDir(model);
    final target = Directory(dir);
    if (!target.existsSync()) target.createSync(recursive: true);
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 30),
    ));
    var done = 0;
    final total = model.totalBytes;
    try {
      for (final file in model.files) {
        final url = downloadUrl(source, model.repo, file.name);
        final path = '$dir/${file.name}';
        final parent = Directory(File(path).parent.path);
        if (!parent.existsSync()) parent.createSync(recursive: true);
        await dio.download(
          url,
          path,
          cancelToken: cancelToken,
          onReceiveProgress: (received, fileTotal) {
            onProgress?.call(done + received, total);
          },
        );
        // 校验大小，避免半截文件被当成完成
        final expected = file.sizeBytes;
        final actual = File(path).lengthSync();
        if (expected > 0 && actual != expected) {
          throw StateError('文件不完整: ${file.name} ($actual/$expected)');
        }
        done += file.sizeBytes;
        onProgress?.call(done, total);
      }
    } catch (e) {
      // 失败或取消时清理半成品，避免下次下载被残留文件干扰
      try {
        if (target.existsSync()) target.deleteSync(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }
}
