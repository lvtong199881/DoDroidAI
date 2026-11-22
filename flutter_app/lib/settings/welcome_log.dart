import 'package:flutter/foundation.dart';

import 'welcome_contract.dart';

/// 欢迎弹窗结构化日志接口。
///
/// 事件名与字段是 PRD 11.1 的固定契约；日志失败不得影响弹窗流程。
abstract interface class WelcomeLog {
  void check({
    required bool show,
    required WelcomeReason reason,
    required WelcomeEntry entry,
    required String locale,
  });

  void mark({required bool success, String? error});

  void shown({required WelcomeEntry entry, required String locale});

  void dismissed({
    required WelcomeDismissMethod method,
    required int visibleMs,
  });

  void error({required WelcomeErrorStage stage, required String error});
}

/// debug 构建输出到 `debugPrint`（Android 上即 logcat），release/profile 不输出。
class DebugWelcomeLog implements WelcomeLog {
  const DebugWelcomeLog();

  static const String prefix = '[welcome]';

  @override
  void check({
    required bool show,
    required WelcomeReason reason,
    required WelcomeEntry entry,
    required String locale,
  }) {
    _emit(
      'welcome_check result=${show ? 'show' : 'skip'} '
      'reason=${reason.wire} entry=${entry.wire} locale=$locale',
    );
  }

  @override
  void mark({required bool success, String? error}) {
    final suffix = success ? '' : ' error=${error ?? 'unknown'}';
    _emit('welcome_mark result=${success ? 'success' : 'fail'}$suffix');
  }

  @override
  void shown({required WelcomeEntry entry, required String locale}) {
    _emit('welcome_shown entry=${entry.wire} locale=$locale');
  }

  @override
  void dismissed({
    required WelcomeDismissMethod method,
    required int visibleMs,
  }) {
    _emit('welcome_dismissed method=${method.wire} visible_ms=$visibleMs');
  }

  @override
  void error({required WelcomeErrorStage stage, required String error}) {
    _emit('welcome_error stage=${stage.wire} error=$error');
  }

  void _emit(String line) {
    if (!kDebugMode) return;
    try {
      debugPrint('$prefix $line');
    } catch (_) {
      // 日志失败不阻塞弹窗流程
    }
  }
}

/// 把异常转成单行、可截断的错误摘要。
///
/// 格式：`runtimeType: message`，message 最多 120 字符、换行替换为空格。
/// 只接收文件 IO / presenter 异常，不接收对话、笔记、账号等自由文本。
String welcomeErrorSummary(Object error) {
  var message = error.toString().replaceAll('\r', ' ').replaceAll('\n', ' ');
  if (message.length > 120) {
    message = message.substring(0, 120);
  }
  final type = error.runtimeType.toString();
  return '$type: $message';
}
