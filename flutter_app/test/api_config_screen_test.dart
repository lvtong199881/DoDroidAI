import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dodroidai/ai/ai_config.dart';
import 'package:dodroidai/screens/chat/chat_provider.dart';
import 'package:dodroidai/screens/settings/api_config_screen.dart';

/// 隔离 sqflite：配置页只验证渲染，不在这里验证会话加载。
class _NoopChatController extends ChatController {
  @override
  Future<void> ensureReady() async {}
}

const Key _baseUrlKey = Key('api_config_base_url');
const Key _mainModelKey = Key('api_config_main_model');
const Key _apiKeyKey = Key('api_config_api_key');
const Key _saveKey = Key('api_config_save');

AiConfig existingConfig() => AiConfig(
      id: 'existing',
      provider: AiProvider.openai,
      apiFormat: ApiFormat.openAiChatCompletions,
      providerName: 'OpenAI',
      baseUrl: 'https://api.openai.com',
      apiKey: 'sk-placeholder-not-real',
      mainModel: 'gpt-4o',
    );

/// 页面内容较长：用高视口让所有控件都真实建出来，避免 ListView 懒加载找不到。
///
/// 宽度保持测试默认的 800：flutter_test 的等宽测试字体会把「Anthropic Messages」
/// 下拉文本撑宽，窄视口下会触发与真机无关的 RenderFlex overflow。
Future<void> pumpScreen(
  WidgetTester tester, {
  AiConfig? config,
  AiProvider? initialProvider,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 1800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [chatProvider.overrideWith((_) => _NoopChatController())],
      child: MaterialApp(
        home: ApiConfigScreen(
          config: config,
          initialProvider: initialProvider,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String fieldText(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller?.text ?? '';

String mainModelText(WidgetTester tester) => tester
        .widget<DropdownMenu<String>>(find.byKey(_mainModelKey))
        .controller
        ?.text ??
    '';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('initialProvider=deepseek：新建态预设，Key 为空，无删除', (tester) async {
    await pumpScreen(tester, initialProvider: AiProvider.deepseek);

    expect(find.text('新建配置'), findsOneWidget);
    expect(find.text('编辑配置'), findsNothing);
    expect(find.text('删除'), findsNothing);
    expect(find.text('设为激活'), findsNothing);
    expect(find.byKey(_saveKey), findsOneWidget);

    expect(fieldText(tester, _baseUrlKey), 'https://api.deepseek.com/anthropic');
    expect(mainModelText(tester), 'DeepSeek-V4-Flash');
    expect(fieldText(tester, _apiKeyKey), '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('不带初始服务商：仍是空的自定义新建态（回归）', (tester) async {
    await pumpScreen(tester);

    expect(find.text('新建配置'), findsOneWidget);
    expect(find.text('编辑配置'), findsNothing);
    expect(fieldText(tester, _baseUrlKey), '');
    expect(mainModelText(tester), '');
    expect(fieldText(tester, _apiKeyKey), '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('传入已有配置：编辑态出现删除与设为激活（回归）', (tester) async {
    await pumpScreen(tester, config: existingConfig());

    expect(find.text('编辑配置'), findsOneWidget);
    expect(find.text('新建配置'), findsNothing);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('设为激活'), findsOneWidget);
    expect(fieldText(tester, _baseUrlKey), 'https://api.openai.com');
    expect(mainModelText(tester), 'gpt-4o');
    expect(tester.takeException(), isNull);
  });
}
