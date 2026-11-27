import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/ai/voice_bootstrap.dart';

void main() {
  test('模型都就绪时不下载', () {
    final plan = resolveVoiceDownloadPlan(
      sttReady: true,
      ttsReady: true,
      hasNetwork: true,
    );
    expect(plan.downloadStt, isFalse);
    expect(plan.downloadTts, isFalse);
    expect(plan.blockedReason, isNull);
  });

  test('有网络时下载缺失项', () {
    final plan = resolveVoiceDownloadPlan(
      sttReady: false,
      ttsReady: true,
      hasNetwork: true,
    );
    expect(plan.downloadStt, isTrue);
    expect(plan.downloadTts, isFalse);
    expect(plan.blockedReason, isNull);
  });

  test('非 Wi-Fi（蜂窝）网络同样下载，不再因移动网络阻塞', () {
    // 该判定的入参只反映「有没有网络」，不再区分 Wi-Fi / 蜂窝：
    // 只要 hasNetwork 为 true 就必须放行下载。
    final plan = resolveVoiceDownloadPlan(
      sttReady: false,
      ttsReady: false,
      hasNetwork: true,
    );
    expect(plan.downloadStt, isTrue);
    expect(plan.downloadTts, isTrue);
    expect(plan.blockedReason, isNull);
  });

  test('无网络时阻塞', () {
    final plan = resolveVoiceDownloadPlan(
      sttReady: false,
      ttsReady: false,
      hasNetwork: false,
    );
    expect(plan.downloadStt, isFalse);
    expect(plan.downloadTts, isFalse);
    expect(plan.blockedReason, 'noNetwork');
  });
}
