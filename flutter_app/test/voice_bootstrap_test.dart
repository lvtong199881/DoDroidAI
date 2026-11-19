import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/ai/voice_bootstrap.dart';

void main() {
  test('模型都就绪时不下载', () {
    final plan = resolveVoiceDownloadPlan(
      sttReady: true,
      ttsReady: true,
      onWifi: true,
      hasNetwork: true,
    );
    expect(plan.downloadStt, isFalse);
    expect(plan.downloadTts, isFalse);
    expect(plan.blockedReason, isNull);
  });

  test('Wi-Fi 下下载缺失项', () {
    final plan = resolveVoiceDownloadPlan(
      sttReady: false,
      ttsReady: true,
      onWifi: true,
      hasNetwork: true,
    );
    expect(plan.downloadStt, isTrue);
    expect(plan.downloadTts, isFalse);
    expect(plan.blockedReason, isNull);
  });

  test('蜂窝网络下阻塞下载', () {
    final plan = resolveVoiceDownloadPlan(
      sttReady: false,
      ttsReady: false,
      onWifi: false,
      hasNetwork: true,
    );
    expect(plan.downloadStt, isFalse);
    expect(plan.downloadTts, isFalse);
    expect(plan.blockedReason, 'cellular');
  });

  test('无网络时阻塞', () {
    final plan = resolveVoiceDownloadPlan(
      sttReady: false,
      ttsReady: false,
      onWifi: false,
      hasNetwork: false,
    );
    expect(plan.blockedReason, 'noNetwork');
  });
}
