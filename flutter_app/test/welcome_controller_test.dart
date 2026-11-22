import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/settings/welcome_contract.dart';
import 'package:dodroidai/settings/welcome_controller.dart';
import 'package:dodroidai/settings/welcome_launch_entry.dart';
import 'package:dodroidai/settings/welcome_log.dart';

import 'support/welcome_fakes.dart';

/// 任何日志方法都抛异常：验证日志失败不影响弹窗流程。
class _ThrowingWelcomeLog implements WelcomeLog {
  @override
  void check({
    required bool show,
    required WelcomeReason reason,
    required WelcomeEntry entry,
    required String locale,
  }) {
    throw StateError('log down');
  }

  @override
  void mark({required bool success, String? error}) {
    throw StateError('log down');
  }

  @override
  void shown({required WelcomeEntry entry, required String locale}) {
    throw StateError('log down');
  }

  @override
  void dismissed({
    required WelcomeDismissMethod method,
    required int visibleMs,
  }) {
    throw StateError('log down');
  }

  @override
  void error({required WelcomeErrorStage stage, required String error}) {
    throw StateError('log down');
  }
}

void main() {
  WelcomeController build(
    FakeWelcomeFlagStore store,
    RecordingWelcomeLog log, {
    WelcomeEntry entry = WelcomeEntry.coldStart,
    LaunchEntryResolver? resolver,
  }) {
    return WelcomeController(
      store: store,
      log: log,
      entryResolver: resolver ?? fixedEntryResolver(entry),
    );
  }

  test('已展示：跳过且不写标记、不展示', () async {
    final store = FakeWelcomeFlagStore(flagged: true);
    final log = RecordingWelcomeLog();
    var presented = 0;

    await build(store, log).runOnce(
      locale: 'zh',
      presenter: (_) async {
        presented++;
        return const WelcomeDismissResult(
          method: WelcomeDismissMethod.button,
          visibleMs: 1,
        );
      },
    );

    expect(presented, 0);
    expect(store.writeCount, 0);
    expect(log.events, ['check:skip:flagged:cold_start:zh']);
  });

  test('未展示：先写标记后展示，并输出四类正常日志', () async {
    final store = FakeWelcomeFlagStore();
    final log = RecordingWelcomeLog();
    var writesBeforePresent = -1;

    await build(store, log).runOnce(
      locale: 'zh',
      presenter: (onShown) async {
        writesBeforePresent = store.writeCount;
        onShown();
        return const WelcomeDismissResult(
          method: WelcomeDismissMethod.button,
          visibleMs: 123,
        );
      },
    );

    expect(writesBeforePresent, 1);
    expect(store.flagged, isTrue);
    expect(log.events, [
      'check:show:no_flag:cold_start:zh',
      'mark:success',
      'shown:cold_start:zh',
      'dismissed:button:123',
    ]);
  });

  test('读失败：记 welcome_error(read)，按未展示继续展示', () async {
    final store = FakeWelcomeFlagStore(
      readError: const FileSystemException('标记文件损坏'),
    );
    final log = RecordingWelcomeLog();
    var presented = 0;

    await build(store, log).runOnce(
      locale: 'en',
      presenter: (onShown) async {
        presented++;
        onShown();
        return const WelcomeDismissResult(
          method: WelcomeDismissMethod.back,
          visibleMs: 10,
        );
      },
    );

    expect(presented, 1);
    expect(log.events.first, startsWith('error:read:FileSystemException'));
    expect(log.events[1], 'check:show:read_failed:cold_start:en');
    expect(log.events[2], 'mark:success');
    expect(log.events[3], 'shown:cold_start:en');
    expect(log.events[4], 'dismissed:back:10');
  });

  test('写失败：记录 mark fail 与 welcome_error(write)，仍展示', () async {
    final store = FakeWelcomeFlagStore(
      writeError: const FileSystemException('磁盘已满'),
    );
    final log = RecordingWelcomeLog();
    var presented = 0;

    await build(store, log).runOnce(
      locale: 'zh',
      presenter: (onShown) async {
        presented++;
        onShown();
        return const WelcomeDismissResult(
          method: WelcomeDismissMethod.button,
          visibleMs: 5,
        );
      },
    );

    expect(presented, 1);
    expect(log.events[0], 'check:show:no_flag:cold_start:zh');
    expect(log.events[1], startsWith('mark:fail:FileSystemException'));
    expect(log.events[2], startsWith('error:write:FileSystemException'));
    expect(log.events[3], 'shown:cold_start:zh');
    expect(log.events[4], 'dismissed:button:5');
  });

  test('展示异常：记 welcome_error(render) 且不向调用方抛', () async {
    final store = FakeWelcomeFlagStore();
    final log = RecordingWelcomeLog();

    await expectLater(
      build(store, log).runOnce(
        locale: 'zh',
        presenter: (_) async => throw StateError('dialog failed'),
      ),
      completes,
    );

    expect(log.events.last, startsWith('error:render:StateError'));
    expect(log.events.any((event) => event.startsWith('dismissed')), isFalse);
    expect(log.events.any((event) => event.startsWith('shown')), isFalse);
  });

  test('onShown 重复调用只记一次 welcome_shown', () async {
    final store = FakeWelcomeFlagStore();
    final log = RecordingWelcomeLog();

    await build(store, log).runOnce(
      locale: 'zh',
      presenter: (onShown) async {
        onShown();
        onShown();
        return const WelcomeDismissResult(
          method: WelcomeDismissMethod.button,
          visibleMs: 1,
        );
      },
    );

    expect(
      log.events.where((event) => event.startsWith('shown')).length,
      1,
    );
  });

  test('并发调用复用同一个 Future，只读写/展示一次', () async {
    final store = FakeWelcomeFlagStore();
    final log = RecordingWelcomeLog();
    var presented = 0;

    Future<WelcomeDismissResult> presenter(void Function() onShown) async {
      presented++;
      onShown();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return const WelcomeDismissResult(
        method: WelcomeDismissMethod.button,
        visibleMs: 7,
      );
    }

    final controller = build(store, log);
    final first = controller.runOnce(locale: 'zh', presenter: presenter);
    final second = controller.runOnce(locale: 'zh', presenter: presenter);

    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);

    expect(presented, 1);
    expect(store.readCount, 1);
    expect(store.writeCount, 1);
    expect(
      log.events.where((event) => event.startsWith('shown')).length,
      1,
    );
  });

  test('完成后再次调用不再读标记/展示', () async {
    final store = FakeWelcomeFlagStore();
    final log = RecordingWelcomeLog();
    var presented = 0;
    Future<WelcomeDismissResult> presenter(void Function() onShown) async {
      presented++;
      onShown();
      return const WelcomeDismissResult(
        method: WelcomeDismissMethod.button,
        visibleMs: 1,
      );
    }

    final controller = build(store, log);
    await controller.runOnce(locale: 'zh', presenter: presenter);
    await controller.runOnce(locale: 'zh', presenter: presenter);

    expect(presented, 1);
    expect(store.readCount, 1);
    expect(store.writeCount, 1);
  });

  test('入口识别结果写入 check/shown 日志', () async {
    final store = FakeWelcomeFlagStore();
    final log = RecordingWelcomeLog();

    await build(store, log, entry: WelcomeEntry.widget).runOnce(
      locale: 'en',
      presenter: (onShown) async {
        onShown();
        return const WelcomeDismissResult(
          method: WelcomeDismissMethod.button,
          visibleMs: 1,
        );
      },
    );

    expect(log.events[0], 'check:show:no_flag:widget:en');
    expect(log.events[2], 'shown:widget:en');
  });

  test('日志实现抛异常也不影响展示与关闭', () async {
    final store = FakeWelcomeFlagStore();
    var presented = 0;

    final controller = WelcomeController(
      store: store,
      log: _ThrowingWelcomeLog(),
      entryResolver: fixedEntryResolver(WelcomeEntry.coldStart),
    );

    await controller.runOnce(
      locale: 'zh',
      presenter: (onShown) async {
        presented++;
        onShown();
        return const WelcomeDismissResult(
          method: WelcomeDismissMethod.back,
          visibleMs: 2,
        );
      },
    );

    expect(presented, 1);
    expect(store.writeCount, 1);
  });
}
