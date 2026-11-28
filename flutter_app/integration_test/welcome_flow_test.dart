import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dodroidai/app.dart';
import 'package:dodroidai/settings/welcome_flag_store.dart';
import 'package:dodroidai/widgets/welcome_dialog.dart';

/// 真机端到端冒烟：清标记 → 首次进入首页弹窗 → 关闭写标记 → 新容器不再弹。
Future<File> _flagFile() async {
  final directory = await getApplicationSupportDirectory();
  return File(p.join(directory.path, FileWelcomeFlagStore.flagRelativePath));
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('首次展示 → 关闭 → 标记为 1 → 再次进入不弹', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final flag = await _flagFile();
    if (await flag.exists()) {
      await flag.delete();
    }

    await tester.pumpWidget(const ProviderScope(child: DoDroidApp()));
    await tester.pump();
    await _pumpUntil(tester, find.byType(WelcomeDialog));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.byType(WelcomeDialog), findsOneWidget);
    // 说明行随欢迎弹窗一起展示（REQ-1 / AC-19）；文案逐字由
    // welcome_copy_test.dart / app_strings_test.dart 锁定，这里不依赖设备语言。
    expect(find.byKey(welcomeDialogAiHintKey), findsOneWidget);
    // 先写标记再展示（AC-6）
    expect(await flag.exists(), isTrue);
    expect((await flag.readAsString()).trim(), '1');

    final startButton = find.descendant(
      of: find.byType(WelcomeDialog),
      matching: find.byType(FilledButton),
    );
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeDialog), findsNothing);
    expect((await flag.readAsString()).trim(), '1');

    // 强制新建 ProviderScope（等价新进程首次进入首页），标记存在则不再弹
    await tester.pumpWidget(
      const ProviderScope(
        key: ValueKey('welcome-second-launch'),
        child: DoDroidApp(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(WelcomeDialog), findsNothing);

    // 清理，避免影响其他用例
    if (await flag.exists()) {
      await flag.delete();
    }
  });

  testWidgets('角标关闭 → 标记为 1 → 再次进入不弹（AC-12）', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final flag = await _flagFile();
    if (await flag.exists()) {
      await flag.delete();
    }

    await tester.pumpWidget(const ProviderScope(child: DoDroidApp()));
    await tester.pump();
    await _pumpUntil(tester, find.byType(WelcomeDialog));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.byType(WelcomeDialog), findsOneWidget);
    expect(find.byKey(welcomeDialogCloseKey), findsOneWidget);

    await tester.tap(find.byKey(welcomeDialogCloseKey));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeDialog), findsNothing);
    expect((await flag.readAsString()).trim(), '1');

    await tester.pumpWidget(
      const ProviderScope(
        key: ValueKey('welcome-close-second-launch'),
        child: DoDroidApp(),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(WelcomeDialog), findsNothing);

    if (await flag.exists()) {
      await flag.delete();
    }
  });
}
