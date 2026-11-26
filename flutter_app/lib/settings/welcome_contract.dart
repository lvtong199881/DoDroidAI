/// 欢迎弹窗的稳定枚举与结果类型。
///
/// 本文件是纯 Dart（不依赖 Flutter），枚举的 [wire] 取值是 `welcome_*` 日志
/// 与测试共用的契约，改动属于破坏性变更。
library;

/// 启动入口。
enum WelcomeEntry {
  coldStart,
  widget,
  notification,
  shortcut,
  other;

  /// 日志字段 `entry` 的固定取值。
  String get wire => switch (this) {
        WelcomeEntry.coldStart => 'cold_start',
        WelcomeEntry.widget => 'widget',
        WelcomeEntry.notification => 'notification',
        WelcomeEntry.shortcut => 'shortcut',
        WelcomeEntry.other => 'other',
      };
}

/// 本次检查得出「展示 / 跳过」的原因。
enum WelcomeReason {
  noFlag,
  flagged,
  readFailed;

  /// 日志字段 `reason` 的固定取值。
  String get wire => switch (this) {
        WelcomeReason.noFlag => 'no_flag',
        WelcomeReason.flagged => 'flagged',
        WelcomeReason.readFailed => 'read_failed',
      };
}

/// `welcome_error` 的阶段。
enum WelcomeErrorStage {
  read,
  write,
  render;

  /// 日志字段 `stage` 的固定取值。
  String get wire => switch (this) {
        WelcomeErrorStage.read => 'read',
        WelcomeErrorStage.write => 'write',
        WelcomeErrorStage.render => 'render',
      };
}

/// 用户关闭欢迎弹窗的方式。系统返回键关闭时没有返回值，由宿主记为 [back]。
enum WelcomeDismissMethod {
  button,
  back,
  configureAi,
  closeButton;

  /// 日志字段 `method` 的固定取值。
  String get wire => switch (this) {
        WelcomeDismissMethod.button => 'button',
        WelcomeDismissMethod.back => 'back',
        WelcomeDismissMethod.configureAi => 'configure_ai',
        WelcomeDismissMethod.closeButton => 'close_button',
      };
}

/// 弹窗关闭结果：关闭方式 + 弹窗可见时长。
class WelcomeDismissResult {
  const WelcomeDismissResult({
    required this.method,
    required this.visibleMs,
  });

  final WelcomeDismissMethod method;
  final int visibleMs;
}
