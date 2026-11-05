import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/app.dart';

void main() {
  testWidgets('app renders chat screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DoDroidApp()));
    await tester.pump();
    final hint = find.textContaining(
      RegExp('发送消息开始对话|Send a message to start'),
    );
    expect(hint, findsOneWidget);
  });
}
