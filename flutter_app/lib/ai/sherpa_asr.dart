import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'speech_worker.dart';

/// 离线 ASR（sherpa-onnx SenseVoice）。
/// 识别在常驻 isolate 中执行，避免阻塞 UI。
class SherpaAsr {
  static Future<String> modelDir() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/stt_models/sense_voice_2025_09_09';
  }

  static Future<bool> isReady() async {
    final dir = await modelDir();
    return File('$dir/model.int8.onnx').existsSync();
  }

  static Future<void>? _warming;

  /// 预热：把模型加载移出首次识别路径；模型未就绪或失败时允许下次重试
  static Future<void> warmUp() {
    _warming ??= _warmUp();
    return _warming!;
  }

  static Future<void> _warmUp() async {
    final dir = await modelDir();
    if (!File('$dir/model.int8.onnx').existsSync()) {
      _warming = null;
      return;
    }
    try {
      await SpeechWorker.warmUpAsr(dir);
    } catch (e) {
      debugPrint('SherpaAsr: 预热失败 $e');
      _warming = null;
    }
  }

  static Future<String> transcribe(
    Float32List samples, {
    int sampleRate = 16000,
  }) async {
    if (samples.isEmpty) return '';
    final dir = await modelDir();
    if (!File('$dir/model.int8.onnx').existsSync()) {
      debugPrint('SherpaAsr: 模型未下载 $dir');
      return '';
    }
    try {
      return await SpeechWorker.transcribe(
        modelDir: dir,
        samples: samples.toList(growable: false),
      );
    } catch (e) {
      debugPrint('SherpaAsr: 识别失败 $e');
      return '';
    }
  }
}
