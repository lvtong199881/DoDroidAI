import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dodroidai/ai/ai_config.dart';
import 'package:dodroidai/app.dart';
import 'package:dodroidai/screens/chat/chat_provider.dart';
import 'package:dodroidai/screens/chat/chat_screen.dart';
import 'package:dodroidai/screens/settings/api_config_screen.dart';
import 'package:dodroidai/settings/welcome_ai_gate.dart';
import 'package:dodroidai/settings/welcome_contract.dart';
import 'package:dodroidai/settings/welcome_controller.dart';
import 'package:dodroidai/settings/welcome_providers.dart';
import 'package:dodroidai/widgets/welcome_dialog.dart';

import 'support/welcome_fakes.dart';

/// 隔离 sqflite：首页只关心欢迎弹窗接入，不在这里验证会话加载。
class _NoopChatController extends ChatController {
  @override
  Future<void> ensureReady() async {}
}

const Key _configureAiKey = Key('welcome_dialog_configure_ai');
const Key _startKey = Key('welcome_dialog_start');

ProviderScope appWith({
  required WelcomeController controller,
  WelcomeAiGate? gate,
}) {
  return ProviderScope(
    overrides: [
      chatProvider.overrideWith((_) => _NoopChatController()),
      welcomeControllerProvider.overrideWithValue(controller),
      if (gate != null) welcomeAiGateProvider.overrideWithValue(gate),
    ],
    child: const DoDroidApp(),
  );
}

/// 三字段完整的激活配置（已配置 AI）。
AiConfig completeConfig() => AiConfig(
      id: 'active',
      provider: AiProvider.deepseek,
      apiFormat: ApiFormat.anthropicMessages,
      providerName: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com/anthropic',
      apiKey: 'sk-placeholder-not-real',
      mainModel: 'DeepSeek-V4-Flash',
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Finder startButton() => find.descendant(
        of: find.byType(WelcomeDialog),
        matching: find.byType(FilledButton),
      );

  testWidgets('首次进入首页：首帧后弹一次并写入标记', (tester) async {
    final store = FakeWelcomeFlagStore();
    final log = RecordingWelcomeLog();
    final controller = WelcomeController(
      store: store,
      log: log,
      entryResolver: fixedEntryResolver(WelcomeEntry.coldStart),
    );

    await tester.pumpWidget(appWith(controller: controller));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byType(WelcomeDialog), findsOneWidget);
    expect(store.writeCount, 1);
    expect(log.events.first, startsWith('check:show:no_flag:cold_start:'));

    await tester.tap(startButton());
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeDialog), findsNothing);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(store.writeCount, 1);
    expect(log.events.any((event) => event.startsWith('dismissed:button')), isTrue);
  });

  testWidgets('已展示标记存在时不弹窗、不写标记', (tester) async {
    final store = FakeWelcomeFlagStore(flagged: true);
    final log = RecordingWelcomeLog();
    final controller = WelcomeController(
      store: store,
      log: log,
      entryResolver: fixedEntryResolver(WelcomeEntry.coldStart),
    );

    await tester.pumpWidget(appWith(controller: controller));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeDialog), findsNothing);
    expect(store.writeCount, 0);
    expect(log.events.single, startsWith('check:skip:flagged:cold_start:'));
  });

  testWidgets('关闭后重建/回前台不再弹窗', (tester) async {
    final store = FakeWelcomeFlagStore();
    final log = RecordingWelcomeLog();
    final controller = WelcomeController(
      store: store,
      log: log,
      entryResolver: fixedEntryResolver(WelcomeEntry.coldStart),
    );

    await tester.pumpWidget(appWith(controller: controller));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.tap(startButton());
    await tester.pumpAndSettle();

    // 同一进程内离开首页再进入 + 切后台再回前台，都不再检查
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpWidget(appWith(controller: controller));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeDialog), findsNothing);
    expect(
      log.events.where((event) => event.startsWith('shown')).length,
      1,
    );
    expect(store.readCount, 1);
  });

  testWidgets('未配置 AI：首帧后弹窗出现两个按钮，判定只做一次', (tester) async {
    var gateCalls = 0;
    final gate = WelcomeAiGate(loadActive: () async {
      gateCalls++;
      return null;
    });
    final store = FakeWelcomeFlagStore();
    final controller = WelcomeController(
      store: store,
      log: RecordingWelcomeLog(),
      entryResolver: fixedEntryResolver(WelcomeEntry.coldStart),
    );

    await tester.pumpWidget(appWith(controller: controller, gate: gate));
    // 首帧只有首页，弹窗还没上屏
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byType(WelcomeDialog), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byType(WelcomeDialog), findsOneWidget);
    expect(find.byKey(_configureAiKey), findsOneWidget);
    expect(find.byKey(_startKey), findsOneWidget);
    expect(gateCalls, 1);
  });

  testWidgets('已配置 AI：弹窗只有「开始使用」，判定只做一次', (tester) async {
    var gateCalls = 0;
    final gate = WelcomeAiGate(loadActive: () async {
      gateCalls++;
      return completeConfig();
    });
    final controller = WelcomeController(
      store: FakeWelcomeFlagStore(),
      log: RecordingWelcomeLog(),
      entryResolver: fixedEntryResolver(WelcomeEntry.coldStart),
    );

    await tester.pumpWidget(appWith(controller: controller, gate: gate));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeDialog), findsOneWidget);
    expect(find.byKey(_configureAiKey), findsNothing);
    expect(find.byKey(_startKey), findsOneWidget);
    expect(gateCalls, 1);
  });

  testWidgets('已展示标记：不弹窗也不读 AI 配置', (tester) async {
    var gateCalls = 0;
    final gate = WelcomeAiGate(loadActive: () async {
      gateCalls++;
      return null;
    });
    final store = FakeWelcomeFlagStore(flagged: true);
    final controller = WelcomeController(
      store: store,
      log: RecordingWelcomeLog(),
      entryResolver: fixedEntryResolver(WelcomeEntry.coldStart),
    );

    await tester.pumpWidget(appWith(controller: controller, gate: gate));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeDialog), findsNothing);
    expect(gateCalls, 0);
    expect(store.writeCount, 0);
  });

  testWidgets('点击「去配置AI」：关弹窗后进入带预设的新建配置页', (tester) async {
    // 配置页内容较长：用高视口让预设字段都真实建出来
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final log = RecordingWelcomeLog();
    final controller = WelcomeController(
      store: FakeWelcomeFlagStore(),
      log: log,
      entryResolver: fixedEntryResolver(WelcomeEntry.coldStart),
    );

    await tester.pumpWidget(
      appWith(
        controller: controller,
        gate: WelcomeAiGate(loadActive: () async => null),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_configureAiKey));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeDialog), findsNothing);
    expect(find.byType(ApiConfigScreen), findsOneWidget);
    expect(find.text('新建配置'), findsOneWidget);
    expect(find.text('删除'), findsNothing);
    expect(find.text('设为激活'), findsNothing);
    expect(
      log.events.any((event) => event.startsWith('dismissed:configure_ai')),
      isTrue,
    );

    // 预设：Base URL / 主模型非空，API Key 为空
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('api_config_base_url')))
          .controller
          ?.text,
      'https://api.deepseek.com/anthropic',
    );
    expect(
      tester
          .widget<DropdownMenu<String>>(
            find.byKey(const Key('api_config_main_model')),
          )
          .controller
          ?.text,
      'DeepSeek-V4-Flash',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('api_config_api_key')))
          .controller
          ?.text,
      '',
    );
  });

  testWidgets('连点「去配置AI」只打开一次编辑页', (tester) async {
    final controller = WelcomeController(
      store: FakeWelcomeFlagStore(),
      log: RecordingWelcomeLog(),
      entryResolver: fixedEntryResolver(WelcomeEntry.coldStart),
    );

    await tester.pumpWidget(
      appWith(
        controller: controller,
        gate: WelcomeAiGate(loadActive: () async => null),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_configureAiKey));
    await tester.tap(find.byKey(_configureAiKey), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(ApiConfigScreen), findsOneWidget);
  });

  testWidgets('编辑页返回未保存：回首页且弹窗不恢复', (tester) async {
    final store = FakeWelcomeFlagStore();
    final log = RecordingWelcomeLog();
    final controller = WelcomeController(
      store: store,
      log: log,
      entryResolver: fixedEntryResolver(WelcomeEntry.coldStart),
    );

    await tester.pumpWidget(
      appWith(
        controller: controller,
        gate: WelcomeAiGate(loadActive: () async => null),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_configureAiKey));
    await tester.pumpAndSettle();
    expect(find.byType(ApiConfigScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ApiConfigScreen), findsNothing);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byType(WelcomeDialog), findsNothing);
    expect(
      log.events.where((event) => event.startsWith('shown')).length,
      1,
    );
    expect(store.writeCount, 1);
  });
}
