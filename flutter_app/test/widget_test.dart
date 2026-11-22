import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dodroidai/app.dart';

import 'support/welcome_fakes.dart';

void main() {
  testWidgets('app renders chat screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        // 欢迎弹窗由 welcome_* 用例覆盖，这里跳过以免遮罩影响首页断言
        overrides: [welcomeAlreadyShownOverride()],
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
