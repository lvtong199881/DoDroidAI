import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'model_catalog.dart';
import 'model_manager.dart';
import 'speech_worker.dart';

/// 离线 TTS（sherpa-onnx MeloTTS）。
/// 合成在常驻 isolate 执行；长文本按句切分、边合成边播放，首句很快出声。
class SherpaTts {
  static final AudioPlayer _player = AudioPlayer();
  static ConcatenatingAudioSource? _playlist;
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

  /// 朗读：逐句流式合成，边生成边播，播放队列无缝衔接
  static Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!await isReady()) {
      debugPrint('SherpaTts: 模型未下载');
      return;
    }
    final model = await activeModel();
    final dir = await ModelManager('tts').modelDir(model);
    final temp = await getTemporaryDirectory();

    final playlist = ConcatenatingAudioSource(children: []);
    _playlist = playlist;
    var added = 0;
    var started = false;
    var firstChunkAt = -1;
    final sw = Stopwatch()..start();

    try {
      await _player.setAudioSource(playlist);
      for (final piece in splitForSpeech(text)) {
        await SpeechWorker.synthesizeStream(
          modelDir: dir,
          text: piece,
          tempDir: temp.path,
          kind: model.kind,
          onChunk: (path) {
            if (firstChunkAt < 0) {
              firstChunkAt = sw.elapsedMilliseconds;
              debugPrint('TTS_STREAM first_chunk_ms=$firstChunkAt');
            }
            added++;
            // 播放中追加，实现无缝续播
            unawaited(playlist.add(AudioSource.file(path)));
            if (!started) {
              started = true;
              unawaited(_player.play());
            }
          },
        );
      }
      // 等待队列播完
      if (added > 0) {
        await _player.processingStateStream
            .firstWhere((state) => state == ProcessingState.completed)
            .timeout(const Duration(seconds: 120), onTimeout: () {
          return ProcessingState.completed;
        });
      }
    } catch (e) {
      debugPrint('SherpaTts: 流式合成失败 $e');
    } finally {
      _playlist = null;
      try {
        await _player.stop();
      } catch (_) {}
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
