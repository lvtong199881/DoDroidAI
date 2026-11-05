import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/app.dart';

void main() {
  testWidgets('app renders chat screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DoDroidApp()),
    );
    await tester.pump();
    expect(find.text('发送消息开始对话'), findsOneWidget);
  });
}
