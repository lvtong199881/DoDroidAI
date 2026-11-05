import 'package:flutter_test/flutter_test.dart';

import 'package:dodroidai/ai/tools.dart';

void main() {
  test('get_current_time returns iso string', () async {
    final result = await ToolRegistry.execute('get_current_time', '{}');
    expect(DateTime.tryParse(result), isNotNull);
  });

  test('unknown tool returns message', () async {
    final result = await ToolRegistry.execute('unknown_tool', '{}');
    expect(result, contains('未知工具'));
  });

  test('high risk tools are marked', () {
    expect(ToolRegistry.isHighRisk('send_sms'), isTrue);
    expect(ToolRegistry.isHighRisk('get_current_time'), isFalse);
  });
}
