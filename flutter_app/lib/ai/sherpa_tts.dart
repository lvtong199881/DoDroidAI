import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'model_catalog.dart';
import 'model_manager.dart';
import 'speech_worker.dart';

/// 离线 TTS（sherpa-onnx MeloTTS）。
/// 合成在常驻 isolate 执行；长文本按句切分、边合成边播放，首句很快出声。
class SherpaTts {
  static final AudioPlayer _player = AudioPlayer();
  static Future<void>? _warming;

  /// 当前激活的 TTS 模型（默认 Matcha）
  static Future<VoiceModel> activeModel() async {
    final id = await ModelManager('tts').activeModelId();
    return TtsModels.byId(id);
  }

  static Future<String> modelDir() async {
    final model = await activeModel();
    return ModelManager('tts').modelDir(model);
  }

  static Future<bool> isReady() async {
    final model = await activeModel();
    final dir = await ModelManager('tts').modelDir(model);
    if (model.kind == 'matcha') {
      return File('$dir/model-steps-3.onnx').existsSync() &&
          File('$dir/vocos-16khz-univ.onnx').existsSync();
    }
    return File('$dir/model.int8.onnx').existsSync();
  }

  /// App 启动后调用：提前把模型加载进语音 isolate
  static Future<void> warmUp() async {
    if (_warming != null) return _warming!;
    _warming = () async {
      final model = await activeModel();
      final dir = await ModelManager('tts').modelDir(model);
      if (!await isReady()) return;
      await SpeechWorker.warmUpTts(dir, kind: model.kind);
      debugPrint('SherpaTts: 预热完成 engine=${model.kind}');
    }();
    return _warming!;
  }

  /// 仅合成到 wav（不播放），失败返回 null
  static Future<String?> synthesizeToWav(String text) async {
    if (text.trim().isEmpty) return null;
    final model = await activeModel();
    final dir = await ModelManager('tts').modelDir(model);
    if (!await isReady()) {
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
        kind: model.kind,
      );
    } catch (e) {
      debugPrint('SherpaTts: 合成失败 $e');
      return null;
    }
  }

  /// 朗读：逐句合成 + 预取下一句 + 顺序播放
  static Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!await isReady()) {
      debugPrint('SherpaTts: 模型未下载');
      return;
    }
    final model = await activeModel();
    final dir = await ModelManager('tts').modelDir(model);
    final temp = await getTemporaryDirectory();
    final pieces = splitForSpeech(text);
    if (pieces.isEmpty) return;

    final sw = Stopwatch()..start();
    var index = 0;
    Future<String?>? pending = _synthPiece(model, dir, temp.path, pieces[index]);

    while (true) {
      final path = await pending;
      if (path == null) break;
      if (index == 0) debugPrint('TTS_FIRST_READY ms=${sw.elapsedMilliseconds}');
      // 先启动下一句合成，再播放当前句
      index++;
      if (index < pieces.length) {
        pending = _synthPiece(model, dir, temp.path, pieces[index]);
      } else {
        pending = null;
      }
      await _playAndWait(path);
      if (pending == null) break;
    }
    debugPrint('SherpaTts: 播放结束 total_ms=${sw.elapsedMilliseconds}');
  }

  static Future<String?> _synthPiece(
    VoiceModel model,
    String dir,
    String tempDir,
    String piece,
  ) {
    final path =
        '$tempDir/tts_${DateTime.now().microsecondsSinceEpoch}.wav';
    return SpeechWorker.synthesize(
      modelDir: dir,
      text: piece,
      outPath: path,
      kind: model.kind,
    ).catchError((Object e) {
      debugPrint('SherpaTts: 合成失败 $e');
      return null;
    });
  }

  static Future<void> _playAndWait(String path) async {
    try {
      await _player.play(DeviceFileSource(path));
      // audioplayers 的 onPlayerComplete 在部分版本不稳定，这里按音频实际时长等待
      final ms = _wavDurationMs(path);
      await Future<void>.delayed(Duration(milliseconds: ms + 80));
    } catch (e) {
      debugPrint('SherpaTts: 播放失败 $e');
    }
  }

  /// 读取 16-bit 单声道 wav 的时长
  static int _wavDurationMs(String path) {
    try {
      final bytes = File(path).readAsBytesSync();
      if (bytes.length < 44) return 500;
      final data = ByteData.sublistView(bytes);
      var offset = 12;
      var sampleRate = 44100;
      var channels = 1;
      var bits = 16;
      var dataBytes = bytes.length - 44;
      while (offset + 8 <= bytes.length) {
        final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final size = data.getUint32(offset + 4, Endian.little);
        if (id == 'fmt ') {
          channels = data.getUint16(offset + 10, Endian.little);
          sampleRate = data.getUint32(offset + 12, Endian.little);
          bits = data.getUint16(offset + 22, Endian.little);
        } else if (id == 'data') {
          dataBytes = size;
          break;
        }
        offset += 8 + size + (size.isOdd ? 1 : 0);
      }
      final bytesPerSample = (bits ~/ 8) * channels;
      if (sampleRate <= 0 || bytesPerSample <= 0) return 500;
      return (dataBytes / (sampleRate * bytesPerSample) * 1000).round();
    } catch (_) {
      return 500;
    }
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
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
