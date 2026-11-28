import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_version.dart';
import 'welcome_ai_gate.dart';
import 'welcome_controller.dart';
import 'welcome_flag_store.dart';
import 'welcome_launch_entry.dart';
import 'welcome_log.dart';

/// 应用级单例：`ProviderScope` 生命周期内只创建一次。
///
/// 单测/集成测试用 `overrideWithValue` 换成 fake store/探针。
final welcomeControllerProvider = Provider<WelcomeController>((ref) {
  return WelcomeController(
    store: FileWelcomeFlagStore(),
    log: const DebugWelcomeLog(),
    entryResolver: LaunchEntryResolver(),
  );
});

/// 「去配置AI」入口判定：读激活 AI 配置，测试用 `overrideWithValue` 注入。
final welcomeAiGateProvider = Provider<WelcomeAiGate>((ref) {
  return WelcomeAiGate();
});

/// 应用版本读取器：欢迎弹窗展示前解析版本号，测试用 `overrideWithValue`
/// 注入 fake loader。
///
/// 不缓存结果、不持有 BuildContext；每次启动最多调用一次。
final appVersionProvider = Provider<AppVersionResolver>(
  (ref) => const AppVersionResolver(),
);

