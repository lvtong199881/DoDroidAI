import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'speech_worker.dart';

/// 离线 TTS（sherpa-onnx MeloTTS）。
/// 合成在常驻 isolate 执行；长文本按句切分、边合成边播放，首句很快出声。
class SherpaTts {
  static final AudioPlayer _player = AudioPlayer();
  static Future<void>? _warming;

  static Future<String> modelDir() async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/tts_models/vits_melo_tts_zh_en';
  }

  static Future<bool> isReady() async {
    final dir = await modelDir();
    return File('$dir/model.int8.onnx').existsSync();
  }

  /// App 启动后调用：提前把模型加载进语音 isolate
  static Future<void> warmUp() async {
    if (_warming != null) return _warming!;
    _warming = () async {
      final dir = await modelDir();
      if (!File('$dir/model.int8.onnx').existsSync()) return;
      await SpeechWorker.warmUpTts(dir);
      debugPrint('SherpaTts: 预热完成');
    }();
    return _warming!;
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
        '${temp.path}/tts_${DateTime.now().microsecondsSinceEpoch}.wav';
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

  /// 朗读：按句切分，边合成边播
  static Future<void> speak(String text) async {
    final chunks = splitForSpeech(text);
    if (chunks.isEmpty) return;

    Future<String?>? pending = synthesizeToWav(chunks.first);
    for (var i = 0; i < chunks.length; i++) {
      final path = await pending;
      if (path == null) break;
      // 提前合成下一句，减少句间空档
      if (i + 1 < chunks.length) {
        pending = synthesizeToWav(chunks[i + 1]);
      } else {
        pending = null;
      }
      await _playAndWait(path);
    }
  }

  static Future<void> _playAndWait(String path) async {
    final completer = Completer<void>();
    late StreamSubscription<void> sub;
    sub = _player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
      sub.cancel();
    });
    try {
      await _player.play(DeviceFileSource(path));
      await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {},
      );
    } catch (e) {
      debugPrint('SherpaTts: 播放失败 $e');
    } finally {
      await sub.cancel();
    }
  }

  static Future<void> stop() async {
    await _player.stop();
  }

  /// 按中英文句读切分；首段控制得更短，让第一声尽快出来
  static List<String> splitForSpeech(String text, {int maxLen = 30}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return const [];

    final parts = <String>[];
    final buffer = StringBuffer();
    for (final char in normalized.split('')) {
      buffer.write(char);
      final isBreak = '。！？!?；;.\n'.contains(char);
      final isSpaceBreak = char == ' ' && buffer.length >= maxLen;
      if (isBreak || isSpaceBreak || buffer.length >= maxLen * 2) {
        final piece = buffer.toString().trim();
        if (piece.isNotEmpty) parts.add(piece);
        buffer.clear();
      }
    }
    final rest = buffer.toString().trim();
    if (rest.isNotEmpty) parts.add(rest);

    // 只合并极短片段，且合并后不超过 maxLen，避免把整段并成一句
    final merged = <String>[];
    for (final p in parts) {
      final canMerge = merged.isNotEmpty &&
          merged.last.length < 6 &&
          merged.last.length + p.length <= maxLen;
      if (canMerge) {
        merged[merged.length - 1] = '${merged.last}$p';
      } else {
        merged.add(p);
      }
    }
    return merged;
  }
}
