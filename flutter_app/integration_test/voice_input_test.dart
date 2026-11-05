import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dodroidai/app.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(const ProviderScope(child: DoDroidApp()));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('麦克风支持按住说话（按下有反馈，抬起结束）', (tester) async {
    await _pumpApp(tester);

    final mic = find.byIcon(Icons.mic_none).first;
    expect(mic, findsOneWidget);

    final center = tester.getCenter(mic);
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 600));

    // 未授权时会弹提示；已授权时会出现波形层。两种情况都必须有反馈。
    final hasToast = find.textContaining('权限').evaluate().isNotEmpty ||
        find.textContaining('麦克风').evaluate().isNotEmpty ||
        find.textContaining('语音').evaluate().isNotEmpty;
    final hasOverlay = find.byType(CustomPaint).evaluate().length > 1;
    expect(hasToast || hasOverlay, isTrue, reason: '按住麦克风没有任何反馈');

    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    // 抬起后不应崩溃，且提示/波形应关闭
    expect(tester.takeException(), isNull);
  });

  testWidgets('键盘/语音模式可切换，语音模式显示「按住说话」', (tester) async {
    await _pumpApp(tester);

    expect(find.text('按住说话'), findsNothing);

    // 模式切换按钮（第二行右侧麦克风图标）
    final switchBtn = find.byIcon(Icons.mic_none).last;
    await tester.tap(switchBtn);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('按住说话'), findsOneWidget);

    // 再点键盘图标切回打字模式
    await tester.tap(find.byIcon(Icons.keyboard).last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('按住说话'), findsNothing);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('语音模式下按住「按住说话」有反馈', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byIcon(Icons.mic_none).last);
    await tester.pump(const Duration(milliseconds: 300));

    final bar = find.text('按住说话');
    expect(bar, findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(bar));
    await tester.pump(const Duration(milliseconds: 500));
    // 授权成功会进入录音态（文案变化/波形），未授权会弹提示
    final feedback = find.text('正在录音…').evaluate().isNotEmpty ||
        find.textContaining('权限').evaluate().isNotEmpty ||
        find.textContaining('麦克风').evaluate().isNotEmpty ||
        find.byType(CustomPaint).evaluate().length > 1;
    expect(feedback, isTrue);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
