import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// 常驻语音 isolate：TTS 合成与 ASR 识别都在这里跑，
/// 避免 sherpa 的同步 FFI 调用阻塞 UI（表现为点朗读后界面卡死）。
class SpeechWorker {
  static Isolate? _isolate;
  static SendPort? _commandPort;
  static ReceivePort? _replyPort;
  static final Map<int, Completer<Object?>> _pending = {};
  static Completer<void>? _starting;
  static int _seq = 0;

  static Future<void> _ensureStarted() async {
    if (_commandPort != null) return;
    if (_starting != null) return _starting!.future;
    final completer = Completer<void>();
    _starting = completer;

    _replyPort = ReceivePort();
    _replyPort!.listen((message) {
      if (message is SendPort) {
        _commandPort = message;
        if (!completer.isCompleted) completer.complete();
        _starting = null;
        return;
      }
      if (message is Map && message['id'] is int) {
        final id = message['id'] as int;
        final pending = _pending.remove(id);
        if (pending == null) return;
        if (message['error'] != null) {
          pending.completeError(message['error'].toString());
        } else {
          pending.complete(message['result']);
        }
      }
    });

    _isolate = await Isolate.spawn(_workerEntry, _replyPort!.sendPort);
    await completer.future;
  }

  static Future<Object?> _call(String type, Map<String, Object?> args) async {
    await _ensureStarted();
    final id = _seq++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _commandPort!.send({'id': id, 'type': type, 'args': args});
    try {
      return await completer.future.timeout(const Duration(seconds: 90));
    } finally {
      _pending.remove(id);
    }
  }

  /// 合成 wav 到 outPath，返回 outPath
  static Future<String> synthesize({
    required String modelDir,
    required String text,
    required String outPath,
  }) async {
    final result = await _call('tts', {
      'modelDir': modelDir,
      'text': text,
      'outPath': outPath,
    });
    return result as String;
  }

  /// 预加载 TTS 模型，避免首次朗读等待
  static Future<void> warmUpTts(String modelDir) async {
    try {
      await _call('tts-warmup', {'modelDir': modelDir});
    } catch (e) {
      // 预热失败不影响使用
    }
  }

  /// 识别 16k 单声道 PCM
  static Future<String> transcribe({
    required String modelDir,
    required List<double> samples,
  }) async {
    final result = await _call('asr', {
      'modelDir': modelDir,
      'samples': samples,
    });
    return (result as String?) ?? '';
  }

  static void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commandPort = null;
    _replyPort?.close();
    _replyPort = null;
    _starting = null;
  }
}

void _workerEntry(SendPort mainPort) async {
  final receivePort = ReceivePort();
  mainPort.send(receivePort.sendPort);

  sherpa.OfflineTts? tts;
  sherpa.OfflineRecognizer? recognizer;
  String? ttsDir;
  String? asrDir;

  sherpa.initBindings();

  await for (final dynamic raw in receivePort) {
    if (raw is! Map) continue;
    final id = raw['id'] as int?;
    final type = raw['type'] as String?;
    final args = (raw['args'] as Map?)?.cast<String, Object?>() ?? {};
    try {
      switch (type) {
        case 'tts':
          final modelDir = args['modelDir'] as String;
          final text = args['text'] as String;
          final outPath = args['outPath'] as String;
          if (tts == null || ttsDir != modelDir) {
            tts = sherpa.OfflineTts(
              sherpa.OfflineTtsConfig(
                model: sherpa.OfflineTtsModelConfig(
                  vits: sherpa.OfflineTtsVitsModelConfig(
                    model: '$modelDir/model.int8.onnx',
                    tokens: '$modelDir/tokens.txt',
                    lexicon: '$modelDir/lexicon.txt',
                    dictDir: '$modelDir/dict',
                  ),
                  numThreads: 4,
                ),
                ruleFsts:
                    ['date.fst', 'new_heteronym.fst', 'number.fst', 'phone.fst']
                        .map((f) => '$modelDir/$f')
                        .join(','),
              ),
            );
            ttsDir = modelDir;
          }
          final audio = tts.generate(text: text);
          _writeWav(outPath, audio.samples, audio.sampleRate);
          mainPort.send({'id': id, 'result': outPath});
          break;

        case 'tts-warmup':
          final modelDir = args['modelDir'] as String;
          if (tts == null || ttsDir != modelDir) {
            tts = sherpa.OfflineTts(
              sherpa.OfflineTtsConfig(
                model: sherpa.OfflineTtsModelConfig(
                  vits: sherpa.OfflineTtsVitsModelConfig(
                    model: '$modelDir/model.int8.onnx',
                    tokens: '$modelDir/tokens.txt',
                    lexicon: '$modelDir/lexicon.txt',
                    dictDir: '$modelDir/dict',
                  ),
                  numThreads: 4,
                ),
                ruleFsts:
                    ['date.fst', 'new_heteronym.fst', 'number.fst', 'phone.fst']
                        .map((f) => '$modelDir/$f')
                        .join(','),
              ),
            );
            ttsDir = modelDir;
          }
          mainPort.send({'id': id, 'result': true});
          break;

        case 'asr':
          final modelDir = args['modelDir'] as String;
          final samples = (args['samples'] as List).cast<double>();
          if (recognizer == null || asrDir != modelDir) {
            recognizer = sherpa.OfflineRecognizer(
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
                  numThreads: 4,
                ),
              ),
            );
            asrDir = modelDir;
          }
          final stream = recognizer.createStream();
          stream.acceptWaveform(
            samples: Float32List.fromList(samples),
            sampleRate: 16000,
          );
          recognizer.decode(stream);
          final text = recognizer.getResult(stream).text.trim();
          stream.free();
          mainPort.send({'id': id, 'result': text});
          break;

        default:
          mainPort.send({'id': id, 'error': 'unknown type $type'});
      }
    } catch (e) {
      mainPort.send({'id': id, 'error': e.toString()});
    }
  }
}

void _writeWav(String path, Float32List samples, int sampleRate) {
  final builder = BytesBuilder();
  final dataLength = samples.length * 2;
  void str(String s) => builder.add(s.codeUnits);
  void u32(int v) => builder.add(
        Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little),
      );
  void u16(int v) => builder.add(
        Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little),
      );

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
  final pcm = Int16List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    pcm[i] = v;
  }
  builder.add(pcm.buffer.asUint8List());

  File(path).writeAsBytesSync(builder.takeBytes(), flush: true);
}
