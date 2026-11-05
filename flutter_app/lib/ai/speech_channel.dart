import 'package:flutter/services.dart';

/// 桥接原生 sherpa-onnx TTS（dodroidai/speech）
class SpeechChannel {
  static const MethodChannel _channel = MethodChannel('dodroidai/speech');

  static bool _initialized = false;

  static Future<int?> initTts() async {
    try {
      final rate = await _channel.invokeMethod<int>('init');
      _initialized = rate != null;
      return rate;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    if (!_initialized) {
      await initTts();
    }
    try {
      await _channel.invokeMethod('speak', {'text': text});
    } on PlatformException {
      // 忽略播放错误
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } on PlatformException {
      // ignore
    }
  }
}
