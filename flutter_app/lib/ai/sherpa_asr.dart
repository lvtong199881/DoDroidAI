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
