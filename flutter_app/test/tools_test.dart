import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/ai/tools.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('get_battery_level calls native channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dodroidai/tools'),
      (call) async {
        if (call.method == 'get_battery') return '77';
        return null;
      },
    );
    final result = await ToolRegistry.execute('get_battery_level', '{}');
    expect(result, '77%');
  });

  test('set_alarm calls native channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dodroidai/tools'),
      (call) async {
        if (call.method == 'set_alarm') {
          expect(call.arguments['hour'], 7);
          expect(call.arguments['minute'], 30);
          return '已设置闹钟 07:30';
        }
        return null;
      },
    );
    final result = await ToolRegistry.execute(
      'set_alarm',
      '{"hour":7,"minute":30}',
    );
    expect(result, '已设置闹钟 07:30');
  });

  test('unknown tool returns message', () async {
    final result = await ToolRegistry.execute('unknown_tool', '{}');
    expect(result, contains('未知工具'));
  });
}
