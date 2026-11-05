import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dodroidai/app.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(const ProviderScope(child: DoDroidApp()));
  // 等首帧 + 异步初始化（数据库 ensureReady）
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('空会话点击新建对话弹出「已经在新对话中」Toast', (tester) async {
    await _pumpApp(tester);

    // 空状态提示存在
    expect(find.text('发送消息开始对话'), findsOneWidget);

    // 顶栏的 + 按钮（限定在 AppBar 内，避免点到输入框的附件按钮）
    final addButton = find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.add),
    );
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    await tester.pump(const Duration(milliseconds: 200));

    // Toast 文案出现
    expect(find.text('已经在新对话中'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('深度思考 chip 可点击并切换选中状态', (tester) async {
    await _pumpApp(tester);

    final chip = find.text('深度思考');
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 300));

    final filterChip = tester.widget<FilterChip>(
      find.ancestor(of: chip, matching: find.byType(FilterChip)).first,
    );
    expect(filterChip.selected, isTrue);
  });

  testWidgets('音量按钮切换自动朗读并弹 Toast', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.volume_off).first);
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data == '已开启自动朗读' || w.data == '已关闭自动朗读'),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('抽屉可打开并显示底部栏', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();

    expect(find.text('DoDroidAI'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsWidgets);
  });

  testWidgets('设置页可打开并进入语音输入/输出二级页', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings).first);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('设置'), findsWidgets);
    expect(find.text('语音输入'), findsOneWidget);

    await tester.tap(find.text('语音输入'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('下载源'), findsOneWidget);
    expect(find.text('SenseVoice Small'), findsOneWidget);
  });
}
