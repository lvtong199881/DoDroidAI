import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/app.dart';

void main() {
  testWidgets('app renders chat screen', (WidgetTester tester) async {
    await tester.pumpWidget(const DoDroidApp());
    expect(find.text('发送消息开始对话'), findsOneWidget);
  });
}
