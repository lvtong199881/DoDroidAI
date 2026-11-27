import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model_catalog.dart';

/// 下载完成后记录每个文件真实字节数的清单文件名。
/// 有了它，启动时能精确判断文件是否被截断/替换（不再只靠清单大小估算）。
const String modelMetaFileName = '.model_meta.json';

/// 清单大小的相对容差：0.1%（至少 4 KiB）。
///
/// 原先用 ±5%，237MB 的 sense_voice `model.int8.onnx` 少 11MB
/// （225,665,753 / 237,115,547，-4.83%）仍被当成「已下载」，
/// 结果 sherpa 加载时报 `Protobuf parsing failed`，且永远不重下。
const double modelSizeToleranceRatio = 0.001;
const int modelSizeToleranceFloorBytes = 4096;

/// 语音模型的本地管理：下载 / 删除 / 当前选择 / 下载源
class ModelManager {
  ModelManager(this.kind, {this.supportDirOverride});

  /// stt 或 tts
  final String kind;

  /// 测试用：绕过 path_provider，指定应用支持目录
  final String? supportDirOverride;

  String get _prefsActiveKey => '${kind}_active_model';
  String get _prefsSourceKey => '${kind}_model_source';
  String get _modelRoot => kind == 'stt' ? 'stt_models' : 'tts_models';

  Future<Directory> _rootDir() async {
    final base = supportDirOverride != null
        ? Directory(supportDirOverride!)
        : await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/$_modelRoot');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<String> modelDir(VoiceModel model) async {
    final root = await _rootDir();
    return '${root.path}/${model.id}';
  }

  /// 模型是否可用：文件都在，且大小与下载时记录/清单一致。
  /// 半截文件、被替换的文件都算「未下载」，交给下载流程重下。
  Future<bool> isDownloaded(VoiceModel model) async {
    final dir = await modelDir(model);
    final recorded = await _readMeta(model);
    for (final file in model.files) {
      final target = File('$dir/${file.name}');
      if (!target.existsSync()) return false;
      if (!isModelFileIntact(
        actual: target.lengthSync(),
        recorded: recorded[file.name],
        expected: file.sizeBytes,
      )) {
        return false;
      }
    }
    return true;
  }

  Future<Map<String, int>> _readMeta(VoiceModel model) async {
    try {
      final file = File('${await modelDir(model)}/$modelMetaFileName');
      if (!file.existsSync()) return const {};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return const {};
      final files = decoded['files'];
      if (files is! Map) return const {};
      final sizes = <String, int>{};
      files.forEach((name, size) {
        if (name is String && size is int) sizes[name] = size;
      });
      return sizes;
    } catch (e) {
      debugPrint('ModelManager: 读取 $modelMetaFileName 失败 $e');
      return const {};
    }
  }

  Future<void> _writeMeta(VoiceModel model, Map<String, int> sizes) async {
    try {
      final file = File('${await modelDir(model)}/$modelMetaFileName');
      await file.writeAsString(jsonEncode({
        'version': 1,
        'model': model.id,
        'files': sizes,
      }));
    } catch (e) {
      // 写清单失败只影响下次的精确校验，不影响本次使用
      debugPrint('ModelManager: 写入 $modelMetaFileName 失败 $e');
    }
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
    // 记录每个文件下载后的真实大小，成功后写入清单
    final written = <String, int>{};
    try {
      for (final file in model.files) {
        final url =
            file.url ?? downloadUrl(source, file.repo ?? model.repo, file.name);
        final path = '$dir/${file.name}';
        final parent = Directory(File(path).parent.path);
        if (!parent.existsSync()) parent.createSync(recursive: true);
        var fileReceived = 0;
        var fileTotal = -1;
        await dio.download(
          url,
          path,
          cancelToken: cancelToken,
          onReceiveProgress: (received, totalBytes) {
            fileReceived = received;
            fileTotal = totalBytes;
            onProgress?.call(done + received, total);
          },
        );
        final actual = File(path).lengthSync();
        if (actual <= 0) {
          throw StateError('文件为空: ${file.name}');
        }
        // 服务器给了 Content-Length：收到的字节数必须与之相等，
        // 这样即使清单大小本身不准，也不会把半截文件当成完成。
        if (fileTotal > 0 && fileReceived != fileTotal) {
          throw StateError(
            '下载不完整: ${file.name} ($fileReceived/$fileTotal)',
          );
        }
        // 拿不到 Content-Length 时退化为与清单大小比对（严格容差）
        if (fileTotal <= 0 &&
            !isModelFileSizeAcceptable(actual, file.sizeBytes)) {
          throw StateError('文件大小异常: ${file.name} ($actual/${file.sizeBytes})');
        }
        if (file.sizeBytes > 0 && actual != file.sizeBytes) {
          debugPrint(
            'ModelManager: ${file.name} 实际 $actual 与清单 ${file.sizeBytes} '
            '不一致（下载已完整，按实际大小记录）',
          );
        }
        written[file.name] = actual;
        done += file.sizeBytes;
        onProgress?.call(done, total);
      }
      await _writeMeta(model, written);
    } catch (e) {
      // 失败或取消时清理半成品，避免下次下载被残留文件干扰
      try {
        if (target.existsSync()) target.deleteSync(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }
}

/// 清单大小的允许偏差：0.1%，下限 [modelSizeToleranceFloorBytes]。
int modelFileSizeTolerance(int expected) {
  final scaled = (expected * modelSizeToleranceRatio).floor();
  return scaled > modelSizeToleranceFloorBytes
      ? scaled
      : modelSizeToleranceFloorBytes;
}

/// 模型文件大小校验：只在「有清单、但没有下载时记录」的场景使用（老数据）。
/// expected <= 0 表示清单大小未知，只要求非空。
bool isModelFileSizeAcceptable(int actual, int expected) {
  if (actual <= 0) return false;
  if (expected <= 0) return true;
  return (actual - expected).abs() <= modelFileSizeTolerance(expected);
}

/// 单个模型文件是否完好：
/// - 有下载时记录的真实大小（`[modelMetaFileName]`）→ 必须精确相等，
///   截断、追加、被替换都会判为损坏；
/// - 没有记录（老版本下载的，没有清单）→ 与清单大小比对（严格容差）。
bool isModelFileIntact({
  required int actual,
  required int? recorded,
  required int expected,
}) {
  if (actual <= 0) return false;
  if (recorded != null) return actual == recorded;
  return isModelFileSizeAcceptable(actual, expected);
}
