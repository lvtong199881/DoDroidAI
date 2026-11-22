import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dodroidai/app.dart';
import 'package:dodroidai/screens/chat/chat_provider.dart';

import 'support/welcome_fakes.dart';

/// 隔离 sqflite：这里只验证首页能渲染，不验证会话加载。
class _NoopChatController extends ChatController {
  @override
  Future<void> ensureReady() async {}
}

void main() {
  testWidgets('app renders chat screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        // 欢迎弹窗由 welcome_* 用例覆盖，这里跳过以免遮罩影响首页断言
        overrides: [
          chatProvider.overrideWith((_) => _NoopChatController()),
          welcomeAlreadyShownOverride(),
        ],
        child: const DoDroidApp(),
      ),
    );
    await tester.pump();
    final hint = find.textContaining(
      RegExp('发送消息开始对话|Send a message to start'),
    );
    expect(hint, findsOneWidget);
  });
}
