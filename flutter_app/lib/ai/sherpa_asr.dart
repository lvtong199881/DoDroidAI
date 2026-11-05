import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// 纯 Flutter 离线 ASR（sherpa-onnx SenseVoice）
class SherpaAsr {
  static sherpa.OfflineRecognizer? _recognizer;
  static bool _ready = false;

  static Future<bool> init() async {
    if (_ready) return true;
    try {
      sherpa.initBindings();
      final dir = await getApplicationSupportDirectory();
      final modelDir = '${dir.path}/stt_models/sense_voice_2025_09_09';
      if (!File('$modelDir/model.int8.onnx').existsSync()) {
        return false;
      }
      _recognizer = sherpa.OfflineRecognizer(
        sherpa.OfflineRecognizerConfig(
          feat: const sherpa.FeatureConfig(
            sampleRate: 16000,
            featureDim: 80,
          ),
          model: sherpa.OfflineModelConfig(
            senseVoice: sherpa.OfflineSenseVoiceModelConfig(
              model: '$modelDir/model.int8.onnx',
            ),
            tokens: '$modelDir/tokens.txt',
            numThreads: 2,
          ),
        ),
      );
      _ready = true;
      debugPrint('SherpaAsr: 初始化成功');
      return true;
    } catch (e) {
      debugPrint('SherpaAsr: 初始化失败 $e');
      _ready = false;
      return false;
    }
  }

  static Future<String> transcribe(
    Float32List samples, {
    int sampleRate = 16000,
  }) async {
    if (samples.isEmpty) return '';
    if (!await init()) return '';
    final recognizer = _recognizer;
    if (recognizer == null) return '';
    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);
      return result.text.trim();
    } catch (e) {
      debugPrint('SherpaAsr: 识别失败 $e');
      return '';
    } finally {
      stream.free();
    }
  }
}
