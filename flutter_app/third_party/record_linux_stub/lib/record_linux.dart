import 'dart:typed_data';

import 'package:record_platform_interface/record_platform_interface.dart';

/// Linux 空实现：record 聚合包在 Android 构建时也会编译各平台实现，
/// 官方的 record_linux 与当前 record_platform_interface 接口不兼容，
/// 这里用最小实现绕过编译（Linux 平台不提供录音能力）。
class RecordLinux extends RecordMethodChannelPlatformInterface {
  static void registerWith() {}
  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<void> start(
    String recorderId,
    RecordConfig config, {
    required String path,
  }) async {
    throw UnsupportedError('record_linux stub: 不支持录音');
  }

  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async {
    throw UnsupportedError('record_linux stub: 不支持录音');
  }

  @override
  Future<String?> stop(String recorderId) async => null;

  @override
  Future<void> pause(String recorderId) async {}

  @override
  Future<void> resume(String recorderId) async {}

  @override
  Future<bool> isRecording(String recorderId) async => false;

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async =>
      false;

  @override
  Future<void> dispose(String recorderId) async {}

  @override
  Future<Amplitude> getAmplitude(String recorderId) async =>
      Amplitude(current: 0, max: 0);

  @override
  Future<bool> isEncoderSupported(
    String recorderId,
    AudioEncoder encoder,
  ) async =>
      false;

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async =>
      const <InputDevice>[];

  @override
  Future<void> cancel(String recorderId) async {}

  @override
  RecordIos? getIos(String recorderId) => null;
}
