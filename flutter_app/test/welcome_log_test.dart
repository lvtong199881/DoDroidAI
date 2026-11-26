import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/settings/welcome_contract.dart';
import 'package:dodroidai/settings/welcome_log.dart';

void main() {
  final lines = <String>[];
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    lines.clear();
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
  });

  test('welcome_check 展示：字段与顺序固定', () {
    const DebugWelcomeLog().check(
      show: true,
      reason: WelcomeReason.noFlag,
      entry: WelcomeEntry.coldStart,
      locale: 'zh',
    );

    expect(lines, [
      '[welcome] welcome_check result=show reason=no_flag '
          'entry=cold_start locale=zh',
    ]);
  });

  test('welcome_check 跳过：flagged', () {
    const DebugWelcomeLog().check(
      show: false,
      reason: WelcomeReason.flagged,
      entry: WelcomeEntry.widget,
      locale: 'en',
    );

    expect(lines, [
      '[welcome] welcome_check result=skip reason=flagged '
          'entry=widget locale=en',
    ]);
  });

  test('welcome_check 读失败原因', () {
    const DebugWelcomeLog().check(
      show: true,
      reason: WelcomeReason.readFailed,
      entry: WelcomeEntry.notification,
      locale: 'zh',
    );

    expect(lines.single, contains('reason=read_failed'));
  });

  test('welcome_mark 成功不输出 error 字段', () {
    const DebugWelcomeLog().mark(success: true);
    expect(lines, ['[welcome] welcome_mark result=success']);
  });

  test('welcome_mark 失败带 error 摘要', () {
    const DebugWelcomeLog().mark(success: false, error: 'FileSystemException: x');
    expect(lines, ['[welcome] welcome_mark result=fail error=FileSystemException: x']);
  });

  test('welcome_shown 字段', () {
    const DebugWelcomeLog().shown(entry: WelcomeEntry.other, locale: 'en');
    expect(lines, ['[welcome] welcome_shown entry=other locale=en']);
  });

  test('welcome_dismissed 字段', () {
    const DebugWelcomeLog().dismissed(
      method: WelcomeDismissMethod.back,
      visibleMs: 1234,
    );
    expect(lines, ['[welcome] welcome_dismissed method=back visible_ms=1234']);
  });

  test('welcome_dismissed 去配置AI：method=configure_ai', () {
    const DebugWelcomeLog().dismissed(
      method: WelcomeDismissMethod.configureAi,
      visibleMs: 88,
    );
    expect(
      lines,
      ['[welcome] welcome_dismissed method=configure_ai visible_ms=88'],
    );
  });

  test('welcome_dismissed 角标关闭：method=close_button 精确行', () {
    const DebugWelcomeLog().dismissed(
      method: WelcomeDismissMethod.closeButton,
      visibleMs: 0,
    );
    expect(
      lines,
      ['[welcome] welcome_dismissed method=close_button visible_ms=0'],
    );
  });

  test('四种关闭方式的 wire 取值稳定', () {
    expect(WelcomeDismissMethod.button.wire, 'button');
    expect(WelcomeDismissMethod.back.wire, 'back');
    expect(WelcomeDismissMethod.configureAi.wire, 'configure_ai');
    expect(WelcomeDismissMethod.closeButton.wire, 'close_button');
  });

  test('welcome_error 字段', () {
    const DebugWelcomeLog().error(
      stage: WelcomeErrorStage.render,
      error: 'StateError: boom',
    );
    expect(lines, ['[welcome] welcome_error stage=render error=StateError: boom']);
  });

  test('错误摘要单行且 message 截断到 120 字符', () {
    final summary = welcomeErrorSummary(StateError('x\n' * 200));

    expect(summary.contains('\n'), isFalse);
    expect(summary.startsWith('StateError: '), isTrue);
    final message = summary.substring('StateError: '.length);
    expect(message.length, 120);
  });

  test('错误摘要替换回车', () {
    final summary = welcomeErrorSummary(Exception('a\r\nb'));
    expect(summary.contains('\r'), isFalse);
    expect(summary.contains('\n'), isFalse);
  });

  test('日志实现自身异常不向外抛', () {
    debugPrint = (String? message, {int? wrapWidth}) {
      throw StateError('print failed');
    };

    expect(
      () => const DebugWelcomeLog().check(
        show: true,
        reason: WelcomeReason.noFlag,
        entry: WelcomeEntry.coldStart,
        locale: 'zh',
      ),
      returnsNormally,
    );
  });
}
