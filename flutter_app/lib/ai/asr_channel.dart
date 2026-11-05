import 'package:flutter/services.dart';

/// 桥接原生 sherpa-onnx SenseVoice ASR（dodroidai/asr）
class AsrChannel {
  static const MethodChannel _channel = MethodChannel('dodroidai/asr');

  static Future<bool> init() async {
    try {
      return await _channel.invokeMethod<bool>('init') ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> start() async {
    try {
      return await _channel.invokeMethod<bool>('start') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// 停止录音并返回识别文本
  static Future<String?> stop() async {
    try {
      return await _channel.invokeMethod<String>('stop');
    } on PlatformException {
      return null;
    }
  }
}
