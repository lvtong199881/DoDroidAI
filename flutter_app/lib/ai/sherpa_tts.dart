import 'dart:io';

import 'package:flutter/foundation.dart';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// 纯 Flutter 离线 TTS（sherpa-onnx MeloTTS VITS）
class SherpaTts {
  static sherpa.OfflineTts? _tts;
  static final AudioPlayer _player = AudioPlayer();
  static bool _ready = false;

  static Future<bool> init() async {
    if (_ready) return true;
    try {
      sherpa.initBindings();
      final dir = await getApplicationSupportDirectory();
      final modelDir = '${dir.path}/tts_models/vits_melo_tts_zh_en';
      if (!File('$modelDir/model.int8.onnx').existsSync()) {
        return false;
      }
      _tts = sherpa.OfflineTts(
        sherpa.OfflineTtsConfig(
          model: sherpa.OfflineTtsModelConfig(
            vits: sherpa.OfflineTtsVitsModelConfig(
              model: '$modelDir/model.int8.onnx',
              tokens: '$modelDir/tokens.txt',
              lexicon: '$modelDir/lexicon.txt',
              dictDir: '$modelDir/dict',
            ),
            numThreads: 2,
          ),
          ruleFsts: ['date.fst', 'new_heteronym.fst', 'number.fst', 'phone.fst']
              .map((f) => '$modelDir/$f')
              .join(','),
        ),
      );
      _ready = true;
      debugPrint('SherpaTts: 初始化成功 sampleRate=${_tts?.sampleRate}');
      return true;
    } catch (e) {
      debugPrint('SherpaTts: 初始化失败 $e');
      _ready = false;
      return false;
    }
  }

  static Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!await init()) return;
    final engine = _tts;
    if (engine == null) return;
    final audio = engine.generate(text: text);
    if (audio.samples.isEmpty) return;
    final temp = await getTemporaryDirectory();
    final path = '${temp.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav';
    _writeWav(path, audio.samples, audio.sampleRate);
    debugPrint('SherpaTts: 合成 ${audio.samples.length} samples @ ${audio.sampleRate}Hz');
    await _player.stop();
    await _player.play(DeviceFileSource(path));
    debugPrint('SherpaTts: 播放已开始');
  }

  static Future<void> stop() async {
    await _player.stop();
  }

  static void _writeWav(String path, Float32List samples, int sampleRate) {
    final data = ByteData(samples.length * 2);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
      data.setInt16(i * 2, v, Endian.little);
    }
    final bytes = data.buffer.asUint8List();
    final header = _waveHeader(bytes.length, sampleRate);
    final file = File(path).openSync(mode: FileMode.write);
    try {
      file.writeFromSync(header);
      file.writeFromSync(bytes);
    } finally {
      file.closeSync();
    }
  }

  static Uint8List _waveHeader(int dataLength, int sampleRate) {
    final builder = BytesBuilder();
    void str(String s) => builder.add(s.codeUnits);
    void u32(int v) {
      final d = ByteData(4)..setUint32(0, v, Endian.little);
      builder.add(d.buffer.asUint8List());
    }

    void u16(int v) {
      final d = ByteData(2)..setUint16(0, v, Endian.little);
      builder.add(d.buffer.asUint8List());
    }

    str('RIFF');
    u32(36 + dataLength);
    str('WAVE');
    str('fmt ');
    u32(16);
    u16(1);
    u16(1);
    u32(sampleRate);
    u32(sampleRate * 2);
    u16(2);
    u16(16);
    str('data');
    u32(dataLength);
    return builder.toBytes();
  }
}
