import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'speech_worker.dart';

/// 离线 TTS（sherpa-onnx MeloTTS）。
/// 合成在常驻 isolate 中执行，避免阻塞 UI。
class SherpaTts {
  static final AudioPlayer _player = AudioPlayer();

  static Future<String> modelDir() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/tts_models/vits_melo_tts_zh_en';
  }

  static Future<bool> isReady() async {
    final dir = await modelDir();
    return File('$dir/model.int8.onnx').existsSync();
  }

  /// 仅合成到 wav（不播放），失败返回 null
  static Future<String?> synthesizeToWav(String text) async {
    if (text.trim().isEmpty) return null;
    final dir = await modelDir();
    if (!File('$dir/model.int8.onnx').existsSync()) {
      debugPrint('SherpaTts: 模型未下载 $dir');
      return null;
    }
    final temp = await getTemporaryDirectory();
    final path =
        '${temp.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav';
    try {
      return await SpeechWorker.synthesize(
        modelDir: dir,
        text: text,
        outPath: path,
      );
    } catch (e) {
      debugPrint('SherpaTts: 合成失败 $e');
      return null;
    }
  }

  static Future<void> speak(String text) async {
    final path = await synthesizeToWav(text);
    if (path == null) return;
    try {
      await _player.stop();
      await _player.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('SherpaTts: 播放失败 $e');
    }
  }

  static Future<void> stop() async {
    await _player.stop();
  }
}
