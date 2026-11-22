import 'package:flutter_riverpod/flutter_riverpod.dart';

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
