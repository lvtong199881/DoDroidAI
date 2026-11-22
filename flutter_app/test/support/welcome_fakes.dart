import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dodroidai/settings/welcome_contract.dart';
import 'package:dodroidai/settings/welcome_controller.dart';
import 'package:dodroidai/settings/welcome_flag_store.dart';
import 'package:dodroidai/settings/welcome_launch_entry.dart';
import 'package:dodroidai/settings/welcome_log.dart';
import 'package:dodroidai/settings/welcome_providers.dart';

/// 记录事件顺序的日志实现，事件串形如 `check:show:no_flag:cold_start:zh`。
class RecordingWelcomeLog implements WelcomeLog {
  final List<String> events = [];

  @override
  void check({
    required bool show,
    required WelcomeReason reason,
    required WelcomeEntry entry,
    required String locale,
  }) {
    events.add(
      'check:${show ? 'show' : 'skip'}:${reason.wire}:${entry.wire}:$locale',
    );
  }

  @override
  void mark({required bool success, String? error}) {
    events.add(success ? 'mark:success' : 'mark:fail:$error');
  }

  @override
  void shown({required WelcomeEntry entry, required String locale}) {
    events.add('shown:${entry.wire}:$locale');
  }

  @override
  void dismissed({
    required WelcomeDismissMethod method,
    required int visibleMs,
  }) {
    events.add('dismissed:${method.wire}:$visibleMs');
  }

  @override
  void error({required WelcomeErrorStage stage, required String error}) {
    events.add('error:${stage.wire}:$error');
  }
}

/// 可控的标记存储：可注入读写异常，并记录调用次数。
class FakeWelcomeFlagStore implements WelcomeFlagStore {
  FakeWelcomeFlagStore({this.flagged = false, this.readError, this.writeError});

  bool flagged;
  Object? readError;
  Object? writeError;
  int readCount = 0;
  int writeCount = 0;

  @override
  Future<bool> read() async {
    readCount++;
    final error = readError;
    if (error != null) throw error;
    return flagged;
  }

  @override
  Future<void> write() async {
    writeCount++;
    final error = writeError;
    if (error != null) throw error;
    flagged = true;
  }
}

/// 已展示过的标记（既有用例用来跳过欢迎弹窗）。
class ShownWelcomeFlagStore implements WelcomeFlagStore {
  const ShownWelcomeFlagStore();

  @override
  Future<bool> read() async => true;

  @override
  Future<void> write() async {}
}

/// 静默日志，避免既有测试输出 welcome 日志。
class NoopWelcomeLog implements WelcomeLog {
  const NoopWelcomeLog();

  @override
  void check({
    required bool show,
    required WelcomeReason reason,
    required WelcomeEntry entry,
    required String locale,
  }) {}

  @override
  void mark({required bool success, String? error}) {}

  @override
  void shown({required WelcomeEntry entry, required String locale}) {}

  @override
  void dismissed({
    required WelcomeDismissMethod method,
    required int visibleMs,
  }) {}

  @override
  void error({required WelcomeErrorStage stage, required String error}) {}
}

/// 固定入口的探针组合，单测不碰真实插件。
LaunchEntryResolver fixedEntryResolver(WelcomeEntry entry) {
  switch (entry) {
    case WelcomeEntry.coldStart:
      return LaunchEntryResolver(
        widgetProbe: () async => null,
        notificationProbe: () async => false,
      );
    case WelcomeEntry.widget:
      return LaunchEntryResolver(
        widgetProbe: () async => Uri.parse('dodroidai://widget'),
        notificationProbe: () async => false,
      );
    case WelcomeEntry.notification:
      return LaunchEntryResolver(
        widgetProbe: () async => null,
        notificationProbe: () async => true,
      );
    case WelcomeEntry.shortcut:
      return LaunchEntryResolver(
        widgetProbe: () async => null,
        notificationProbe: () async => false,
      );
    case WelcomeEntry.other:
      return LaunchEntryResolver(
        widgetProbe: () async => null,
        notificationProbe: () async => throw StateError('probe failed'),
      );
  }
}

/// 既有测试用：把欢迎控制器替换为「已展示、不会再弹」的实现。
Override welcomeAlreadyShownOverride() {
  return welcomeControllerProvider.overrideWithValue(
    WelcomeController(
      store: const ShownWelcomeFlagStore(),
      log: const NoopWelcomeLog(),
      entryResolver: fixedEntryResolver(WelcomeEntry.coldStart),
    ),
  );
}
