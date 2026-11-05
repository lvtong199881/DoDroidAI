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

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.menu).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings).first);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('语音输入页：下载源单选与模型卡片结构', (tester) async {
    await _pumpApp(tester);
    await _openSettings(tester);

    await tester.tap(find.text('语音输入'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // 下载源标题 + 两个单选
    expect(find.text('下载源'), findsOneWidget);
    expect(find.text('国内镜像（hf-mirror）'), findsOneWidget);
    expect(find.text('HuggingFace'), findsOneWidget);

    // 模型卡片
    expect(find.text('SenseVoice Small'), findsOneWidget);
    expect(find.text('中文 / 英文 / 粤语 / 日语 / 韩语'), findsOneWidget);

    // 切换下载源
    await tester.tap(find.text('HuggingFace'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.text('HuggingFace'), findsOneWidget);
  });

  testWidgets('语音输出页：单模型详情与提示文案', (tester) async {
    await _pumpApp(tester);
    await _openSettings(tester);

    await tester.tap(find.text('语音输出'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('MeloTTS 中英混合'), findsOneWidget);
    expect(find.textContaining('中文 / 英文'), findsOneWidget);
    expect(find.text('离线合成，不依赖系统语音引擎；下载后自动启用。'), findsOneWidget);
    expect(find.text('下载'), findsOneWidget);
  });

  testWidgets('对话页麦克风按钮可点击（首次会拉起系统录音权限）', (tester) async {
    await _pumpApp(tester);

    final mic = find.byIcon(Icons.mic_none).first;
    expect(mic, findsOneWidget);

    await tester.tap(mic);
    await tester.pump(const Duration(milliseconds: 800));

    // 未授权时系统会弹权限框（Flutter 侧无变化），
    // 已授权时会切到录音图标或给出提示；这里只要求不抛异常、界面仍可交互。
    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
