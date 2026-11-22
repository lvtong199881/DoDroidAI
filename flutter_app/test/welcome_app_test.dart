import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dodroidai/app.dart';
import 'package:dodroidai/screens/chat/chat_provider.dart';
import 'package:dodroidai/screens/chat/chat_screen.dart';
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

ProviderScope appWith({
  required WelcomeController controller,
}) {
  return ProviderScope(
    overrides: [
      chatProvider.overrideWith((_) => _NoopChatController()),
      welcomeControllerProvider.overrideWithValue(controller),
    ],
    child: const DoDroidApp(),
  );
}

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
}
