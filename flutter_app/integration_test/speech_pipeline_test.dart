import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dodroidai/ai/sherpa_asr.dart';
import 'package:dodroidai/ai/sherpa_tts.dart';

/// 离线语音链路自检：TTS 合成一句 → 喂给 ASR 识别 → 断言识别文本
/// 前置条件：设备上已放置 stt_models/sense_voice_2025_09_09 与 tts_models/vits_melo_tts_zh_en
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TTS 能合成音频（音频数据非空）', (tester) async {
    final path = await SherpaTts.synthesizeToWav('你好，这是一个语音合成测试。');
    if (path == null) {
      // flutter test 会重装应用并清空 files 目录，模型不在时明确跳过
      markTestSkipped('未找到 tts_models，请先把模型放入应用 files/tts_models/vits_melo_tts_zh_en');
      return;
    }
    final file = File(path);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(10000), reason: '生成的音频太小');
  });

  testWidgets('ASR 能识别 TTS 合成的语音', (tester) async {
    final path = await SherpaTts.synthesizeToWav('今天天气怎么样');
    if (path == null) {
      markTestSkipped('未找到 tts_models，跳过 ASR 链路用例');
      return;
    }

    final samples = _readWav(File(path));
    expect(samples.length, greaterThan(8000), reason: '音频样本太少');

    final text = await SherpaAsr.transcribe(samples);
    // 允许识别偏差，但必须出现关键字符之一
    expect(
      text.contains('天气') || text.contains('今天') || text.contains('怎么样'),
      isTrue,
      reason: 'ASR 识别结果异常：$text',
    );
  });
}

/// 解析 16-bit PCM wav → Float32List
Float32List _readWav(File file) {
  final bytes = file.readAsBytesSync();
  // 找 data chunk
  var offset = 12;
  var dataStart = 44;
  var dataLength = bytes.length - 44;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = ByteData.sublistView(bytes, offset + 4, offset + 8)
        .getUint32(0, Endian.little);
    if (id == 'data') {
      dataStart = offset + 8;
      dataLength = size;
      break;
    }
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  final end = (dataStart + dataLength).clamp(0, bytes.length);
  final pcm = bytes.sublist(dataStart, end);
  final count = pcm.length ~/ 2;
  final result = Float32List(count);
  for (var i = 0; i < count; i++) {
    final v = ByteData.sublistView(pcm, i * 2, i * 2 + 2).getInt16(0, Endian.little);
    result[i] = v / 32768.0;
  }
  return result;
}
