import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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

  /// 朗读：首句先播，其余句子合成后合并为一个文件，整段只有一次切换
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
    try {
      // 1) 首句，尽快出声
      final first = await _synthPiece(model, dir, temp.path, pieces[0]);
      if (first == null) return;
      debugPrint('TTS_FIRST_READY ms=${sw.elapsedMilliseconds}');

      // 2) 首句播放的同时，并行合成剩余句子
      final restFuture = Future.wait(
        pieces
            .skip(1)
            .map((p) => _synthPiece(model, dir, temp.path, p)),
      );

      debugPrint('TTS_SEG first ${_wavDurationMs(first)}ms');
      await _player.play(DeviceFileSource(first));
      final firstMs = _wavDurationMs(first);
      await Future<void>.delayed(Duration(milliseconds: firstMs));

      final rest = (await restFuture).whereType<String>().toList();
      if (rest.isEmpty) {
        debugPrint('SherpaTts: 播放结束 total_ms=${sw.elapsedMilliseconds}');
        return;
      }

      // 3) 其余句子合并成一个 wav，无缝续播
      final mergedPath = '${temp.path}/tts_merged_${DateTime.now().microsecondsSinceEpoch}.wav';
      final merged = _mergeWav(rest, mergedPath);
      if (merged == null) return;
      debugPrint('TTS_SEG merged ${_wavDurationMs(merged)}ms');
      await _player.play(DeviceFileSource(merged));
      await Future<void>.delayed(Duration(milliseconds: _wavDurationMs(merged)));
      debugPrint('SherpaTts: 播放结束 total_ms=${sw.elapsedMilliseconds}');
    } catch (e) {
      debugPrint('SherpaTts: 朗读失败 $e');
    }
  }

  /// 合并多个 16-bit 单声道 wav（要求采样率一致）
  static String? _mergeWav(List<String> paths, String outPath) {
    if (paths.isEmpty) return null;
    try {
      final firstBytes = File(paths.first).readAsBytesSync();
      if (firstBytes.length < 44) return null;
      final head = ByteData.sublistView(firstBytes);
      var offset = 12;
      var sampleRate = 44100;
      var channels = 1;
      var bits = 16;
      while (offset + 8 <= firstBytes.length) {
        final id = String.fromCharCodes(firstBytes.sublist(offset, offset + 4));
        final size = head.getUint32(offset + 4, Endian.little);
        if (id == 'fmt ') {
          channels = head.getUint16(offset + 10, Endian.little);
          sampleRate = head.getUint32(offset + 12, Endian.little);
          bits = head.getUint16(offset + 22, Endian.little);
        } else if (id == 'data') {
          break;
        }
        offset += 8 + size + (size.isOdd ? 1 : 0);
      }

      final pcm = BytesBuilder();
      for (final path in paths) {
        final bytes = File(path).readAsBytesSync();
        if (bytes.length < 44) continue;
        final data = ByteData.sublistView(bytes);
        var o = 12;
        while (o + 8 <= bytes.length) {
          final id = String.fromCharCodes(bytes.sublist(o, o + 4));
          final size = data.getUint32(o + 4, Endian.little);
          if (id == 'data') {
            final end = (o + 8 + size).clamp(0, bytes.length);
            pcm.add(bytes.sublist(o + 8, end));
            break;
          }
          o += 8 + size + (size.isOdd ? 1 : 0);
        }
      }

      final dataBytes = pcm.takeBytes();
      final header = ByteData(44);
      header.setUint32(16, 16, Endian.little); // fmt 块长度
      header.setUint16(20, 1, Endian.little); // PCM
      header.setUint16(22, channels, Endian.little);
      header.setUint32(24, sampleRate, Endian.little);
      header.setUint32(28, sampleRate * channels * bits ~/ 8, Endian.little);
      header.setUint16(32, channels * bits ~/ 8, Endian.little);
      header.setUint16(34, bits, Endian.little);
      header.setUint32(40, dataBytes.length, Endian.little);
      header.setUint32(4, 36 + dataBytes.length, Endian.little);

      final out = BytesBuilder()
        ..add('RIFF'.codeUnits)
        ..add(header.buffer.asUint8List(4, 4))
        ..add('WAVE'.codeUnits)
        ..add('fmt '.codeUnits)
        ..add(header.buffer.asUint8List(16, 4))
        ..add(header.buffer.asUint8List(20, 16))
        ..add('data'.codeUnits)
        ..add(header.buffer.asUint8List(40, 4))
        ..add(dataBytes);
      File(outPath).writeAsBytesSync(out.takeBytes(), flush: true);
      return outPath;
    } catch (e) {
      debugPrint('SherpaTts: 合并音频失败 $e');
      return null;
    }
  }

  static Future<String?> _synthPiece(
    VoiceModel model,
    String dir,
    String tempDir,
    String piece,
  ) async {
    final path = '$tempDir/tts_${DateTime.now().microsecondsSinceEpoch}.wav';
    try {
      return await SpeechWorker.synthesize(
        modelDir: dir,
        text: piece,
        outPath: path,
        kind: model.kind,
      );
    } catch (e) {
      debugPrint('SherpaTts: 合成失败 $e');
      return null;
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
