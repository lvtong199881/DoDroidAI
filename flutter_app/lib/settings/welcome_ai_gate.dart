/// 欢迎弹窗「去配置AI」入口的显示判定：只看当前激活配置的三个字段。
///
/// 纯 Dart（不依赖 Flutter widget），失败一律按「未配置」处理，
/// 保证用户始终还有配置入口，且弹窗本身不受影响。
library;

import '../ai/ai_config.dart';

/// 读取当前激活配置；测试可注入，生产默认 [AiConfigStore.loadActive]。
typedef ActiveAiConfigLoader = Future<AiConfig?> Function();

/// 判定是否显示「去配置AI」按钮。
///
/// 与 [AiConfig.isConfigured] 的区别：这里按 PRD 口径对三个字段做 `trim()`，
/// 全空白字符也算未配置。
class WelcomeAiGate {
  WelcomeAiGate({ActiveAiConfigLoader? loadActive})
      : _loadActive = loadActive ?? AiConfigStore().loadActive;

  final ActiveAiConfigLoader _loadActive;

  /// 返回 `true` 表示应显示「去配置AI」。
  ///
  /// 无激活配置、三字段任一 `trim` 为空、读取抛异常 → `true`；
  /// 三字段 `trim` 后均非空 → `false`。本方法不向调用方抛异常，不联网。
  Future<bool> shouldShowConfigureAi() async {
    try {
      final config = await _loadActive();
      if (config == null) return true;
      return !config.hasCompleteFields;
    } catch (_) {
      // 存储异常 / JSON 损坏：按未配置处理，弹窗照常展示。
      return true;
    }
  }
}
